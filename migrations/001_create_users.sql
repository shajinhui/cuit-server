CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_no TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    college TEXT NOT NULL DEFAULT '',
    major TEXT NOT NULL DEFAULT '',
    class_name TEXT NOT NULL DEFAULT '',
    enrollment_year INTEGER NOT NULL DEFAULT 0,
    jwxt_password_enc BLOB NOT NULL,
    credential_key_version INTEGER NOT NULL DEFAULT 1,
    session_token_hash BLOB UNIQUE,
    last_login_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
