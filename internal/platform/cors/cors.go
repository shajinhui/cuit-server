package cors

import (
	"context"
	"net/http"
	"strings"

	"github.com/cloudwego/hertz/pkg/app"
)

// New 只允许正式前端来源携带 Cookie 访问 API。
func New(allowedOrigin string) app.HandlerFunc {
	allowedOrigin = strings.TrimSpace(allowedOrigin)

	return func(ctx context.Context, c *app.RequestContext) {
		origin := strings.TrimSpace(string(c.GetHeader("Origin")))
		if origin == "" {
			c.Next(ctx)
			return
		}
		if origin != allowedOrigin {
			c.AbortWithStatus(http.StatusForbidden)
			return
		}

		c.Header("Access-Control-Allow-Origin", allowedOrigin)
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type")
		c.Header("Vary", "Origin")

		if string(c.Method()) == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next(ctx)
	}
}
