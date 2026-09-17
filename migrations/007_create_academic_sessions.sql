CREATE TABLE IF NOT EXISTS academic_sessions (
    token_hash BLOB PRIMARY KEY,
    user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_academic_sessions_user_id
ON academic_sessions(user_id);

-- 迁移旧版每个用户仅保存一个 Token 的登录状态，随后清空旧字段，避免以后启动时
-- 把已经退出的历史会话重新导入。旧字段暂时保留，便于平滑升级现有数据库。
INSERT OR IGNORE INTO academic_sessions (token_hash, user_id, created_at, updated_at)
SELECT
    session_token_hash,
    id,
    COALESCE(last_login_at, CURRENT_TIMESTAMP),
    updated_at
FROM users
WHERE session_token_hash IS NOT NULL;

UPDATE users
SET session_token_hash = NULL
WHERE session_token_hash IS NOT NULL;
