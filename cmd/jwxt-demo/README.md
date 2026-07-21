# jwxt-demo

命令行验证入口目录。

当前用于：

- 安全读取学号和密码。
- 调用 `pkg/jwxt` 完成最小登录验证。
- 通过可选的学年、学期参数查询全部成绩字段。
- 输出登录结果、具体错误信息或成绩 JSON。

入口文件为 `main.go`。

```bash
go run ./cmd/jwxt-demo
go run ./cmd/jwxt-demo 2025-2026 2
```
