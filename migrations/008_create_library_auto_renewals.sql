CREATE TABLE IF NOT EXISTS library_auto_renewals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_token_hash BLOB NOT NULL,
    reservation_id TEXT NOT NULL,
    reservation_uuid TEXT NOT NULL DEFAULT '',
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    reservation_end TEXT NOT NULL,
    execute_at INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'running', 'succeeded', 'failed', 'cancelled', 'skipped')),
    attempt_count INTEGER NOT NULL DEFAULT 0,
    claimed_at INTEGER,
    completed_at INTEGER,
    last_message TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE (user_id, reservation_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_library_auto_renewals_due
ON library_auto_renewals(status, execute_at);

CREATE INDEX IF NOT EXISTS idx_library_auto_renewals_user
ON library_auto_renewals(user_id, updated_at DESC);

-- 自动续座由开启它的设备会话负责。该设备退出登录后，尚未执行的任务立即关闭；
-- 已经进入 running 的外部写操作不强行中断，避免产生“已提交但本地记为取消”的歧义。
CREATE TRIGGER IF NOT EXISTS cancel_library_auto_renewals_after_session_logout
AFTER DELETE ON academic_sessions
BEGIN
    UPDATE library_auto_renewals
    SET status = 'cancelled',
        completed_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000,
        last_message = '登录已退出，自动续座已关闭',
        updated_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000
    WHERE session_token_hash = OLD.token_hash
      AND status = 'scheduled';
END;
