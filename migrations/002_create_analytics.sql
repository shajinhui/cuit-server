CREATE TABLE IF NOT EXISTS api_metrics_hourly (
    hour TEXT NOT NULL,
    method TEXT NOT NULL,
    route TEXT NOT NULL,
    status_class INTEGER NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    duration_ms_total INTEGER NOT NULL DEFAULT 0,
    duration_ms_max INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (hour, method, route, status_class)
);

CREATE INDEX IF NOT EXISTS idx_api_metrics_hourly_hour
ON api_metrics_hourly(hour);

CREATE TABLE IF NOT EXISTS user_activity_daily (
    day TEXT NOT NULL,
    user_id INTEGER NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    first_seen_at TEXT NOT NULL,
    last_seen_at TEXT NOT NULL,
    PRIMARY KEY (day, user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_activity_daily_day
ON user_activity_daily(day);
