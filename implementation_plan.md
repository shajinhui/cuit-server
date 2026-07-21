# Campus Assistant 第一阶段计划执行书

## 1. 目标

第一阶段目标是先完成一个最小可验证的 `pkg/jwxt` 教务 SDK，使后端能够安全地完成成都信息工程大学 EAMS + CAS 登录，并在登录成功后访问 EAMS 受保护页面。

本阶段不实现完整业务系统，不接入 Redis、MySQL、Hertz API、抢课、批量请求、自动续登、长期凭据保存。

核心交付物：

- 初始化 Go 项目。
- 实现 `pkg/jwxt` SDK。
- 实现 CAS/EAMS 登录闭环。
- 实现安全的登录链路检查工具。
- 实现命令行 demo。
- 实现纯单元测试，验证 CAS 表单解析逻辑。
- 为未来 `internal/jwxtsync`、`schedule`、`academic`、`exam` 域预留稳定接口。

## 2. 本阶段范围

### 2.1 必做

- 使用 Go 实现 `pkg/jwxt`。
- 使用 `github.com/go-resty/resty/v2` 作为 HTTP 客户端。
- 使用 `net/http/cookiejar` 管理会话 Cookie。
- 使用 `github.com/PuerkitoBio/goquery` 解析 CAS 登录页。
- 使用 `golang.org/x/term` 在 demo 中安全读取密码。
- 使用 `context.Context` 控制请求取消和超时。
- 每个 SDK Client 实例只代表一个用户的一次独立会话。
- 每个 SDK Client 内部独立创建 CookieJar。
- 不使用全局 Client。
- 不使用全局 CookieJar。
- 登录成功后确认不会再次跳回 CAS 登录页。
- 单元测试默认不访问真实学校系统。

### 2.2 不做

- 不保存教务密码。
- 不保存 Cookie。
- 不实现自动续登。
- 不实现抢课。
- 不实现批量访问 EAMS。
- 不实现 Redis 缓存。
- 不实现 MySQL 存储。
- 不实现 Hertz API。
- 不实现前端页面。
- 不在日志或终端输出密码、Cookie、ticket、完整重定向 URL、HTML 正文。

## 3. 教务处登录流程

后端登录链路如下：

```text
后端
    ↓
GET http://jwgl.cuit.edu.cn/eams/
    ↓
EAMS 返回 302
    ↓
跳转到 https://sso.cuit.edu.cn/authserver/login?service=...
    ↓
CAS 返回登录 HTML 页面
    ↓
解析一网通办登录入口、loginType、redirectUrl
    ↓
POST 一网通办 /api/base/login
    ↓
一网通办返回回跳 EAMS 的 redirect_uri
    ↓
CAS 认证成功
    ↓
302 跳回 EAMS，并带一次性 ticket
    ↓
EAMS 验证 ticket
    ↓
EAMS 发自己的 JSESSIONID
    ↓
后续可访问课表、成绩、考试页面
```

关键点：

- EAMS 是 HTTP。
- CAS 是 HTTPS。
- EAMS 和 CAS 会分别下发自己的 Cookie。
- 登录过程中必须使用同一个 CookieJar。
- CAS 回跳 EAMS 时会携带一次性 ticket。
- ticket 只能用于完成 EAMS 会话绑定，不允许输出或记录。
- 后续请求应使用 EAMS 下发的 JSESSIONID 访问课表、成绩、考试等页面。

## 4. 推荐目录结构

第一阶段只创建最小结构：

```text
campus-assistant/
├── cmd/
│   └── jwxt-demo/
│       └── main.go
├── pkg/
│   └── jwxt/
│       ├── client.go
│       ├── config.go
│       ├── errors.go
│       ├── internal/
│       │   └── login/
│       │       ├── flow.go
│       │       ├── portal.go
│       │       ├── redirect.go
│       │       ├── session.go
│       │       ├── detect.go
│       │       ├── inspect.go
│       │       └── portal_test.go
│       └── parser/
├── go.mod
├── go.sum
├── architecture_guide.md
└── implementation_plan.md
```

后续进入业务系统阶段后，再补：

```text
apps/api/
apps/worker/
internal/bootstrap/
internal/platform/
internal/user/
internal/schedule/
internal/jwxtsync/
migrations/
configs/
deploy/
```

## 5. SDK 设计

### 5.1 对外接口

第一阶段建议先提供最小接口：

```go
type Client interface {
    InspectLoginFlow(ctx context.Context) error
    Login(ctx context.Context, username, password string) error
    IsLoggedIn(ctx context.Context) (bool, error)
}
```

后续再扩展：

```go
GetProfile(ctx context.Context) (*Profile, error)
GetCourses(ctx context.Context, term string) ([]Course, error)
GetGrades(ctx context.Context, term string) ([]Grade, error)
GetExams(ctx context.Context, term string) ([]Exam, error)
```

### 5.2 默认实现

SDK 内部默认实现可以命名为 `DefaultClient`：

```go
type DefaultClient struct {
    resty    *resty.Client
    cfg      Config
    loggedIn bool
}
```

创建 Client 时必须：

- `cookiejar.New(nil)`
- `resty.New().SetCookieJar(jar)`
- 设置 15 秒超时。
- 禁止自动重试。
- 设置正常浏览器 User-Agent。
- 设置 Accept。
- 默认不打开 debug。
- 默认不输出请求头、响应头、响应体。

必须在代码注释中说明：

> 每个用户必须使用独立 CookieJar。CAS Cookie、EAMS JSESSIONID 和一次性 ticket 都属于某个用户的认证上下文。如果多个用户共享 CookieJar，可能出现会话串号、身份混淆、隐私泄露，甚至把 A 用户的教务请求发到 B 用户会话里。

## 6. 安全要求

### 6.1 绝对禁止输出

以下内容不得出现在日志、终端、错误信息、测试输出中：

- 密码。
- Cookie 值。
- JSESSIONID 值。
- CAS ticket 值。
- 完整 `service` 参数。
- 完整重定向 URL。
- CAS 登录页 HTML 正文。
- EAMS 页面 HTML 正文。

### 6.2 允许输出的安全摘要

调试或 `InspectLoginFlow` 只能输出：

- 请求 host。
- 请求 path。
- HTTP 状态码。
- Location 的 host。
- Location 的 path。
- 一网通办入口 host。
- 一网通办入口 path。
- 一网通办登录字段名摘要。

示例：

```text
request: host=jwgl.cuit.edu.cn path=/eams/ status=302
location: host=sso.cuit.edu.cn path=/authserver/login
portal: host=ywtb.cuit.edu.cn path=/ route=/login fields=loginType,redirectUrl
```

不能输出：

```text
https://sso.cuit.edu.cn/authserver/login?service=http://...
ticket=ST-...
Cookie: JSESSIONID=...
```

## 7. 登录实现步骤

### 7.1 InspectLoginFlow

目标：不提交账号密码，只检查当前学校登录页面结构。

执行步骤：

1. GET `http://jwgl.cuit.edu.cn/eams/`。
2. 手动处理有限次数 302。
3. 找到 CAS 登录页。
4. 解析一网通办登录入口。
5. 提取 `loginType` 和 `redirectUrl` 字段结构。
6. 输出安全摘要。

验收标准：

- 不提交账号密码。
- 不输出 Cookie。
- 不输出 ticket。
- 不输出完整 URL。
- 不输出 HTML 正文。
- 能看出当前 CAS 页面是否包含一网通办登录入口。

### 7.2 Login

目标：使用学号密码完成 CAS 登录，并获得 EAMS 会话。

执行步骤：

1. GET `http://jwgl.cuit.edu.cn/eams/`。
2. 手动跟随 EAMS 到 CAS 登录页的重定向。
3. 解析一网通办登录入口。
4. 提取 `loginType` 和 `redirectUrl`。
5. POST 学号、密码到一网通办 `/api/base/login`。
6. 读取返回的 `redirect_uri`。
7. 手动跟随回跳 EAMS。
8. 让 EAMS 验证 ticket。
9. 接收并保存 EAMS 下发的 JSESSIONID。
15. 再次 GET EAMS 首页或受保护页面。
16. 确认最终 URL 不在 CAS 登录页。
17. 确认响应中不再出现 `authserver/login` 或 `loginType=cas`。
18. 设置 `loggedIn = true`。

验收标准：

- 正确账号密码可以登录成功。
- 错误账号密码返回 `ErrInvalidCredentials` 或 `ErrLoginVerificationFailed`。
- 学校页面变化导致无法解析时返回 `ErrUnsupportedLoginPage`。
- 登录成功判断不能只依赖 HTTP 200。

## 8. 错误类型

SDK 至少定义以下错误：

```go
var (
    ErrRemoteUnavailable       = errors.New("jwxt: remote unavailable")
    ErrUnsupportedLoginPage    = errors.New("jwxt: unsupported login page")
    ErrInvalidCredentials      = errors.New("jwxt: invalid credentials")
    ErrLoginVerificationFailed = errors.New("jwxt: login verification failed")
    ErrSessionExpired          = errors.New("jwxt: session expired")
)
```

错误处理要求：

- 对外返回的错误必须能被 `errors.Is` 判断。
- 错误信息只能包含安全上下文，例如操作名、host、path、状态码。
- 不 wrap 可能包含完整 URL、Cookie 或响应正文的原始错误文本。
- 如果需要保留定位信息，使用安全字段重新构造错误。

示例：

```text
jwxt: remote unavailable: GET host=jwgl.cuit.edu.cn path=/eams/ status=503
```

禁止：

```text
Get "https://sso.cuit.edu.cn/authserver/login?service=...": ...
```

## 9. 重定向策略

本阶段建议禁用 Resty 自动重定向，改为 SDK 内部手动跟随。

原因：

- 自动重定向容易隐藏 CAS/EAMS 的关键跳转过程。
- 错误信息可能泄露完整 URL。
- CAS 回跳 EAMS 时 URL 里包含 ticket，必须避免被日志记录。
- 需要明确区分 GET 重定向和 POST 后重定向。

规则：

- 最多跟随 10 次重定向。
- 301、302、303 使用 GET 跟随。
- POST 后遇到 302/303，下一跳使用 GET。
- 307、308 不自动重放带密码的 POST 请求。
- Location 解析后只允许在内部使用，不能输出完整值。

## 10. 单元测试计划

单元测试只测试纯逻辑，不访问真实学校系统。

### 10.1 一网通办登录路由解析测试

给定 sample CAS HTML：

- 包含一网通办 hash 登录路由。
- 包含一网通办 history 登录路由。
- `redirectUrl` 可以不是最后一个 query 参数。

验证：

- 能提取入口 URL。
- 能提取 `loginType`。
- 能提取完整 `redirectUrl`。

### 10.2 网络集成测试

真实学校系统测试默认不执行。

可以使用 build tag：

```go
//go:build jwxt_live
```

也可以使用环境变量：

```text
CUIT_JWXT_LIVE_TEST=1
CUIT_JWXT_USERNAME=...
CUIT_JWXT_PASSWORD=...
```

要求：

- 不在测试代码中写真实学号密码。
- 不在测试失败时输出密码、Cookie、ticket、完整 URL。
- CI 默认不执行 live test。

## 11. Demo 计划

命令行 demo 放在：

```text
cmd/jwxt-demo/main.go
```

行为：

1. 从终端读取学号。
2. 使用 `term.ReadPassword` 读取密码，不回显。
3. 创建独立 JWXT Client。
4. 调用 `Login`。
5. 只输出登录成功或失败。
6. 失败时输出不含查询参数的具体错误信息。

输出示例：

```text
学号: 2024xxxxxx
密码:
正在登录...
登录成功
```

失败示例：

```text
登录失败: jwxt: invalid credentials
```

## 12. 执行里程碑

### M1：项目初始化

交付：

- `go.mod`
- 基础目录结构
- 依赖引入

验证：

```bash
go mod tidy
go test ./...
```

### M2：一网通办登录路由解析

交付：

- `pkg/jwxt/internal/login/portal.go`
- `pkg/jwxt/internal/login/portal_test.go`

验证：

```bash
go test ./pkg/jwxt/internal/login
```

### M3：Client 与安全配置

交付：

- `pkg/jwxt/client.go`
- `pkg/jwxt/config.go`
- `pkg/jwxt/errors.go`

验证：

```bash
go test ./...
go vet ./...
```

### M4：InspectLoginFlow

交付：

- `pkg/jwxt/inspect.go`

验证：

- 本地运行 demo 或单独命令。
- 只输出安全摘要。
- 不提交账号密码。

### M5：Login

交付：

- `pkg/jwxt/internal/login/flow.go`
- `pkg/jwxt/internal/login/redirect.go`
- `pkg/jwxt/internal/login/session.go`
- 登录成功验证逻辑。

验证：

- 单元测试通过。
- 手动 live test 可以登录。
- 错误密码能返回安全错误。

### M6：Demo

交付：

- `cmd/jwxt-demo/main.go`

验证：

```bash
go run ./cmd/jwxt-demo
```

## 13. 最终验收标准

第一阶段完成后，应满足：

- `go test ./...` 通过。
- `go vet ./...` 通过。
- 默认测试不访问真实学校系统。
- demo 可以安全读取账号密码。
- `InspectLoginFlow` 不提交账号密码。
- `Login` 可以完成 CAS 到 EAMS 的登录闭环。
- 错误账号密码不会被误判为成功。
- 登录成功不只依赖 HTTP 200。
- 代码中没有全局 CookieJar。
- 代码中没有保存密码。
- 代码中没有输出 Cookie、ticket、完整 URL、HTML 正文。

## 14. 后续阶段衔接

第一阶段完成后，再进入第二阶段：

1. `pkg/jwxt` 增加课表页面访问。
2. `pkg/jwxt/parser` 增加课表 HTML 解析。
3. 返回统一的 `[]Course`。
4. 新增 `internal/jwxtsync`。
5. 新增 `schedule` 域。
6. 再考虑 Redis 缓存、MySQL 快照、Hertz API。

这保证项目始终从最小可验证链路向外扩展，而不是一开始就把系统复杂度全部堆起来。
