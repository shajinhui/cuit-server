# Campus Assistant API

当前 API 服务成绩查询最小闭环，并使用 MySQL 保存用户、加密后的教务凭据和应用会话。

## 启动

```bash
cp .env.example .env
# 填写 MYSQL_DSN，并生成 JWXT_CREDENTIAL_KEY：openssl rand -base64 32
go run ./apps/api
```

默认监听 `127.0.0.1:8888`。可通过 `APP_ADDR` 修改监听地址；HTTPS 部署时设置 `APP_COOKIE_SECURE=true`。

首次启动前需要创建数据库：

```sql
CREATE DATABASE cuit_server CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

启动时会自动执行 `migrations` 中的建表语句。`MYSQL_DSN` 必须包含 `parseTime=true`。

## 接口

```text
POST   /api/v1/jwxt/session     教务登录
GET    /api/v1/jwxt/session     查询当前登录状态
DELETE /api/v1/jwxt/session     退出教务
GET    /api/v1/jwxt/semesters  查询学期
GET    /api/v1/jwxt/grades     查询指定学期成绩
GET    /api/v1/health           健康检查
```

登录成功后，API 会保存用户学号、加密后的教务密码和应用会话摘要。姓名、性别、学院等字段暂时为空，等学校资料接口确认后再写入。

勾选“保持登录状态”时，`HttpOnly` 应用会话 Cookie 有效期为 30 天。学校系统 Cookie 仍只存在对应用户的独立 `jwxt.Client` 中；API 重启或 EAMS Session 失效后，查询会使用加密凭据自动登录，并且只重试原查询一次。
