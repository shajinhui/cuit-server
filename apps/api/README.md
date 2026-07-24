# Campus Assistant API

当前 API 服务已实现登录、学籍信息、计划完成情况、学期、成绩、考试、个人课表和空教室查询，并使用 SQLite 保存用户、加密后的教务凭据和应用会话。

完整的请求参数、响应字段和错误码见 [`docs/API.md`](../../docs/API.md)。

## 启动

```bash
cp .env.example .env
# 生成 JWXT_CREDENTIAL_KEY：openssl rand -base64 32
go run ./apps/api
```

默认监听 `127.0.0.1:8888`。可通过 `APP_ADDR` 修改监听地址；HTTPS 部署时设置 `APP_COOKIE_SECURE=true`。

SQLite 文件默认位于 `data/cuit-server.db`，可通过 `SQLITE_PATH` 修改。启动时会自动创建目录、数据库并执行 `migrations` 中的建表语句。

## 接口

```text
POST   /api/v1/jwxt/session     教务登录
GET    /api/v1/jwxt/session     查询当前登录状态
DELETE /api/v1/jwxt/session     退出教务
GET    /api/v1/jwxt/profile     查询个人学籍信息
GET    /api/v1/jwxt/plan-completion 查询计划完成情况
GET    /api/v1/jwxt/semesters  查询学期
GET    /api/v1/jwxt/grades     查询指定学期成绩
GET    /api/v1/jwxt/exams      按学期和固定考试类型查询考场
GET    /api/v1/jwxt/course-table 查询指定学期个人课表
GET    /api/v1/jwxt/classroom-options 查询空教室筛选项
GET    /api/v1/jwxt/available-classrooms 查询空教室
GET    /api/v1/jwxt/classroom-schedule 查询指定学期和校区的完整教室占用快照
GET    /api/v1/schedule/current-week 查询当前教学周
GET    /api/v1/health           健康检查
```

登录成功后，API 会保存用户学号、已取得的学籍资料、加密后的教务密码和应用 Session Token 哈希。同一学号再次登录会直接覆盖旧 Session。

应用 Session 本身不设置业务过期时间，只会在新登录覆盖、主动退出或已保存凭据失效时撤销。学校系统 Cookie 只存在对应用户的独立 `jwxt.Client` 中；同一用户的查询会串行执行，Client 空闲 3 分钟后释放，下一次查询会使用加密凭据自动登录。
