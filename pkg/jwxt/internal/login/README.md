# internal/login

CAS/EAMS 登录私有实现目录。

这个目录只服务于 `pkg/jwxt`，外部业务代码不应该直接导入。

职责拆分：

- `flow.go`：登录流程编排。
- `portal.go`：一网通办登录路由解析和 API 登录。
- `redirect.go`：手动重定向处理，避免泄露 ticket 或完整 URL。
- `session.go`：EAMS 会话确认和 Session 失效判断。
- `detect.go`：CAS/Portal 登录页识别、host 判断。

约束：

- 不保存密码。
- 不保存 Cookie。
- 不输出 Cookie、ticket、完整重定向 URL。
- 不把课表、成绩、考试解析逻辑放在这里。
