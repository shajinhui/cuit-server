package academic

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

var ErrStoredSessionNotFound = errors.New("academic: stored session not found")

type UserRepository interface {
	UpsertLogin(ctx context.Context, studentNo string, encryptedPassword []byte, loggedAt time.Time) (int64, error)
	CreateSession(ctx context.Context, userID int64, tokenHash [sha256.Size]byte, expiresAt time.Time) error
	FindUserBySession(ctx context.Context, tokenHash [sha256.Size]byte, now time.Time) (StoredUser, error)
	DeleteSession(ctx context.Context, tokenHash [sha256.Size]byte) error
}

type MySQLRepository struct {
	db *sql.DB
}

func NewMySQLRepository(db *sql.DB) *MySQLRepository {
	return &MySQLRepository{db: db}
}

func (r *MySQLRepository) UpsertLogin(ctx context.Context, studentNo string, encryptedPassword []byte, loggedAt time.Time) (int64, error) {
	result, err := r.db.ExecContext(ctx, `
INSERT INTO users (student_no, jwxt_password_enc, last_login_at)
VALUES (?, ?, ?)
ON DUPLICATE KEY UPDATE
    id = LAST_INSERT_ID(id),
    jwxt_password_enc = VALUES(jwxt_password_enc),
    last_login_at = VALUES(last_login_at)`, studentNo, encryptedPassword, loggedAt)
	if err != nil {
		return 0, fmt.Errorf("academic: save user login: %w", err)
	}
	userID, err := result.LastInsertId()
	if err != nil {
		return 0, fmt.Errorf("academic: read saved user ID: %w", err)
	}
	return userID, nil
}

func (r *MySQLRepository) CreateSession(ctx context.Context, userID int64, tokenHash [sha256.Size]byte, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
INSERT INTO user_sessions (user_id, token_hash, expires_at)
VALUES (?, ?, ?)`, userID, tokenHash[:], expiresAt)
	if err != nil {
		return fmt.Errorf("academic: save user session: %w", err)
	}
	return nil
}

func (r *MySQLRepository) FindUserBySession(ctx context.Context, tokenHash [sha256.Size]byte, now time.Time) (StoredUser, error) {
	var user StoredUser
	err := r.db.QueryRowContext(ctx, `
SELECT u.id, u.student_no, u.jwxt_password_enc, s.expires_at
FROM user_sessions s
JOIN users u ON u.id = s.user_id
WHERE s.token_hash = ? AND s.expires_at > ?
LIMIT 1`, tokenHash[:], now).Scan(
		&user.ID,
		&user.StudentNo,
		&user.EncryptedPassword,
		&user.SessionExpiresAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return StoredUser{}, ErrStoredSessionNotFound
	}
	if err != nil {
		return StoredUser{}, fmt.Errorf("academic: find user session: %w", err)
	}
	return user, nil
}

func (r *MySQLRepository) DeleteSession(ctx context.Context, tokenHash [sha256.Size]byte) error {
	if _, err := r.db.ExecContext(ctx, `DELETE FROM user_sessions WHERE token_hash = ?`, tokenHash[:]); err != nil {
		return fmt.Errorf("academic: delete user session: %w", err)
	}
	return nil
}
