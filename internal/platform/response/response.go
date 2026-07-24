package response

import (
	"net/http"

	"github.com/cloudwego/hertz/pkg/app"
)

// Body 是所有 HTTP API 共用的响应外壳，业务数据只放在 Data 中。
type Body struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data"`
}

func Success(c *app.RequestContext, data any) {
	// 登录、成绩和课表响应都包含用户数据，统一禁止浏览器及中间代理缓存。
	c.Header("Cache-Control", "no-store")
	c.JSON(http.StatusOK, Body{Code: 0, Message: "success", Data: data})
}

func Error(c *app.RequestContext, status int, code int, message string) {
	c.Header("Cache-Control", "no-store")
	c.JSON(status, Body{Code: code, Message: message, Data: nil})
}
