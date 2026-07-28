package analytics

import (
	"context"
	"crypto/subtle"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"cuit-server/internal/feedback"
	platformcache "cuit-server/internal/platform/cache"
	apiresponse "cuit-server/internal/platform/response"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
)

type Handler struct {
	collector *Collector
	token     string
	cache     CacheStatsReader
	feedback  FeedbackReader
}

type CacheStatsReader interface {
	Snapshot(ctx context.Context) platformcache.Snapshot
}

type FeedbackReader interface {
	ListRecent(ctx context.Context, limit int) ([]feedback.Record, error)
}

func NewHandler(
	collector *Collector,
	token string,
	cache CacheStatsReader,
	feedback FeedbackReader,
) *Handler {
	return &Handler{
		collector: collector,
		token:     token,
		cache:     cache,
		feedback:  feedback,
	}
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
	stats.Cache = mapCacheStats(h.cache.Snapshot(requestCtx))
	records, err := h.feedback.ListRecent(requestCtx, 50)
	if err != nil {
		log.Printf("读取用户反馈失败: %v", err)
		apiresponse.Error(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
		return
	}
	stats.Feedback = make([]FeedbackItem, 0, len(records))
	for _, record := range records {
		stats.Feedback = append(stats.Feedback, FeedbackItem{
			ID:        record.ID,
			Type:      record.Type,
			Platform:  record.Platform,
			Content:   record.Content,
			CreatedAt: record.CreatedAt,
		})
	}
	apiresponse.Success(c, stats)
}

func mapCacheStats(snapshot platformcache.Snapshot) CacheStats {
	return CacheStats{
		Enabled:           snapshot.Enabled,
		Reachable:         snapshot.Reachable,
		StartedAt:         snapshot.StartedAt,
		Requests:          snapshot.Requests,
		Hits:              snapshot.Hits,
		SourceLoads:       snapshot.SourceLoads,
		CoalescedRequests: snapshot.CoalescedRequests,
		ReadErrors:        snapshot.ReadErrors,
		WriteErrors:       snapshot.WriteErrors,
		Keys:              snapshot.Keys,
		MemoryBytes:       snapshot.MemoryBytes,
		EvictedKeys:       snapshot.EvictedKeys,
		ExpiredKeys:       snapshot.ExpiredKeys,
	}
}

func (h *Handler) authorized(header string) bool {
	expected := "Bearer " + h.token
	if len(header) != len(expected) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(header), []byte(expected)) == 1
}
