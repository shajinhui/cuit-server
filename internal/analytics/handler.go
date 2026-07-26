package analytics

import (
	"context"
	"crypto/subtle"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	apiresponse "cuit-server/internal/platform/response"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
)

type Handler struct {
	collector *Collector
	token     string
}

func NewHandler(collector *Collector, token string) *Handler {
	return &Handler{collector: collector, token: token}
}

func (h *Handler) Register(server *server.Hertz) {
	server.GET("/api/v1/admin/stats", h.stats)
}

func (h *Handler) stats(ctx context.Context, c *app.RequestContext) {
	if !h.authorized(string(c.Request.Header.Peek("Authorization"))) {
		c.Header("WWW-Authenticate", "Bearer")
		apiresponse.Error(c, http.StatusUnauthorized, 40100, "未授权")
		return
	}
	days := 30
	if rawDays := strings.TrimSpace(c.Query("days")); rawDays != "" {
		value, err := strconv.Atoi(rawDays)
		if err != nil || value < 1 || value > 365 {
			apiresponse.Error(c, http.StatusBadRequest, 40000, "days 必须在 1 到 365 之间")
			return
		}
		days = value
	}
	requestCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	stats, err := h.collector.Stats(requestCtx, days)
	if err != nil {
		log.Printf("读取服务统计失败: %v", err)
		apiresponse.Error(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
		return
	}
	apiresponse.Success(c, stats)
}

func (h *Handler) authorized(header string) bool {
	expected := "Bearer " + h.token
	if len(header) != len(expected) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(header), []byte(expected)) == 1
}
