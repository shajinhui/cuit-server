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
	UpsertLogin(
		ctx context.Context,
		user LoginUser,
		encryptedPassword []byte,
		tokenHash [sha256.Size]byte,
		loggedAt time.Time,
	) (int64, error)
	FindUserBySession(ctx context.Context, tokenHash [sha256.Size]byte) (StoredUser, error)
	ClearSession(ctx context.Context, tokenHash [sha256.Size]byte) error
}

type SQLiteRepository struct {
	db *sql.DB
}

func NewSQLiteRepository(db *sql.DB) *SQLiteRepository {
	return &SQLiteRepository{db: db}
}

func (r *SQLiteRepository) UpsertLogin(
	ctx context.Context,
	user LoginUser,
	encryptedPassword []byte,
	tokenHash [sha256.Size]byte,
	loggedAt time.Time,
) (int64, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("academic: begin user login save: %w", err)
	}
	defer tx.Rollback()

	_, err = tx.ExecContext(ctx, `
INSERT INTO users (
    student_no, name, college, major, enrollment_year,
    jwxt_password_enc, session_token_hash, last_login_at, updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(student_no) DO UPDATE SET
    name = excluded.name,
    college = excluded.college,
    major = excluded.major,
    enrollment_year = excluded.enrollment_year,
    jwxt_password_enc = excluded.jwxt_password_enc,
    session_token_hash = excluded.session_token_hash,
    last_login_at = excluded.last_login_at,
    updated_at = excluded.updated_at`,
		user.StudentNo,
		user.Name,
		user.College,
		user.Major,
		user.EnrollmentYear,
		encryptedPassword,
		tokenHash[:],
		loggedAt,
		loggedAt,
	)
	if err != nil {
		return 0, fmt.Errorf("academic: save user login: %w", err)
	}

	var userID int64
	if err := tx.QueryRowContext(ctx, `SELECT id FROM users WHERE student_no = ?`, user.StudentNo).Scan(&userID); err != nil {
		return 0, fmt.Errorf("academic: read saved user ID: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("academic: commit user login save: %w", err)
	}
	return userID, nil
}

func (r *SQLiteRepository) FindUserBySession(ctx context.Context, tokenHash [sha256.Size]byte) (StoredUser, error) {
	var user StoredUser
	err := r.db.QueryRowContext(ctx, `
SELECT id, student_no, name, college, major, enrollment_year, jwxt_password_enc
FROM users
WHERE session_token_hash = ?
LIMIT 1`, tokenHash[:]).Scan(
		&user.ID,
		&user.StudentNo,
		&user.Name,
		&user.College,
		&user.Major,
		&user.EnrollmentYear,
		&user.EncryptedPassword,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return StoredUser{}, ErrStoredSessionNotFound
	}
	if err != nil {
		return StoredUser{}, fmt.Errorf("academic: find user session: %w", err)
	}
	return user, nil
}

func (r *SQLiteRepository) ClearSession(ctx context.Context, tokenHash [sha256.Size]byte) error {
	if _, err := r.db.ExecContext(
		ctx,
		`UPDATE users SET session_token_hash = NULL, updated_at = CURRENT_TIMESTAMP WHERE session_token_hash = ?`,
		tokenHash[:],
	); err != nil {
		return fmt.Errorf("academic: clear user session: %w", err)
	}
	return nil
}
