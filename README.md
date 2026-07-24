# Campus Assistant

这是成都信息工程大学校园助手后端项目。

当前已完成并真实验证 `pkg/jwxt` 的 CAS/EAMS 登录闭环，包括一网通办登录、校内账号切换、CAS 桥接页处理和 EAMS 会话确认。

成绩模块已实现学期列表和指定学期成绩查询。个人课表 SDK、后端接口和前端课表页面已完成对接。当前已通过离线协议、解析和 API 测试，真实课表查询仍等待真实账号验证。

当前实现：

- `pkg/jwxt`：独立 JWXT SDK，负责 CAS/EAMS 登录、Cookie 会话和教务页面访问。
- `cmd/jwxt-demo`：用于手动验证登录和指定学期成绩查询。
- `apps/api`：最小 Hertz API，提供教务登录、登录状态、退出、学期列表、成绩、个人课表和当前教学周查询。
- `apps/web`：Vue 3 PWA，已完成登录、课表、校园工具、个人中心和成绩查询页面。
- `migrations`：SQLite 用户与应用会话表。

SQLite 已接入用户、加密教务凭据和应用会话持久化。每个学号只保存一个应用 Session，新登录会覆盖旧 Session；内存中的 JWXT Client 空闲 3 分钟后释放，需要查询时再自动登录。

本地启动：

```bash
go run ./apps/api

cd apps/web
pnpm install
pnpm dev
```

首次启动前复制 `.env.example` 为 `.env`。API 会自动创建 `data/cuit-server.db` 并执行迁移。`JWXT_CREDENTIAL_KEY` 可通过 `openssl rand -base64 32` 生成；密钥变更后，已有教务密码密文将无法解密。

前端默认运行在 `http://127.0.0.1:5173`，并把 `/api` 代理到 `http://127.0.0.1:8888`。

早期架构讨论保留在 `architecture_guide.md`；当前运行结构以本 README 和代码为准。

当前 HTTP API 见 [`docs/API.md`](docs/API.md)。

第一阶段执行计划见 `implementation_plan.md`。
