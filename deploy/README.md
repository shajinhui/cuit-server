# 正式部署

已完成首次安装后，日常连接服务器和更新后端请直接参考
[SSH 后端更新流程](SSH_BACKEND_UPDATE.md)。

当前正式环境使用：

- 前端：Cloudflare Pages，`https://fanxiaogao05.dpdns.org`
- API：Cloudflare Tunnel，`https://api.fanxiaogao05.dpdns.org`
- 校内服务器：Debian GNU/Linux 13（trixie），amd64
- API 本机监听：`127.0.0.1:8888`
- 数据库：服务器本地 SQLite
- 缓存：服务器本地 Redis

浏览器直接访问 API 子域名。`cloudflared` 只把 API 请求转发到本机 Go 服务，EAMS 和 CAS 仍由校内服务器访问。

## 1. 构建 API

在项目根目录交叉编译 Debian amd64 二进制：

```bash
mkdir -p build
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -o build/cuit-server-api ./apps/api
```

将 `build/cuit-server-api`、`deploy/systemd/cuit-server.service` 和
`deploy/systemd/cuit-server.env.example` 上传到服务器。

## 2. 安装 API 服务

以下命令在服务器执行：

```bash
sudo useradd --system \
  --home-dir /var/lib/cuit-server \
  --create-home \
  --shell /usr/sbin/nologin \
  cuit-server

sudo install -d -o root -g cuit-server -m 0750 /etc/cuit-server
sudo install -d -o cuit-server -g cuit-server -m 0700 /var/lib/cuit-server
sudo install -o root -g root -m 0755 cuit-server-api /usr/local/bin/cuit-server-api
sudo install -o root -g root -m 0644 cuit-server.service /etc/systemd/system/cuit-server.service
sudo install -o root -g cuit-server -m 0640 \
  cuit-server.env.example \
  /etc/cuit-server/cuit-server.env
```

生成正式凭据加密密钥：

```bash
openssl rand -base64 32
sudo editor /etc/cuit-server/cuit-server.env
```

把生成结果写入 `JWXT_CREDENTIAL_KEY`。密钥不得提交到 Git，也不要在更换版本时重新生成，否则已有教务密码密文将无法解密。

再生成仅用于查看匿名聚合统计的管理员令牌：

```bash
openssl rand -hex 32
```

把结果写入 `ADMIN_STATS_TOKEN`。没有配置该变量时，统计接口不会注册。

`LOGIN_MAX_CONCURRENCY` 控制同时访问学校认证系统的登录请求数量，默认值为
`200`。达到上限的请求会立即收到 `503`，不会在服务器中排队。

启动并检查 API：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cuit-server
sudo systemctl status cuit-server
curl --fail http://127.0.0.1:8888/api/v1/health
```

### 配置 Redis

Redis 只保存可以重新查询的缓存，不承载应用 Session、密码或学校 Cookie。先安装：

```bash
sudo apt-get update
sudo apt-get install redis-server
```

编辑 `/etc/redis/redis.conf`，确认以下配置：

```text
bind 127.0.0.1 ::1
protected-mode yes
save ""
appendonly no
maxmemory 128mb
maxmemory-policy allkeys-lru
```

本项目的 Redis 不需要磁盘持久化；关闭 RDB 和 AOF 可以避免把个人教务查询缓存
写入磁盘。Redis 只监听本机，不要通过防火墙或 Cloudflare Tunnel 暴露 `6379`。

```bash
sudo systemctl enable --now redis-server
redis-cli ping
```

在 `/etc/cuit-server/cuit-server.env` 中配置：

```text
REDIS_URL=redis://127.0.0.1:6379/0
```

修改环境变量后重启 API，并确认日志包含“Redis 缓存已启用”：

```bash
sudo systemctl restart cuit-server
sudo journalctl -u cuit-server -n 30 --no-pager -o cat
```

## 3. 安装 Cloudflare Tunnel

在服务器安装 Cloudflare 官方稳定软件源：

```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update
sudo apt-get install cloudflared
```

随后在 Cloudflare 控制台完成：

1. 打开 `Networking -> Tunnels`。
2. 创建名为 `cuit-server-api` 的 Tunnel。
3. 选择 Debian、amd64。
4. 在服务器执行控制台生成的 `cloudflared service install <TUNNEL_TOKEN>`。
5. 新增 Published application：
   - Subdomain：`api`
   - Domain：`fanxiaogao05.dpdns.org`
   - Type：`HTTP`
   - URL：`localhost:8888`

Tunnel Token 只在服务器执行，不写入仓库或聊天记录。

检查 Tunnel：

```bash
sudo systemctl status cloudflared
curl --fail https://api.fanxiaogao05.dpdns.org/api/v1/health
```

服务器不需要开放 `8888` 入站端口。若校网限制外连，需要允许
`cloudflared` 访问 Cloudflare 的 `7844/TCP` 或 `7844/UDP`。

## 4. 部署 Cloudflare Pages

在 Cloudflare `Workers & Pages` 中导入本项目 GitHub 仓库，填写：

| 配置 | 值 |
|---|---|
| Production branch | `main` |
| Root directory | `apps/web` |
| Build command | `pnpm run build` |
| Build output directory | `dist` |
| `NODE_VERSION` | `22.20.0` |
| `PNPM_VERSION` | `10.26.1` |
| `VITE_API_BASE_URL` | `https://api.fanxiaogao05.dpdns.org` |

部署成功后，将 Pages Custom domain 设置为：

```text
fanxiaogao05.dpdns.org
```

根域当前已有 DNS 记录。绑定 Pages 前先确认该记录不再承载其他服务，然后按 Pages 提示替换冲突记录。

`pnpm run build` 还会生成 Android Web 热更新清单和 ZIP。Android 使用原生
HTTP 从 `https://fanxiaogao05.dpdns.org/app-updates/android/latest.json`
读取清单，因此不会被同域的 Capacitor 本地资源服务器拦截。自定义域名是首选
下载地址，Pages 自动注入的 `CF_PAGES_URL` 是不可变部署的备用地址；不需要
R2 或额外上传步骤。

## 5. 上线验证

按顺序检查：

1. `https://api.fanxiaogao05.dpdns.org/api/v1/health` 返回成功。
2. `https://fanxiaogao05.dpdns.org` 可以安装 PWA。
3. 浏览器登录请求没有 CORS 错误。
4. 登录响应写入带 `Secure` 和 `HttpOnly` 的 `campus_session`。
5. 刷新页面后仍保持登录状态。
6. 学期、成绩、课表、考试和个人信息接口可以正常访问。
7. 重启 `cuit-server` 后，已有用户能够通过保存的加密凭据重新登录教务系统。

查看服务日志：

```bash
sudo journalctl -u cuit-server -f
sudo journalctl -u cloudflared -f
```

查看最近 30 天接口调用和用户增长：

```bash
curl --fail \
  -H "Authorization: Bearer $ADMIN_STATS_TOKEN" \
  "http://127.0.0.1:8888/api/v1/admin/stats?days=30"
```

部署 Web 后也可以打开图形化统计面板：

```text
https://fanxiaogao05.dpdns.org/admin/stats
```

在页面中手动输入 `ADMIN_STATS_TOKEN`。令牌只保存在当前浏览器标签页的
`sessionStorage` 中，退出统计或关闭标签页后清除，不会进入 Web 构建产物。

统计数据只包含按接口聚合的请求量、状态码分类、耗时，以及内部用户 ID
对应的日活记录；不会保存学号、Cookie、请求体或成绩内容。
