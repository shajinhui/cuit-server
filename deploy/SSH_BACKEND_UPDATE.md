# SSH 后端更新流程

本文用于从 macOS 开发机通过个人虚拟机跳板机连接校内服务器，并更新已经由
systemd 管理的 `cuit-server` 后端。

## 当前部署信息

| 项目 | 值 |
|---|---|
| 项目目录 | 本地仓库根目录 |
| 跳板机 | `ssh.personal.asynclab.club:55552` |
| 统一认证账号 | `YOUR_UNIFIED_ACCOUNT`，执行前替换 |
| 内网服务器 | `root@172.16.0.20` |
| 服务名称 | `cuit-server` |
| 正式二进制 | `/usr/local/bin/cuit-server-api` |
| 本机健康接口 | `http://127.0.0.1:8888/api/v1/health` |
| 公网健康接口 | `https://api.fanxiaogao05.dpdns.org/api/v1/health` |

统一认证密码只在本机 SSH 提示中输入，不要写进命令、脚本、GitHub Secret 或聊天记录。
目标服务器使用本机 `~/.ssh/id_ed25519` 私钥认证，私钥不需要复制到跳板机。

## 1. 测试并构建

以下命令在 Mac 本地终端执行：

```bash
cd /path/to/cuit-server

go test ./...

mkdir -p build
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -o build/cuit-server-api ./apps/api

file build/cuit-server-api
shasum -a 256 build/cuit-server-api
```

`file` 应显示该文件是 `ELF 64-bit`、`x86-64` 可执行文件。记录本次 SHA-256，
上传后需要在服务器上再次核对。

## 2. 上传二进制

仍在 Mac 本地终端执行：

```bash
scp -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519 \
  -J YOUR_UNIFIED_ACCOUNT@ssh.personal.asynclab.club:55552 \
  build/cuit-server-api \
  root@172.16.0.20:/tmp/cuit-server-api
```

SSH 会提示输入跳板机的统一认证密码。上传目标固定为
`/tmp/cuit-server-api`，不要直接覆盖正在运行的正式二进制。

## 3. 连接服务器

```bash
ssh -t \
  -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519 \
  -J YOUR_UNIFIED_ACCOUNT@ssh.personal.asynclab.club:55552 \
  root@172.16.0.20
```

登录后先确认主机和当前服务状态：

```bash
hostname
systemctl is-active cuit-server
```

确认主机名是目标个人虚拟机，服务状态应为 `active`。

## 4. 校验并原子替换

以下命令均在服务器执行：

```bash
sha256sum /tmp/cuit-server-api
```

输出必须与本地 `shasum -a 256` 完全一致。确认一致后执行：

```bash
sudo cp -a \
  /usr/local/bin/cuit-server-api \
  /usr/local/bin/cuit-server-api.previous

sudo install -o root -g root -m 0755 \
  /tmp/cuit-server-api \
  /usr/local/bin/cuit-server-api.new

sudo mv \
  /usr/local/bin/cuit-server-api.new \
  /usr/local/bin/cuit-server-api

sudo systemctl restart cuit-server
```

`.previous` 保留上一个可运行版本；先写入 `.new` 再 `mv`，可以避免正式路径出现
只上传了一部分的二进制。

## 5. 验证部署

```bash
sudo systemctl status cuit-server --no-pager -l
curl --fail http://127.0.0.1:8888/api/v1/health
sha256sum /usr/local/bin/cuit-server-api
```

健康接口应返回：

```json
{"code":0,"data":{"status":"ok"},"message":"success"}
```

退出服务器后，在 Mac 本地验证 Cloudflare Tunnel 公网链路：

```bash
curl --fail https://api.fanxiaogao05.dpdns.org/api/v1/health
```

本机和公网健康检查都成功，才算部署完成。

## 6. 查看日志

查看最近 80 行：

```bash
sudo journalctl -u cuit-server -n 80 --no-pager -o cat
```

实时查看：

```bash
sudo journalctl -u cuit-server -f -o cat
```

筛选 journald 当前仍保留的全部错误：

```bash
sudo journalctl -u cuit-server --no-pager -o cat \
  | grep -Ei 'error|失败|status=(4[0-9]{2}|5[0-9]{2})'
```

注意：密码错误和 `academic: unauthenticated` 通常属于用户输入或登录状态，
需要与解析失败、上游不可用和服务内部错误分开判断。

## 7. 失败回滚

仅在新版本启动或健康检查失败时，在服务器执行：

```bash
sudo install -o root -g root -m 0755 \
  /usr/local/bin/cuit-server-api.previous \
  /usr/local/bin/cuit-server-api.rollback

sudo mv \
  /usr/local/bin/cuit-server-api.rollback \
  /usr/local/bin/cuit-server-api

sudo systemctl restart cuit-server
sudo systemctl status cuit-server --no-pager -l
curl --fail http://127.0.0.1:8888/api/v1/health
```

回滚后保留现场日志，不要立刻覆盖或删除失败二进制，便于定位原因。

## 8. 常见 SSH 问题

### `Too many authentication failures`

说明 SSH 在询问密码前尝试了过多身份。先确认命令包含：

```text
-o IdentitiesOnly=yes -i ~/.ssh/id_ed25519
```

如果问题发生在跳板机，可强制跳板连接仅使用统一认证密码：

```bash
ssh -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519 \
  -o 'ProxyCommand=ssh -p 55552 -o PubkeyAuthentication=no -o PreferredAuthentications=keyboard-interactive,password -W %h:%p YOUR_UNIFIED_ACCOUNT@ssh.personal.asynclab.club' \
  root@172.16.0.20
```

上传时发生相同错误，可以把 `scp` 的 `-J` 替换为显式代理：

```bash
scp -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519 \
  -o 'ProxyCommand=ssh -p 55552 -o PubkeyAuthentication=no -o PreferredAuthentications=keyboard-interactive,password -W %h:%p YOUR_UNIFIED_ACCOUNT@ssh.personal.asynclab.club' \
  build/cuit-server-api \
  root@172.16.0.20:/tmp/cuit-server-api
```

### `Permission denied (publickey)`

目标服务器的 root 登录只接受密钥。确认本机私钥存在：

```bash
ls -l ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
```

不要把私钥上传到跳板机。若公钥尚未安装到目标服务器，需要通过已有服务器会话把
本机公钥加入目标服务器的 `/root/.ssh/authorized_keys`。

### 公网健康检查失败但本机成功

后端本身正常，继续检查 Cloudflare Tunnel：

```bash
sudo systemctl status cloudflared --no-pager -l
sudo journalctl -u cloudflared -n 80 --no-pager -o cat
```
