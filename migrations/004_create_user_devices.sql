CREATE TABLE IF NOT EXISTS user_devices (
    user_id INTEGER PRIMARY KEY,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    brand TEXT NOT NULL,
    first_seen_at TEXT NOT NULL,
    last_seen_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_devices_platform
ON user_devices(platform);

CREATE INDEX IF NOT EXISTS idx_user_devices_brand
ON user_devices(brand);

-- 已提交过反馈的用户可以使用现有平台字段完成首次回填。
INSERT OR IGNORE INTO user_devices (user_id, platform, brand, first_seen_at, last_seen_at)
SELECT
    feedback.user_id,
    feedback.platform,
    CASE feedback.platform WHEN 'ios' THEN 'Apple' ELSE '其他 Android' END,
    feedback.created_at,
    feedback.created_at
FROM feedback
WHERE feedback.id = (
    SELECT latest.id
    FROM feedback AS latest
    WHERE latest.user_id = feedback.user_id
    ORDER BY latest.created_at DESC, latest.id DESC
    LIMIT 1
);
