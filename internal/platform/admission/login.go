package admission

import (
	"context"
	"errors"
	"math"
	"net/http"
	"strconv"
	"time"

	apiresponse "cuit-server/internal/platform/response"
	"github.com/cloudwego/hertz/pkg/app"
)

const (
	loginBusyCode    = 50301
	loginBusyMessage = "当前登录人数较多，请稍后重试"
)

type LoginGate struct {
	slots             chan struct{}
	retryAfterSeconds int
}

func NewLoginGate(maxConcurrent int, retryAfter time.Duration) (*LoginGate, error) {
	if maxConcurrent < 1 {
		return nil, errors.New("login admission: max concurrency must be positive")
	}
	if retryAfter <= 0 {
		return nil, errors.New("login admission: retry delay must be positive")
	}
	return &LoginGate{
		slots:             make(chan struct{}, maxConcurrent),
		retryAfterSeconds: int(math.Ceil(retryAfter.Seconds())),
	}, nil
}

// Middleware 只允许固定数量的登录请求进入，不在服务端积压等待请求。
func (g *LoginGate) Middleware() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		select {
		case g.slots <- struct{}{}:
			defer func() { <-g.slots }()
			c.Next(ctx)
		default:
			c.Header("Retry-After", strconv.Itoa(g.retryAfterSeconds))
			apiresponse.Error(
				c,
				http.StatusServiceUnavailable,
				loginBusyCode,
				loginBusyMessage,
			)
			c.Abort()
		}
	}
}
