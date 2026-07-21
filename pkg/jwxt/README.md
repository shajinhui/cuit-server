# pkg/jwxt

独立 JWXT SDK 目录。

职责边界：

- 访问 EAMS。
- 跳转 CAS。
- 管理独立 CookieJar。
- 登录并保持会话。
- 查询学期列表和指定学期成绩。
- 解析教务页面。
- 判断 Session 是否失效。

不应该依赖：

- Hertz。
- Redis。
- MySQL。
- JWT。
- `internal/` 下的业务代码。

当前已经真实验证最小 CAS/EAMS 登录闭环。成绩查询已完成离线测试，等待真实账号验证。

## 内部分层

`pkg/jwxt` 是 SDK 边界，不代表所有逻辑写在一起。

当前按职责拆分：

```text
client.go          对外 Client、NewClient、IsLoggedIn 等入口
config.go          SDK 配置
errors.go          SDK 错误
grade.go           学期和成绩查询入口
internal/login/    CAS/EAMS 登录私有实现
internal/grade/    学期请求、成绩请求和纯解析
```

`internal/login` 职责：

```text
flow.go            登录编排
portal.go          一网通办登录路由解析和 API 登录
redirect.go        手动重定向
session.go         EAMS 会话确认
detect.go          CAS/Portal 登录页识别、host 判断
inspect.go         登录流程安全检查
```

约束：

- 页面解析不要和登录流程混在一起。
- 会话验证不要和业务数据解析混在一起。
- 登录页识别逻辑集中管理，避免各流程各写一套判断。
- 外部业务只调用 `pkg/jwxt`，不要调用 `internal/login`。
