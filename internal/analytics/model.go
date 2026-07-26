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
	PeriodDays  int          `json:"period_days"`
	GeneratedAt time.Time    `json:"generated_at"`
	Summary     StatsSummary `json:"summary"`
	Daily       []DailyStats `json:"daily"`
	TopRoutes   []RouteStats `json:"top_routes"`
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
