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

type StatsPeriod struct {
	Key         string
	Granularity string
	BucketMins  int
	BucketCount int
	Days        int
}

var statsPeriods = map[string]StatsPeriod{
	"1h":  {Key: "1h", Granularity: "5_minutes", BucketMins: 5, BucketCount: 12, Days: 1},
	"6h":  {Key: "6h", Granularity: "30_minutes", BucketMins: 30, BucketCount: 12, Days: 1},
	"24h": {Key: "24h", Granularity: "hour", BucketMins: 60, BucketCount: 24, Days: 1},
	"7d":  {Key: "7d", Granularity: "6_hours", BucketMins: 360, BucketCount: 28, Days: 7},
	"30d": {Key: "30d", Granularity: "day", BucketMins: 1440, BucketCount: 30, Days: 30},
	"90d": {Key: "90d", Granularity: "day", BucketMins: 1440, BucketCount: 90, Days: 90},
}

func ParseStatsPeriod(value string) (StatsPeriod, bool) {
	period, ok := statsPeriods[value]
	return period, ok
}

func statsPeriodForDays(days int) StatsPeriod {
	return StatsPeriod{
		Key:         fmt.Sprintf("%dd", days),
		Granularity: "day",
		BucketMins:  1440,
		BucketCount: days,
		Days:        days,
	}
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Flush(
	ctx context.Context,
	requests []RequestMetric,
	activities []UserActivity,
	devices []UserDevice,
) error {
	if len(requests) == 0 && len(activities) == 0 && len(devices) == 0 {
		return nil
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("analytics: begin flush: %w", err)
	}
	defer tx.Rollback()

	for _, metric := range requests {
		if _, err := tx.ExecContext(ctx, `
INSERT INTO api_metrics_five_minute (
    bucket, method, route, status_class,
    request_count, duration_ms_total, duration_ms_max
)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(bucket, method, route, status_class) DO UPDATE SET
    request_count = request_count + excluded.request_count,
    duration_ms_total = duration_ms_total + excluded.duration_ms_total,
    duration_ms_max = MAX(duration_ms_max, excluded.duration_ms_max)`,
			metric.Bucket,
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

	for _, device := range devices {
		if _, err := tx.ExecContext(ctx, `
INSERT INTO user_devices (
    user_id, platform, brand, first_seen_at, last_seen_at
)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT(user_id) DO UPDATE SET
    platform = excluded.platform,
    brand = excluded.brand,
    first_seen_at = MIN(first_seen_at, excluded.first_seen_at),
    last_seen_at = MAX(last_seen_at, excluded.last_seen_at)`,
			device.UserID,
			device.Platform,
			device.Brand,
			device.FirstSeenAt.UTC(),
			device.LastSeenAt.UTC(),
		); err != nil {
			return fmt.Errorf("analytics: save user device: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("analytics: commit flush: %w", err)
	}
	return nil
}

func (r *Repository) Stats(ctx context.Context, days int, now time.Time) (Stats, error) {
	return r.StatsForPeriod(ctx, statsPeriodForDays(days), now)
}

func (r *Repository) StatsForPeriod(ctx context.Context, period StatsPeriod, now time.Time) (Stats, error) {
	today := now.In(chinaLocation)
	start := periodStart(period, today)
	startDay := today.AddDate(0, 0, -(period.Days - 1)).Format(time.DateOnly)
	startHour := start.UTC().Format(time.RFC3339)
	endHour := today.Truncate(5 * time.Minute).UTC().Format(time.RFC3339)
	result := Stats{
		PeriodDays:  period.Days,
		Period:      period.Key,
		Granularity: period.Granularity,
		GeneratedAt: now.UTC(),
		Daily:       make([]DailyStats, 0, period.Days),
		Timeline:    make([]RequestStats, period.BucketCount),
	}
	for index := range result.Timeline {
		bucketTime := start.Add(time.Duration(index*period.BucketMins) * time.Minute)
		result.Timeline[index].Time = bucketTime.Format(time.RFC3339)
	}
	dailyByDate := make(map[string]*DailyStats, period.Days)
	for offset := period.Days - 1; offset >= 0; offset-- {
		date := today.AddDate(0, 0, -offset).Format(time.DateOnly)
		result.Daily = append(result.Daily, DailyStats{Date: date})
		dailyByDate[date] = &result.Daily[len(result.Daily)-1]
	}

	if err := r.readUsers(ctx, start, startDay, dailyByDate, &result); err != nil {
		return Stats{}, err
	}
	if err := r.readDevices(ctx, &result); err != nil {
		return Stats{}, err
	}
	if err := r.readActivity(ctx, startDay, today, dailyByDate, &result); err != nil {
		return Stats{}, err
	}
	if err := r.readRequests(ctx, startHour, endHour, start, period, dailyByDate, &result); err != nil {
		return Stats{}, err
	}
	topRoutes, err := r.readTopRoutes(ctx, startHour, endHour)
	if err != nil {
		return Stats{}, err
	}
	result.TopRoutes = topRoutes
	return result, nil
}

func periodStart(period StatsPeriod, now time.Time) time.Time {
	if period.BucketMins >= 1440 {
		current := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, chinaLocation)
		return current.Add(-time.Duration(period.BucketCount-1) * 24 * time.Hour)
	}
	current := now.Truncate(time.Minute)
	if period.BucketMins >= 60 {
		bucketHours := period.BucketMins / 60
		current = time.Date(
			current.Year(), current.Month(), current.Day(),
			(current.Hour()/bucketHours)*bucketHours,
			0, 0, 0, chinaLocation,
		)
	} else {
		current = time.Date(
			current.Year(), current.Month(), current.Day(), current.Hour(),
			(current.Minute()/period.BucketMins)*period.BucketMins,
			0, 0, chinaLocation,
		)
	}
	return current.Add(-time.Duration(period.BucketCount-1) * time.Duration(period.BucketMins) * time.Minute)
}

func (r *Repository) readDevices(ctx context.Context, result *Stats) error {
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM user_devices`).Scan(
		&result.Devices.TrackedUsers,
	); err != nil {
		return fmt.Errorf("analytics: count tracked devices: %w", err)
	}
	result.Devices.UntrackedUsers = max(result.Summary.TotalUsers-result.Devices.TrackedUsers, 0)

	platforms, err := r.readDeviceGroups(ctx, "platform")
	if err != nil {
		return err
	}
	brands, err := r.readDeviceGroups(ctx, "brand")
	if err != nil {
		return err
	}
	result.Devices.Platforms = platforms
	result.Devices.Brands = brands
	return nil
}

func (r *Repository) readDeviceGroups(ctx context.Context, column string) ([]DeviceGroup, error) {
	if column != "platform" && column != "brand" {
		return nil, fmt.Errorf("analytics: unsupported device group %q", column)
	}
	rows, err := r.db.QueryContext(ctx, fmt.Sprintf(`
SELECT %s, COUNT(*) AS users
FROM user_devices
GROUP BY %s
ORDER BY users DESC, %s`, column, column, column))
	if err != nil {
		return nil, fmt.Errorf("analytics: list device %s groups: %w", column, err)
	}
	defer rows.Close()

	result := make([]DeviceGroup, 0)
	for rows.Next() {
		var group DeviceGroup
		if err := rows.Scan(&group.Name, &group.Count); err != nil {
			return nil, fmt.Errorf("analytics: scan device %s group: %w", column, err)
		}
		result = append(result, group)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("analytics: iterate device %s groups: %w", column, err)
	}
	return result, nil
}

func (r *Repository) readUsers(
	ctx context.Context,
	start time.Time,
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
		if !createdAt.Before(start) {
			result.Summary.NewUsersPeriod++
		}
		if day >= startDay {
			if daily := dailyByDate[day]; daily != nil {
				daily.NewUsers++
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
	endHour string,
	start time.Time,
	period StatsPeriod,
	dailyByDate map[string]*DailyStats,
	result *Stats,
) error {
	rows, err := r.db.QueryContext(ctx, `
WITH request_metrics AS (
	SELECT hour AS bucket, status_class, request_count, duration_ms_total, duration_ms_max
	FROM api_metrics_hourly
	WHERE hour >= ? AND hour <= ?
	UNION ALL
	SELECT bucket, status_class, request_count, duration_ms_total, duration_ms_max
	FROM api_metrics_five_minute
	WHERE bucket >= ? AND bucket <= ?
)
SELECT
	bucket,
	SUM(request_count),
	SUM(CASE WHEN status_class = 4 THEN request_count ELSE 0 END),
	SUM(CASE WHEN status_class >= 5 THEN request_count ELSE 0 END),
	SUM(duration_ms_total),
	MAX(duration_ms_max)
FROM request_metrics
GROUP BY bucket
ORDER BY bucket`, startHour, endHour, startHour, endHour)
	if err != nil {
		return fmt.Errorf("analytics: list request metrics: %w", err)
	}
	defer rows.Close()
	var totalDuration int64
	dailyDuration := make(map[string]int64, len(dailyByDate))
	timelineDuration := make([]int64, len(result.Timeline))
	for rows.Next() {
		var rawHour string
		var requests int64
		var clientErrors int64
		var serverErrors int64
		var duration int64
		var maxDuration int64
		if err := rows.Scan(&rawHour, &requests, &clientErrors, &serverErrors, &duration, &maxDuration); err != nil {
			return fmt.Errorf("analytics: scan request metrics: %w", err)
		}
		hour, err := time.Parse(time.RFC3339, rawHour)
		if err != nil {
			return fmt.Errorf("analytics: parse request metric hour: %w", err)
		}
		localHour := hour.In(chinaLocation)
		day := localHour.Format(time.DateOnly)
		if daily := dailyByDate[day]; daily != nil {
			daily.RequestCount += requests
			daily.ErrorCount += clientErrors + serverErrors
			dailyDuration[day] += duration
		}
		bucketIndex := int(localHour.Sub(start) / (time.Duration(period.BucketMins) * time.Minute))
		if bucketIndex >= 0 && bucketIndex < len(result.Timeline) {
			bucket := &result.Timeline[bucketIndex]
			bucket.RequestCount += requests
			bucket.ClientErrorCount += clientErrors
			bucket.ServerErrorCount += serverErrors
			bucket.MaxLatencyMS = max(bucket.MaxLatencyMS, maxDuration)
			timelineDuration[bucketIndex] += duration
		}
		result.Summary.RequestsPeriod += requests
		result.Summary.ClientErrors += clientErrors
		result.Summary.ServerErrors += serverErrors
		result.Summary.ErrorsPeriod += clientErrors + serverErrors
		result.Summary.MaxLatencyMS = max(result.Summary.MaxLatencyMS, maxDuration)
		totalDuration += duration
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("analytics: iterate request metrics: %w", err)
	}
	for day, duration := range dailyDuration {
		daily := dailyByDate[day]
		daily.AverageLatencyMS = average(duration, daily.RequestCount)
	}
	for index, duration := range timelineDuration {
		result.Timeline[index].AverageLatencyMS = average(duration, result.Timeline[index].RequestCount)
	}
	result.Summary.AverageLatencyMS = average(totalDuration, result.Summary.RequestsPeriod)
	return nil
}

func (r *Repository) readTopRoutes(ctx context.Context, startHour string, endHour string) ([]RouteStats, error) {
	rows, err := r.db.QueryContext(ctx, `
WITH request_metrics AS (
	SELECT hour AS bucket, method, route, status_class, request_count, duration_ms_total, duration_ms_max
	FROM api_metrics_hourly
	WHERE hour >= ? AND hour <= ?
	UNION ALL
	SELECT bucket, method, route, status_class, request_count, duration_ms_total, duration_ms_max
	FROM api_metrics_five_minute
	WHERE bucket >= ? AND bucket <= ?
)
SELECT
    method,
    route,
	SUM(request_count) AS requests,
	SUM(CASE WHEN status_class >= 4 THEN request_count ELSE 0 END) AS errors,
	SUM(CASE WHEN status_class = 4 THEN request_count ELSE 0 END) AS client_errors,
	SUM(CASE WHEN status_class >= 5 THEN request_count ELSE 0 END) AS server_errors,
	SUM(duration_ms_total) AS duration,
    MAX(duration_ms_max) AS max_duration
FROM request_metrics
GROUP BY method, route
ORDER BY requests DESC, method, route
LIMIT 20`, startHour, endHour, startHour, endHour)
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
			&route.ClientErrorCount,
			&route.ServerErrorCount,
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
