# Campus Assistant

这是成都信息工程大学校园助手后端项目。

当前已完成并真实验证 `pkg/jwxt` 的 CAS/EAMS 登录闭环，包括一网通办登录、校内账号切换、CAS 桥接页处理和 EAMS 会话确认。

成绩模块已实现学期列表和指定学期成绩查询，并接入最小 Hertz API 与 PWA 页面。当前已通过离线协议、解析、API 和前端构建验证，真实成绩查询仍等待真实账号验证。

当前实现：

- `pkg/jwxt`：独立 JWXT SDK，负责 CAS/EAMS 登录、Cookie 会话和教务页面访问。
- `cmd/jwxt-demo`：用于手动验证登录和指定学期成绩查询。
- `apps/api`：最小 Hertz API，提供教务登录、登录状态、退出、学期列表和成绩查询。
- `apps/web`：Vue 3 PWA，已完成登录、课表、校园工具、个人中心和成绩查询页面。
- `migrations`：MySQL 用户与应用会话表。

MySQL 已接入用户凭据和应用会话持久化；用户资料字段的数据来源尚未接入。Redis、课表接口和其他校园工具后端尚未实现。

本地启动：

```bash
go run ./apps/api

cd apps/web
pnpm install
pnpm dev
```

首次启动前创建 `cuit_server` 数据库，并复制 `.env.example` 为 `.env`。API 启动时会自动加载 `.env`。`JWXT_CREDENTIAL_KEY` 可通过 `openssl rand -base64 32` 生成；密钥变更后，已有教务密码密文将无法解密。

前端默认运行在 `http://127.0.0.1:5173`，并把 `/api` 代理到 `http://127.0.0.1:8888`。

完整架构说明见 `architecture_guide.md`。

第一阶段执行计划见 `implementation_plan.md`。
