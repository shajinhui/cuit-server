# pkg/jwxt

独立 JWXT SDK 目录。

职责边界：

- 访问 EAMS。
- 跳转 CAS。
- 管理独立 CookieJar。
- 登录并保持会话。
- 查询学期、成绩、个人课表、整学期教室占用快照、空闲教室和考试考场。
- 解析教务页面。
- 判断 Session 是否失效。

不应该依赖：

- Hertz。
- Redis。
- SQLite 或其他业务持久化。
- JWT。
- `internal/` 下的业务代码。

当前已经真实验证最小 CAS/EAMS 登录闭环，以及成绩、个人课表和公共教室课表的真实页面结构。

## 内部分层

`pkg/jwxt` 是 SDK 边界，不代表所有逻辑写在一起。

当前按职责拆分：

```text
client.go          对外 Client、NewClient、IsLoggedIn 等入口
config.go          SDK 配置
errors.go          SDK 错误
grade.go           学期和成绩查询入口
course_table.go    个人课表和空闲教室查询入口
exam.go            考试批次和考场查询入口
internal/login/    CAS/EAMS 登录私有实现
internal/grade/    学期请求、成绩请求和纯解析
internal/coursetable/  课表请求、教室占用请求和纯解析
internal/exam/     考试批次请求、考场请求和纯解析
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

## 考试考场查询

业务调用方使用固定考试类型，SDK 会按学期解析真实的动态批次 ID：

```go
exams, err := client.GetExamsByType(ctx, semesterID, jwxt.ExamTypeFinal)
```

`Exam` 保留 EAMS 返回的考试日期、时间、地点、状态和备注。尚未安排的值可能是“时间未安排”或“地点未安排”，SDK 不自行改写。

真实网络测试默认不执行。显式运行时使用：

```bash
CUIT_JWXT_LIVE_TEST=1 \
CUIT_JWXT_USERNAME='<学号>' \
CUIT_JWXT_PASSWORD='<密码>' \
CUIT_JWXT_SEMESTER_ID='<学期ID>' \
go test -tags jwxt_live ./pkg/jwxt -run TestLiveExamQuery
```
