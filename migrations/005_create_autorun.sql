-- AutoRun 持久化状态。只保存上游 token 的密文，不保存校园跑密码。
CREATE TABLE IF NOT EXISTS sessions (
    session_key TEXT PRIMARY KEY NOT NULL,
    student_id INTEGER NOT NULL UNIQUE,
    user_id INTEGER NOT NULL,
    school_id INTEGER NOT NULL,
    phone_hash TEXT NOT NULL DEFAULT '',
    token_ciphertext TEXT NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_phone_hash
ON sessions(phone_hash);

CREATE INDEX IF NOT EXISTS idx_sessions_updated_at
ON sessions(updated_at);

CREATE TABLE IF NOT EXISTS club_schedules (
    student_id INTEGER PRIMARY KEY NOT NULL,
    school_id INTEGER NOT NULL DEFAULT 0,
    session_key TEXT NOT NULL DEFAULT '',
    enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
    last_sign_in_key TEXT,
    last_sign_back_key TEXT,
    last_probe_at INTEGER,
    last_action_at INTEGER,
    last_message TEXT,
    updated_at INTEGER NOT NULL,
    refresh_date TEXT NOT NULL DEFAULT '',
    refresh_after INTEGER NOT NULL DEFAULT 0,
    refresh_queued_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_club_schedules_enabled
ON club_schedules(enabled);

CREATE INDEX IF NOT EXISTS idx_club_schedules_refresh
ON club_schedules(enabled, refresh_after, refresh_queued_at);

-- 在触碰上游签到/签退 mutation 前先 claim，Cron 或进程重试不会重复提交。
CREATE TABLE IF NOT EXISTS club_action_claims (
    student_id INTEGER NOT NULL,
    action_key TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('in_flight', 'done', 'failed')),
    claimed_at INTEGER NOT NULL,
    PRIMARY KEY (student_id, action_key)
);

CREATE INDEX IF NOT EXISTS idx_club_action_claims_claimed_at
ON club_action_claims(claimed_at);

-- 事件记录保留 done/expired 审计历史；刷新活动快照时只淘汰 pending 事件。
CREATE TABLE IF NOT EXISTS club_schedule_events (
    student_id INTEGER NOT NULL,
    action_key TEXT NOT NULL,
    activity_id INTEGER NOT NULL,
    sign_type TEXT NOT NULL CHECK (sign_type IN ('1', '2')),
    event_at INTEGER NOT NULL,
    window_start INTEGER NOT NULL,
    window_end INTEGER NOT NULL,
    available_at INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'done', 'expired')),
    queued_at INTEGER,
    PRIMARY KEY (student_id, action_key)
);

CREATE INDEX IF NOT EXISTS idx_club_schedule_events_due
ON club_schedule_events(status, available_at, window_start, window_end, queued_at);
