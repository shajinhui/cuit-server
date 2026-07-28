CREATE TABLE IF NOT EXISTS feedback (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    feedback_type TEXT NOT NULL CHECK (feedback_type IN ('suggestion', 'bug')),
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    content TEXT NOT NULL CHECK (length(content) BETWEEN 10 AND 2000),
    user_agent TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_feedback_user_created_at
ON feedback(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_feedback_created_at
ON feedback(created_at DESC);
