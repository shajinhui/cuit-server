CREATE TABLE IF NOT EXISTS api_metrics_five_minute (
    bucket TEXT NOT NULL,
    method TEXT NOT NULL,
    route TEXT NOT NULL,
    status_class INTEGER NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    duration_ms_total INTEGER NOT NULL DEFAULT 0,
    duration_ms_max INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (bucket, method, route, status_class)
);

CREATE INDEX IF NOT EXISTS idx_api_metrics_five_minute_bucket
ON api_metrics_five_minute(bucket);
