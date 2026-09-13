package analytics

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"path/filepath"
	"testing"
	"time"

	"cuit-server/internal/feedback"
	platformcache "cuit-server/internal/platform/cache"
	"cuit-server/internal/platform/database"
	"cuit-server/migrations"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

type fixedUserResolver struct {
	userID int64
}

func (r fixedUserResolver) ResolveUserID(context.Context, string) (int64, error) {
	return r.userID, nil
}

func TestCollectorAggregatesRequestsAndActiveUsers(t *testing.T) {
	db := openTestDatabase(t)
	userID := insertTestUser(t, db)
	repository := NewRepository(db)
	collector := NewCollector(repository, fixedUserResolver{userID: userID}, "campus_session", time.Hour)
	now := time.Date(2026, 7, 26, 4, 30, 0, 0, time.UTC)
	collector.now = func() time.Time { return now }

	h := server.Default()
	h.Use(collector.Middleware())
	h.GET("/api/v1/items/:id", func(_ context.Context, c *app.RequestContext) {
		c.Status(http.StatusOK)
	})
	response := ut.PerformRequest(
		h.Engine,
		http.MethodGet,
		"/api/v1/items/42",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
		ut.Header{Key: "X-Client-Platform", Value: "android"},
		ut.Header{Key: "X-Client-Brand", Value: "Xiaomi"},
	).Result()
	if response.StatusCode() != http.StatusOK {
		t.Fatalf("unexpected response status: %d", response.StatusCode())
	}
	collector.Record(now, http.MethodPost, "/api/v1/failing", http.StatusBadGateway, 80*time.Millisecond, 0)

	stats, err := collector.Stats(context.Background(), 7)
	if err != nil {
		t.Fatal(err)
	}
	if stats.Summary.TotalUsers != 1 ||
		stats.Summary.NewUsersToday != 1 ||
		stats.Summary.NewUsersPeriod != 1 ||
		stats.Summary.DAUToday != 1 ||
		stats.Summary.WAU != 1 ||
		stats.Summary.MAU != 1 {
		t.Fatalf("unexpected user summary: %+v", stats.Summary)
	}
	if stats.Summary.RequestsPeriod != 2 || stats.Summary.ErrorsPeriod != 1 {
		t.Fatalf("unexpected request summary: %+v", stats.Summary)
	}
	if len(stats.TopRoutes) != 2 {
		t.Fatalf("unexpected top routes: %+v", stats.TopRoutes)
	}
	if stats.Devices.TrackedUsers != 1 ||
		stats.Devices.UntrackedUsers != 0 ||
		len(stats.Devices.Platforms) != 1 ||
		stats.Devices.Platforms[0].Name != "android" ||
		stats.Devices.Platforms[0].Count != 1 ||
		len(stats.Devices.Brands) != 1 ||
		stats.Devices.Brands[0].Name != "Xiaomi" {
		t.Fatalf("unexpected device stats: %+v", stats.Devices)
	}
	var normalizedRouteFound bool
	for _, route := range stats.TopRoutes {
		if route.Route == "/api/v1/items/:id" {
			normalizedRouteFound = true
		}
	}
	if !normalizedRouteFound {
		t.Fatalf("route template was not recorded: %+v", stats.TopRoutes)
	}
}

func TestCollectorReturnsFineGrainedStatusAndLatencyBreakdown(t *testing.T) {
	db := openTestDatabase(t)
	collector := NewCollector(NewRepository(db), nil, "campus_session", time.Hour)
	now := time.Date(2026, 7, 26, 4, 30, 0, 0, time.UTC)
	collector.now = func() time.Time { return now }
	collector.Record(now.Add(-20*time.Minute), http.MethodGet, "/api/v1/client-error", http.StatusUnauthorized, 20*time.Millisecond, 0)
	collector.Record(now, http.MethodGet, "/api/v1/server-error", http.StatusBadGateway, 80*time.Millisecond, 0)
	collector.Record(now.Add(-2*time.Hour), http.MethodGet, "/api/v1/old-error", http.StatusBadGateway, 150*time.Millisecond, 0)
	period, ok := ParseStatsPeriod("1h")
	if !ok {
		t.Fatal("1h period is not registered")
	}

	stats, err := collector.StatsForPeriod(context.Background(), period)
	if err != nil {
		t.Fatal(err)
	}
	if stats.Period != "1h" || stats.Granularity != "5_minutes" || len(stats.Timeline) != 12 {
		t.Fatalf("unexpected period details: %+v", stats)
	}
	if stats.Summary.RequestsPeriod != 2 ||
		stats.Summary.ClientErrors != 1 ||
		stats.Summary.ServerErrors != 1 ||
		stats.Summary.MaxLatencyMS != 80 {
		t.Fatalf("unexpected request breakdown: %+v", stats.Summary)
	}
	if stats.Timeline[7].ClientErrorCount != 1 || stats.Timeline[11].ServerErrorCount != 1 {
		t.Fatalf("unexpected hourly timeline: %+v", stats.Timeline)
	}
}

func TestAdminStatsRequiresBearerToken(t *testing.T) {
	db := openTestDatabase(t)
	repository := NewRepository(db)
	collector := NewCollector(repository, nil, "campus_session", time.Hour)
	collector.now = func() time.Time {
		return time.Date(2026, 7, 26, 4, 30, 0, 0, time.UTC)
	}
	userID := insertTestUser(t, db)
	feedbackRepository := feedback.NewRepository(db)
	if _, err := feedbackRepository.Create(context.Background(), userID, feedback.Submission{
		Type:      feedback.TypeSuggestion,
		Platform:  feedback.PlatformAndroid,
		Content:   "希望统计页面可以查看用户反馈内容",
		UserAgent: "test-device",
	}); err != nil {
		t.Fatal(err)
	}
	cacheLoader := platformcache.NewLoader(platformcache.DisabledStore{})
	h := server.Default()
	NewHandler(
		collector,
		"test-admin-token",
		cacheLoader,
		feedbackRepository,
	).Register(h)

	unauthorized := ut.PerformRequest(
		h.Engine,
		http.MethodGet,
		"/api/v1/admin/stats",
		nil,
	).Result()
	if unauthorized.StatusCode() != http.StatusUnauthorized {
		t.Fatalf("unexpected unauthorized status: %d", unauthorized.StatusCode())
	}

	authorized := ut.PerformRequest(
		h.Engine,
		http.MethodGet,
		"/api/v1/admin/stats?days=7",
		nil,
		ut.Header{Key: "Authorization", Value: "Bearer test-admin-token"},
	).Result()
	if authorized.StatusCode() != http.StatusOK {
		t.Fatalf("unexpected authorized status: %d body=%s", authorized.StatusCode(), authorized.Body())
	}
	var response struct {
		Data Stats `json:"data"`
	}
	if err := json.Unmarshal(authorized.Body(), &response); err != nil {
		t.Fatal(err)
	}
	if response.Data.PeriodDays != 7 || len(response.Data.Daily) != 7 {
		t.Fatalf("unexpected stats response: %+v", response.Data)
	}
	if response.Data.Cache.Enabled ||
		response.Data.Cache.StartedAt.IsZero() ||
		len(response.Data.Feedback) != 1 ||
		response.Data.Feedback[0].Content != "希望统计页面可以查看用户反馈内容" {
		t.Fatalf("unexpected admin details: cache=%+v feedback=%+v",
			response.Data.Cache,
			response.Data.Feedback,
		)
	}

	hourly := ut.PerformRequest(
		h.Engine,
		http.MethodGet,
		"/api/v1/admin/stats?range=24h",
		nil,
		ut.Header{Key: "Authorization", Value: "Bearer test-admin-token"},
	).Result()
	if hourly.StatusCode() != http.StatusOK {
		t.Fatalf("unexpected hourly status: %d body=%s", hourly.StatusCode(), hourly.Body())
	}
	if err := json.Unmarshal(hourly.Body(), &response); err != nil {
		t.Fatal(err)
	}
	if response.Data.Period != "24h" || response.Data.Granularity != "hour" || len(response.Data.Timeline) != 24 {
		t.Fatalf("unexpected hourly response: %+v", response.Data)
	}
}

func openTestDatabase(t *testing.T) *sql.DB {
	t.Helper()
	db, err := database.OpenSQLite(context.Background(), filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := db.Close(); err != nil {
			t.Error(err)
		}
	})
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	return db
}

func insertTestUser(t *testing.T, db *sql.DB) int64 {
	t.Helper()
	result, err := db.ExecContext(context.Background(), `
INSERT INTO users (
    student_no, name, jwxt_password_enc, created_at, updated_at
)
VALUES (?, ?, ?, ?, ?)`,
		"test-student",
		"测试同学",
		[]byte("encrypted"),
		time.Date(2026, 7, 26, 3, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 26, 3, 0, 0, 0, time.UTC),
	)
	if err != nil {
		t.Fatal(err)
	}
	userID, err := result.LastInsertId()
	if err != nil {
		t.Fatal(err)
	}
	return userID
}
