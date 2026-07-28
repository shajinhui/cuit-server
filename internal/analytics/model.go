package analytics

import "time"

type RequestMetric struct {
	Hour            string
	Method          string
	Route           string
	StatusClass     int
	RequestCount    int64
	DurationMSTotal int64
	DurationMSMax   int64
}

type UserActivity struct {
	Day          string
	UserID       int64
	RequestCount int64
	FirstSeenAt  time.Time
	LastSeenAt   time.Time
}

type Stats struct {
	PeriodDays  int            `json:"period_days"`
	GeneratedAt time.Time      `json:"generated_at"`
	Summary     StatsSummary   `json:"summary"`
	Cache       CacheStats     `json:"cache"`
	Daily       []DailyStats   `json:"daily"`
	TopRoutes   []RouteStats   `json:"top_routes"`
	Feedback    []FeedbackItem `json:"feedback"`
}

type StatsSummary struct {
	TotalUsers       int64   `json:"total_users"`
	NewUsersToday    int64   `json:"new_users_today"`
	NewUsersPeriod   int64   `json:"new_users_period"`
	DAUToday         int64   `json:"dau_today"`
	WAU              int64   `json:"wau"`
	MAU              int64   `json:"mau"`
	RequestsPeriod   int64   `json:"requests_period"`
	ErrorsPeriod     int64   `json:"errors_period"`
	AverageLatencyMS float64 `json:"average_latency_ms"`
}

type DailyStats struct {
	Date             string  `json:"date"`
	NewUsers         int64   `json:"new_users"`
	ActiveUsers      int64   `json:"active_users"`
	RequestCount     int64   `json:"request_count"`
	ErrorCount       int64   `json:"error_count"`
	AverageLatencyMS float64 `json:"average_latency_ms"`
}

type RouteStats struct {
	Method           string  `json:"method"`
	Route            string  `json:"route"`
	RequestCount     int64   `json:"request_count"`
	ErrorCount       int64   `json:"error_count"`
	AverageLatencyMS float64 `json:"average_latency_ms"`
	MaxLatencyMS     int64   `json:"max_latency_ms"`
}

type CacheStats struct {
	Enabled           bool      `json:"enabled"`
	Reachable         bool      `json:"reachable"`
	StartedAt         time.Time `json:"started_at"`
	Requests          uint64    `json:"requests"`
	Hits              uint64    `json:"hits"`
	SourceLoads       uint64    `json:"source_loads"`
	CoalescedRequests uint64    `json:"coalesced_requests"`
	ReadErrors        uint64    `json:"read_errors"`
	WriteErrors       uint64    `json:"write_errors"`
	Keys              int64     `json:"keys"`
	MemoryBytes       uint64    `json:"memory_bytes"`
	EvictedKeys       uint64    `json:"evicted_keys"`
	ExpiredKeys       uint64    `json:"expired_keys"`
}

type FeedbackItem struct {
	ID        int64     `json:"id"`
	Type      string    `json:"type"`
	Platform  string    `json:"platform"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}
