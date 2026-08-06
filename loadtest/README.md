# k6 压测

这是面向本项目的企业级 k6 压测套件，按“公开接口、已登录缓存接口、登录链路”三类场景分开设计。

## 结构

```text
loadtest/
├── api.js                 # 主压测脚本：smoke/load/stress/soak
├── login.js               # 登录链路专项压测
├── package.json           # 常用命令封装
├── data/
│   └── accounts.example.json
└── reports/               # 运行时生成，不入库
```

`api.js` 会在压测前用账号文件统一登录，拿到各自的 `campus_session` Cookie 后分发到不同 VU，避免压测过程中反复登录学校系统。默认会先暖缓存，保证主压测阶段测的是“应用 + SQLite + Redis”路径。

## 安装

```bash
brew install k6
```

也可以用 [k6 官方安装包](https://grafana.com/docs/k6/latest/set-up/install-k6/)。`package.json` 只是命令封装，不依赖 npm 包。

## 准备测试账号

```bash
cd loadtest
cp data/accounts.example.json data/accounts.json
```

在 `data/accounts.json` 中填入自己可控的测试账号，不要提交真实账号。账号数量至少覆盖压测场景的最大 VU 数，否则会有多个 VU 共享同一个会话，单用户教务请求又是串行的，结果会失真。

## 启动被测服务

```bash
cd ..
go run ./apps/api
```

建议先确认 Redis 已启动并配置 `REDIS_URL`，否则缓存接口每次都会回源到学校系统。

## 运行

默认目标地址是 `http://127.0.0.1:8888`，可以用 `--env BASE_URL=...` 覆盖：

```bash
npm run smoke
npm run load -- --env BASE_URL=http://127.0.0.1:8888
npm run stress -- --env BASE_URL=http://127.0.0.1:8888
npm run soak -- --env BASE_URL=http://127.0.0.1:8888
```

四种模式的定义：

| 模式 | 命令 | 目标 |
|---|---|---|
| smoke | `npm run smoke` | 5 个 VU、100 次迭代，快速验证链路 |
| 1c1g | `npm run 1c1g` | 1 核 1G 小服务器推荐档，峰值 20 RPS |
| load | `npm run load` | 9 分钟斜坡负载，峰值为 100 VU |
| stress | `npm run stress` | 9 分钟高压，峰值 400 VU，看系统何时退化 |
| soak | `npm run soak` | 50 VU 持续 30 分钟，看内存、连接和 Redis 泄漏 |
| soak-1c1g | `npm run soak-1c1g` | 10 RPS 持续 15 分钟，适合小服务器浸泡 |

`load`、`stress`、`soak` 的默认规模面向更宽裕的服务器。1 核 1G
机器建议优先使用 `1c1g` 和 `soak-1c1g`，不要一上来就跑到 400 VU。

## 1 核 1G 服务器的推荐流程

```bash
# 1. 先确认链路和缓存可用
npm run smoke

# 2. 看峰值 20 RPS 下 CPU、内存和延迟是否稳定
npm run 1c1g

# 3. 稳定后再做 15 分钟浸泡，10 RPS
npm run soak-1c1g
```

压测过程中在服务器上同时观察：

```bash
htop
free -h
journalctl -u cuit-server --since "10 minutes ago" -f
redis-cli INFO memory
```

k6 建议在本地或另一台机器上运行，不要和被测 API 共用这台 1C1G 机器，
否则 k6 本身会占用 CPU 和内存，测试结果会偏低。

常用环境变量：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `BASE_URL` | `http://127.0.0.1:8888` | 被测 API 地址 |
| `ACCOUNTS_FILE` | `./data/accounts.json` | 测试账号文件 |
| `SEMESTER_ID` | `1106` | 成绩、课表使用的学期 |
| `WARM_CACHE` | `true` | 压测前先暖缓存 |
| `THINK_TIME_MS` | `0` | 每次迭代后的思考时间 |
| `MODE` | `smoke` | `smoke`/`1c1g`/`load`/`stress`/`soak`/`soak-1c1g` |
| `TARGET_RPS` | `20` | `1c1g` 的峰值 RPS |
| `SOAK_RPS` | `10` | `soak-1c1g` 的固定 RPS |
| `SOAK_DURATION` | `15m` | `soak-1c1g` 的持续时长 |

主场景按权重混合访问：`grades` 最重，`semesters`、`course-table` 其次，`session`、`profile`、`current-week` 较轻。`current-week` 是公开接口，其余接口携带会话 Cookie。

## 阈值

默认 SLO：

```text
endpoint_duration     p95 < 800ms，p99 < 1.5s
endpoint_failures     rate < 1%
```

`endpoint_duration` 和 `endpoint_failures` 只统计主压测阶段的应用请求，不包含登录预热和缓存暖机请求。未达到阈值时 k6 会以非零退出码结束，CI 可以直接把它当成失败门禁。

## 登录链路专项压测

```bash
npm run login -- --env LOGIN_RATE=2
```

默认每秒 1 次登录、持续 1 分钟。登录会真实访问学校 CAS/EAMS 链路，必须使用自己可控的少量测试账号，且不要把并发调高。项目侧 `LOGIN_MAX_CONCURRENCY=200`，超过上限会返回 `503` 和 `Retry-After: 5`。

## 报告

每次运行会在 `loadtest/reports/` 生成 JSON 汇总，包含各场景、各接口的 RPS、延迟分位数和错误率。也可以用 k6 的 Prometheus remote write 或 Grafana Cloud 做实时看板：

```bash
K6_PROMETHEUS_RW_SERVER_URL=http://prometheus:9090/api/v1/write \
K6_PROMETHEUS_RW_USERNAME=... \
K6_PROMETHEUS_RW_PASSWORD=... \
npm run load
```

k6 脚本内通过 `__ENV` 读取参数，统一用 `--env` 传入：

```bash
npm run load -- --env BASE_URL=http://127.0.0.1:8888 --env SEMESTER_ID=1106
npm run smoke -- --env ACCOUNTS_FILE=data/accounts.json --env WARM_CACHE=false
```

## CI 集成

GitHub Actions 可以用官方 `grafana/setup-k6-action` 和 `grafana/run-k6-action`。先做脚本校验，再在手动触发的负载任务里使用真实测试账号：

```yaml
name: Load Test
on:
  workflow_dispatch:

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: grafana/setup-k6-action@v1
      - uses: grafana/run-k6-action@v1
        with:
          path: loadtest/api.js
          flags: --env ACCOUNTS_FILE=loadtest/data/accounts.example.json
          only-verify-scripts: true

  load:
    runs-on: ubuntu-latest
    needs: verify
    steps:
      - uses: actions/checkout@v4
      - name: Write test accounts
        run: |
          mkdir -p loadtest/data
          printf '%s' '${{ secrets.K6_ACCOUNTS_JSON }}' > loadtest/data/accounts.json
        env:
          K6_ACCOUNTS_JSON: ${{ secrets.K6_ACCOUNTS_JSON }}
      - uses: grafana/setup-k6-action@v1
      - uses: grafana/run-k6-action@v1
        with:
          path: loadtest/api.js
          flags: --env MODE=smoke --env BASE_URL=${{ vars.K6_BASE_URL }} --env ACCOUNTS_FILE=loadtest/data/accounts.json
```

实际使用时应把 `K6_ACCOUNTS_JSON`、`K6_BASE_URL` 换成自己的仓库 Secrets/Variables，并按需要改成 `MODE=load` 或 `MODE=stress`。

## 压测注意点

- 不要把高并发直接打到未缓存的 `available-classrooms` 或登录接口，它们会访问学校系统。
- `profile`、`grades`、`course-table` 是用户维度缓存；要模拟多用户，必须准备足够多的账号。
- 同一用户的 JWXT 请求是串行的，单账号压测只能衡量应用层，不能代表多用户真实并发。
- 正式环境通常还经过 Cloudflare Tunnel，先压本地 API，再单独评估隧道和公网链路。
