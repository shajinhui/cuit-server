package analytics

import (
	"context"
	"database/sql"
	"fmt"
	"time"
)

var chinaLocation = time.FixedZone("Asia/Shanghai", 8*60*60)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Flush(
	ctx context.Context,
	requests []RequestMetric,
	activities []UserActivity,
) error {
	if len(requests) == 0 && len(activities) == 0 {
		return nil
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("analytics: begin flush: %w", err)
	}
	defer tx.Rollback()

	for _, metric := range requests {
		if _, err := tx.ExecContext(ctx, `
INSERT INTO api_metrics_hourly (
    hour, method, route, status_class,
    request_count, duration_ms_total, duration_ms_max
)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(hour, method, route, status_class) DO UPDATE SET
    request_count = request_count + excluded.request_count,
    duration_ms_total = duration_ms_total + excluded.duration_ms_total,
    duration_ms_max = MAX(duration_ms_max, excluded.duration_ms_max)`,
			metric.Hour,
			metric.Method,
			metric.Route,
			metric.StatusClass,
			metric.RequestCount,
			metric.DurationMSTotal,
			metric.DurationMSMax,
		); err != nil {
			return fmt.Errorf("analytics: save request metrics: %w", err)
		}
	}

	for _, activity := range activities {
		if _, err := tx.ExecContext(ctx, `
INSERT INTO user_activity_daily (
    day, user_id, request_count, first_seen_at, last_seen_at
)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT(day, user_id) DO UPDATE SET
    request_count = request_count + excluded.request_count,
    first_seen_at = MIN(first_seen_at, excluded.first_seen_at),
    last_seen_at = MAX(last_seen_at, excluded.last_seen_at)`,
			activity.Day,
			activity.UserID,
			activity.RequestCount,
			activity.FirstSeenAt.UTC(),
			activity.LastSeenAt.UTC(),
		); err != nil {
			return fmt.Errorf("analytics: save user activity: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("analytics: commit flush: %w", err)
	}
	return nil
}

func (r *Repository) Stats(ctx context.Context, days int, now time.Time) (Stats, error) {
	today := now.In(chinaLocation)
	startDay := today.AddDate(0, 0, -(days - 1)).Format(time.DateOnly)
	startHour := time.Date(
		today.Year(),
		today.Month(),
		today.Day(),
		0,
		0,
		0,
		0,
		chinaLocation,
	).AddDate(0, 0, -(days - 1)).UTC().Format(time.RFC3339)
	result := Stats{
		PeriodDays:  days,
		GeneratedAt: now.UTC(),
		Daily:       make([]DailyStats, 0, days),
	}
	dailyByDate := make(map[string]*DailyStats, days)
	for offset := days - 1; offset >= 0; offset-- {
		date := today.AddDate(0, 0, -offset).Format(time.DateOnly)
		result.Daily = append(result.Daily, DailyStats{Date: date})
		dailyByDate[date] = &result.Daily[len(result.Daily)-1]
	}

	if err := r.readUsers(ctx, startDay, dailyByDate, &result); err != nil {
		return Stats{}, err
	}
	if err := r.readActivity(ctx, startDay, today, dailyByDate, &result); err != nil {
		return Stats{}, err
	}
	if err := r.readRequests(ctx, startHour, dailyByDate, &result); err != nil {
		return Stats{}, err
	}
	topRoutes, err := r.readTopRoutes(ctx, startHour)
	if err != nil {
		return Stats{}, err
	}
	result.TopRoutes = topRoutes
	return result, nil
}

func (r *Repository) readUsers(
	ctx context.Context,
	startDay string,
	dailyByDate map[string]*DailyStats,
	result *Stats,
) error {
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM users`).Scan(&result.Summary.TotalUsers); err != nil {
		return fmt.Errorf("analytics: count users: %w", err)
	}
	rows, err := r.db.QueryContext(ctx, `SELECT created_at FROM users`)
	if err != nil {
		return fmt.Errorf("analytics: list new users: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var rawCreatedAt string
		if err := rows.Scan(&rawCreatedAt); err != nil {
			return fmt.Errorf("analytics: scan new users: %w", err)
		}
		createdAt, err := parseStoredTime(rawCreatedAt)
		if err != nil {
			return fmt.Errorf("analytics: parse user creation time: %w", err)
		}
		day := createdAt.In(chinaLocation).Format(time.DateOnly)
		if day >= startDay {
			if daily := dailyByDate[day]; daily != nil {
				daily.NewUsers++
				result.Summary.NewUsersPeriod++
			}
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("analytics: iterate new users: %w", err)
	}
	if len(result.Daily) > 0 {
		result.Summary.NewUsersToday = result.Daily[len(result.Daily)-1].NewUsers
	}
	return nil
}

func parseStoredTime(value string) (time.Time, error) {
	layouts := []struct {
		layout   string
		location *time.Location
	}{
		{time.RFC3339Nano, nil},
		{"2006-01-02 15:04:05.999999999 -0700 MST", nil},
		{"2006-01-02 15:04:05 -0700 MST", nil},
		{"2006-01-02 15:04:05.999999999", time.UTC},
		{"2006-01-02 15:04:05", time.UTC},
	}
	for _, candidate := range layouts {
		var parsed time.Time
		var err error
		if candidate.location == nil {
			parsed, err = time.Parse(candidate.layout, value)
		} else {
			parsed, err = time.ParseInLocation(candidate.layout, value, candidate.location)
		}
		if err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("unsupported timestamp %q", value)
}

func (r *Repository) readActivity(
	ctx context.Context,
	startDay string,
	today time.Time,
	dailyByDate map[string]*DailyStats,
	result *Stats,
) error {
	rows, err := r.db.QueryContext(ctx, `
SELECT day, COUNT(DISTINCT user_id)
FROM user_activity_daily
WHERE day >= ?
GROUP BY day
ORDER BY day`, startDay)
	if err != nil {
		return fmt.Errorf("analytics: list active users: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var day string
		var count int64
		if err := rows.Scan(&day, &count); err != nil {
			return fmt.Errorf("analytics: scan active users: %w", err)
		}
		if daily := dailyByDate[day]; daily != nil {
			daily.ActiveUsers = count
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("analytics: iterate active users: %w", err)
	}
	if len(result.Daily) > 0 {
		result.Summary.DAUToday = result.Daily[len(result.Daily)-1].ActiveUsers
	}
	weekStart := today.AddDate(0, 0, -6).Format(time.DateOnly)
	monthStart := today.AddDate(0, 0, -29).Format(time.DateOnly)
	if err := r.db.QueryRowContext(
		ctx,
		`SELECT COUNT(DISTINCT user_id) FROM user_activity_daily WHERE day >= ?`,
		weekStart,
	).Scan(&result.Summary.WAU); err != nil {
		return fmt.Errorf("analytics: count weekly active users: %w", err)
	}
	if err := r.db.QueryRowContext(
		ctx,
		`SELECT COUNT(DISTINCT user_id) FROM user_activity_daily WHERE day >= ?`,
		monthStart,
	).Scan(&result.Summary.MAU); err != nil {
		return fmt.Errorf("analytics: count monthly active users: %w", err)
	}
	return nil
}

func (r *Repository) readRequests(
	ctx context.Context,
	startHour string,
	dailyByDate map[string]*DailyStats,
	result *Stats,
) error {
	rows, err := r.db.QueryContext(ctx, `
SELECT
    date(hour, '+8 hours') AS day,
    SUM(request_count),
    SUM(CASE WHEN status_class >= 4 THEN request_count ELSE 0 END),
    SUM(duration_ms_total)
FROM api_metrics_hourly
WHERE hour >= ?
GROUP BY day
ORDER BY day`, startHour)
	if err != nil {
		return fmt.Errorf("analytics: list request metrics: %w", err)
	}
	defer rows.Close()
	var totalDuration int64
	for rows.Next() {
		var day string
		var requests int64
		var errors int64
		var duration int64
		if err := rows.Scan(&day, &requests, &errors, &duration); err != nil {
			return fmt.Errorf("analytics: scan request metrics: %w", err)
		}
		daily := dailyByDate[day]
		if daily == nil {
			continue
		}
		daily.RequestCount = requests
		daily.ErrorCount = errors
		daily.AverageLatencyMS = average(duration, requests)
		result.Summary.RequestsPeriod += requests
		result.Summary.ErrorsPeriod += errors
		totalDuration += duration
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("analytics: iterate request metrics: %w", err)
	}
	result.Summary.AverageLatencyMS = average(totalDuration, result.Summary.RequestsPeriod)
	return nil
}

func (r *Repository) readTopRoutes(ctx context.Context, startHour string) ([]RouteStats, error) {
	rows, err := r.db.QueryContext(ctx, `
SELECT
    method,
    route,
    SUM(request_count) AS requests,
    SUM(CASE WHEN status_class >= 4 THEN request_count ELSE 0 END) AS errors,
    SUM(duration_ms_total) AS duration,
    MAX(duration_ms_max) AS max_duration
FROM api_metrics_hourly
WHERE hour >= ?
GROUP BY method, route
ORDER BY requests DESC, method, route
LIMIT 20`, startHour)
	if err != nil {
		return nil, fmt.Errorf("analytics: list top routes: %w", err)
	}
	defer rows.Close()
	var result []RouteStats
	for rows.Next() {
		var route RouteStats
		var duration int64
		if err := rows.Scan(
			&route.Method,
			&route.Route,
			&route.RequestCount,
			&route.ErrorCount,
			&duration,
			&route.MaxLatencyMS,
		); err != nil {
			return nil, fmt.Errorf("analytics: scan top routes: %w", err)
		}
		route.AverageLatencyMS = average(duration, route.RequestCount)
		result = append(result, route)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("analytics: iterate top routes: %w", err)
	}
	if result == nil {
		result = []RouteStats{}
	}
	return result, nil
}

func average(total int64, count int64) float64 {
	if count == 0 {
		return 0
	}
	return float64(total) / float64(count)
}
