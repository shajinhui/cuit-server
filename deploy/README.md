# 正式部署

当前正式环境使用：

- 前端：Cloudflare Pages，`https://fanxiaogao05.dpdns.org`
- API：Cloudflare Tunnel，`https://api.fanxiaogao05.dpdns.org`
- 校内服务器：Debian GNU/Linux 13（trixie），amd64
- API 本机监听：`127.0.0.1:8888`
- 数据库：服务器本地 SQLite

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

启动并检查 API：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cuit-server
sudo systemctl status cuit-server
curl --fail http://127.0.0.1:8888/api/v1/health
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

## 6. 后端持续集成与部署

`.github/workflows/api.yml` 将后端发布拆成两个任务：

1. GitHub 托管 Runner 执行测试、静态检查，并交叉编译 Debian amd64 二进制。
2. 只有 `main` 分支推送通过检查后，校内服务器上的专用 Runner 才会下载二进制并部署。

部署脚本会保留上一个二进制。新版本重启后若健康检查失败，会恢复旧版本并再次启动服务。

### 6.1 注册校内服务器 Runner

仓库应保持为私有仓库。打开 GitHub 仓库：

```text
Settings -> Actions -> Runners -> New self-hosted runner
```

选择 `Linux` 和 `x64`。在校内服务器创建独立用户：

```bash
sudo useradd --create-home --shell /bin/bash github-runner
sudo install -d -o github-runner -g github-runner -m 0750 /opt/actions-runner
```

进入 `/opt/actions-runner`，以 `github-runner` 用户执行 GitHub 页面生成的下载和注册命令。注册时添加标签：

```text
cuit-production
```

注册令牌有时效，不要写入仓库。注册完成后，将 Runner 安装为 systemd 服务：

```bash
cd /opt/actions-runner
sudo ./svc.sh install github-runner
sudo ./svc.sh start
sudo ./svc.sh status
```

Runner 只需要主动访问 GitHub 的 HTTPS 443 端口，不需要新增服务器入站端口。

### 6.2 安装部署脚本

将仓库中的 `deploy/scripts/deploy-api.sh` 上传到服务器，再执行：

```bash
sudo install -o root -g root -m 0755 \
  deploy-api.sh \
  /usr/local/sbin/deploy-cuit-server-api

echo 'github-runner ALL=(root) NOPASSWD: /usr/local/sbin/deploy-cuit-server-api *' \
  | sudo tee /etc/sudoers.d/cuit-server-deploy >/dev/null
sudo chmod 0440 /etc/sudoers.d/cuit-server-deploy
sudo visudo -cf /etc/sudoers.d/cuit-server-deploy
```

GitHub 仓库中创建名为 `production` 的 Environment，并只允许 `main` 分支部署。

完成一次性配置后：

- Pull Request 只执行测试和构建。
- 推送到 `main` 会在检查通过后自动更新 `/usr/local/bin/cuit-server-api`。
- 部署完成后会检查 `http://127.0.0.1:8888/api/v1/health`。
