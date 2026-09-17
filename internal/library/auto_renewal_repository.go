package library

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

const (
	AutoRenewalScheduled = "scheduled"
	AutoRenewalRunning   = "running"
	AutoRenewalSucceeded = "succeeded"
	AutoRenewalFailed    = "failed"
	AutoRenewalCancelled = "cancelled"
	AutoRenewalSkipped   = "skipped"
)

var (
	ErrAutoRenewalInProgress   = errors.New("library: auto renewal in progress")
	ErrAutoRenewalAlreadyFinal = errors.New("library: auto renewal already finalized")
	ErrAutoRenewalSessionEnded = errors.New("library: auto renewal session ended")
)

type AutoRenewal struct {
	ID               int64             `json:"ID"`
	ReservationID    string            `json:"ReservationID"`
	ReservationUUID  string            `json:"ReservationUUID"`
	DurationMinutes  int               `json:"DurationMinutes"`
	ReservationEnd   string            `json:"ReservationEnd"`
	ExecuteAt        time.Time         `json:"ExecuteAt"`
	Status           string            `json:"Status"`
	AttemptCount     int               `json:"AttemptCount"`
	LastMessage      string            `json:"LastMessage"`
	CompletedAt      *time.Time        `json:"CompletedAt,omitempty"`
	SessionTokenHash [sha256.Size]byte `json:"-"`
	UserID           int64             `json:"-"`
}

type ScheduleAutoRenewalInput struct {
	UserID           int64
	SessionTokenHash [sha256.Size]byte
	ReservationID    string
	ReservationUUID  string
	DurationMinutes  int
	ReservationEnd   string
	ExecuteAt        time.Time
}

type AutoRenewalRepository struct {
	db *sql.DB
}

func NewAutoRenewalRepository(db *sql.DB) *AutoRenewalRepository {
	return &AutoRenewalRepository{db: db}
}

func (r *AutoRenewalRepository) Schedule(
	ctx context.Context,
	input ScheduleAutoRenewalInput,
	now time.Time,
) (AutoRenewal, error) {
	input.ReservationID = strings.TrimSpace(input.ReservationID)
	input.ReservationUUID = strings.TrimSpace(input.ReservationUUID)
	input.ReservationEnd = strings.TrimSpace(input.ReservationEnd)
	if input.UserID <= 0 || input.ReservationID == "" || input.DurationMinutes <= 0 ||
		input.ReservationEnd == "" || input.ExecuteAt.IsZero() {
		return AutoRenewal{}, errors.New("library: invalid auto renewal schedule")
	}
	if now.IsZero() {
		now = time.Now()
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return AutoRenewal{}, fmt.Errorf("library: begin auto renewal schedule: %w", err)
	}
	defer tx.Rollback()
	var sessionExists int
	err = tx.QueryRowContext(ctx, `
SELECT 1
FROM academic_sessions
WHERE token_hash = ? AND user_id = ?
LIMIT 1`, input.SessionTokenHash[:], input.UserID).Scan(&sessionExists)
	if errors.Is(err, sql.ErrNoRows) {
		return AutoRenewal{}, ErrAutoRenewalSessionEnded
	}
	if err != nil {
		return AutoRenewal{}, fmt.Errorf("library: verify auto renewal session: %w", err)
	}

	var currentStatus string
	err = tx.QueryRowContext(ctx, `
SELECT status
FROM library_auto_renewals
WHERE user_id = ? AND reservation_id = ?`, input.UserID, input.ReservationID).Scan(&currentStatus)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return AutoRenewal{}, fmt.Errorf("library: read existing auto renewal: %w", err)
	}
	switch currentStatus {
	case AutoRenewalRunning:
		return AutoRenewal{}, ErrAutoRenewalInProgress
	case AutoRenewalSucceeded, AutoRenewalFailed:
		return AutoRenewal{}, ErrAutoRenewalAlreadyFinal
	}

	nowMS := now.UnixMilli()
	_, err = tx.ExecContext(ctx, `
INSERT INTO library_auto_renewals (
    user_id, session_token_hash, reservation_id, reservation_uuid,
    duration_minutes, reservation_end, execute_at, status,
    attempt_count, claimed_at, completed_at, last_message, created_at, updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, 'scheduled', 0, NULL, NULL, '', ?, ?)
ON CONFLICT(user_id, reservation_id) DO UPDATE SET
    session_token_hash = excluded.session_token_hash,
    reservation_uuid = excluded.reservation_uuid,
    duration_minutes = excluded.duration_minutes,
    reservation_end = excluded.reservation_end,
    execute_at = excluded.execute_at,
    status = 'scheduled',
    attempt_count = 0,
    claimed_at = NULL,
    completed_at = NULL,
    last_message = '',
    updated_at = excluded.updated_at`,
		input.UserID,
		input.SessionTokenHash[:],
		input.ReservationID,
		input.ReservationUUID,
		input.DurationMinutes,
		input.ReservationEnd,
		input.ExecuteAt.UnixMilli(),
		nowMS,
		nowMS,
	)
	if err != nil {
		return AutoRenewal{}, fmt.Errorf("library: save auto renewal: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return AutoRenewal{}, fmt.Errorf("library: commit auto renewal schedule: %w", err)
	}
	result, err := r.GetByReservation(ctx, input.UserID, input.ReservationID)
	if err != nil {
		return AutoRenewal{}, err
	}
	if result == nil {
		return AutoRenewal{}, errors.New("library: saved auto renewal not found")
	}
	return *result, nil
}

func (r *AutoRenewalRepository) ListByUser(ctx context.Context, userID int64) ([]AutoRenewal, error) {
	rows, err := r.db.QueryContext(ctx, autoRenewalSelect+`
WHERE user_id = ?
ORDER BY updated_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("library: list auto renewals: %w", err)
	}
	defer rows.Close()
	result := make([]AutoRenewal, 0)
	for rows.Next() {
		item, err := scanAutoRenewal(rows)
		if err != nil {
			return nil, err
		}
		result = append(result, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("library: iterate auto renewals: %w", err)
	}
	return result, nil
}

func (r *AutoRenewalRepository) GetByReservation(
	ctx context.Context,
	userID int64,
	reservationID string,
) (*AutoRenewal, error) {
	row := r.db.QueryRowContext(ctx, autoRenewalSelect+`
WHERE user_id = ? AND reservation_id = ?
LIMIT 1`, userID, strings.TrimSpace(reservationID))
	item, err := scanAutoRenewal(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *AutoRenewalRepository) Cancel(
	ctx context.Context,
	userID int64,
	reservationID string,
	now time.Time,
) (*AutoRenewal, error) {
	if now.IsZero() {
		now = time.Now()
	}
	current, err := r.GetByReservation(ctx, userID, reservationID)
	if err != nil || current == nil {
		return current, err
	}
	if current.Status == AutoRenewalRunning {
		return nil, ErrAutoRenewalInProgress
	}
	if current.Status != AutoRenewalScheduled {
		return current, nil
	}
	_, err = r.db.ExecContext(ctx, `
UPDATE library_auto_renewals
SET status = 'cancelled', completed_at = ?, last_message = '自动续座已关闭', updated_at = ?
WHERE id = ? AND status = 'scheduled'`, now.UnixMilli(), now.UnixMilli(), current.ID)
	if err != nil {
		return nil, fmt.Errorf("library: cancel auto renewal: %w", err)
	}
	return r.GetByReservation(ctx, userID, reservationID)
}

func (r *AutoRenewalRepository) CancelByReservationUUID(
	ctx context.Context,
	userID int64,
	reservationUUID string,
	now time.Time,
) error {
	reservationUUID = strings.TrimSpace(reservationUUID)
	if userID <= 0 || reservationUUID == "" {
		return nil
	}
	if now.IsZero() {
		now = time.Now()
	}
	_, err := r.db.ExecContext(ctx, `
UPDATE library_auto_renewals
SET status = 'cancelled', completed_at = ?, last_message = '预约已结束，自动续座已关闭', updated_at = ?
WHERE user_id = ? AND reservation_uuid = ? AND status = 'scheduled'`,
		now.UnixMilli(), now.UnixMilli(), userID, reservationUUID)
	if err != nil {
		return fmt.Errorf("library: cancel auto renewal by reservation UUID: %w", err)
	}
	return nil
}

func (r *AutoRenewalRepository) FailStaleRunning(ctx context.Context, now time.Time, staleAfter time.Duration) error {
	if staleAfter <= 0 {
		staleAfter = 5 * time.Minute
	}
	_, err := r.db.ExecContext(ctx, `
UPDATE library_auto_renewals
SET status = 'failed',
    completed_at = ?,
    last_message = '上次执行状态未知，为避免重复续座未自动重试',
    updated_at = ?
WHERE status = 'running' AND claimed_at <= ?`,
		now.UnixMilli(), now.UnixMilli(), now.Add(-staleAfter).UnixMilli())
	if err != nil {
		return fmt.Errorf("library: fail stale auto renewals: %w", err)
	}
	return nil
}

func (r *AutoRenewalRepository) CancelInactiveSessions(ctx context.Context, now time.Time) error {
	_, err := r.db.ExecContext(ctx, `
UPDATE library_auto_renewals
SET status = 'cancelled',
    completed_at = ?,
    last_message = '登录已退出，自动续座已关闭',
    updated_at = ?
WHERE status = 'scheduled'
  AND NOT EXISTS (
      SELECT 1 FROM academic_sessions
      WHERE academic_sessions.token_hash = library_auto_renewals.session_token_hash
  )`, now.UnixMilli(), now.UnixMilli())
	if err != nil {
		return fmt.Errorf("library: cancel inactive auto renewals: %w", err)
	}
	return nil
}

func (r *AutoRenewalRepository) SessionActive(
	ctx context.Context,
	sessionTokenHash [sha256.Size]byte,
) (bool, error) {
	var exists int
	err := r.db.QueryRowContext(ctx, `
SELECT 1
FROM academic_sessions
WHERE token_hash = ?
LIMIT 1`, sessionTokenHash[:]).Scan(&exists)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("library: verify auto renewal session: %w", err)
	}
	return true, nil
}

func (r *AutoRenewalRepository) ClaimDue(
	ctx context.Context,
	now time.Time,
	limit int,
) ([]AutoRenewal, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("library: begin auto renewal claim: %w", err)
	}
	defer tx.Rollback()
	rows, err := tx.QueryContext(ctx, `
SELECT id
FROM library_auto_renewals
WHERE status = 'scheduled' AND execute_at <= ?
ORDER BY execute_at, id
LIMIT ?`, now.UnixMilli(), limit)
	if err != nil {
		return nil, fmt.Errorf("library: list due auto renewals: %w", err)
	}
	ids := make([]int64, 0, limit)
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return nil, fmt.Errorf("library: scan due auto renewal: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Close(); err != nil {
		return nil, fmt.Errorf("library: close due auto renewal rows: %w", err)
	}
	claimed := make([]AutoRenewal, 0, len(ids))
	for _, id := range ids {
		result, err := tx.ExecContext(ctx, `
UPDATE library_auto_renewals
SET status = 'running', claimed_at = ?, attempt_count = attempt_count + 1, updated_at = ?
WHERE id = ? AND status = 'scheduled'`, now.UnixMilli(), now.UnixMilli(), id)
		if err != nil {
			return nil, fmt.Errorf("library: claim auto renewal: %w", err)
		}
		changed, err := result.RowsAffected()
		if err != nil || changed != 1 {
			continue
		}
		row := tx.QueryRowContext(ctx, autoRenewalSelect+` WHERE id = ?`, id)
		item, err := scanAutoRenewal(row)
		if err != nil {
			return nil, err
		}
		claimed = append(claimed, item)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("library: commit auto renewal claim: %w", err)
	}
	return claimed, nil
}

func (r *AutoRenewalRepository) Complete(
	ctx context.Context,
	id int64,
	status string,
	message string,
	now time.Time,
) error {
	if status != AutoRenewalSucceeded && status != AutoRenewalFailed && status != AutoRenewalSkipped {
		return errors.New("library: invalid auto renewal completion status")
	}
	result, err := r.db.ExecContext(ctx, `
UPDATE library_auto_renewals
SET status = ?, completed_at = ?, last_message = ?, updated_at = ?
WHERE id = ? AND status = 'running'`, status, now.UnixMilli(), strings.TrimSpace(message), now.UnixMilli(), id)
	if err != nil {
		return fmt.Errorf("library: complete auto renewal: %w", err)
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("library: read auto renewal completion result: %w", err)
	}
	if changed != 1 {
		return errors.New("library: auto renewal is no longer running")
	}
	return nil
}

const autoRenewalSelect = `
SELECT id, user_id, session_token_hash, reservation_id, reservation_uuid,
       duration_minutes, reservation_end, execute_at, status, attempt_count,
       completed_at, last_message
FROM library_auto_renewals`

type autoRenewalScanner interface {
	Scan(...any) error
}

func scanAutoRenewal(scanner autoRenewalScanner) (AutoRenewal, error) {
	var item AutoRenewal
	var sessionHash []byte
	var executeAt int64
	var completedAt sql.NullInt64
	if err := scanner.Scan(
		&item.ID,
		&item.UserID,
		&sessionHash,
		&item.ReservationID,
		&item.ReservationUUID,
		&item.DurationMinutes,
		&item.ReservationEnd,
		&executeAt,
		&item.Status,
		&item.AttemptCount,
		&completedAt,
		&item.LastMessage,
	); err != nil {
		return AutoRenewal{}, err
	}
	if len(sessionHash) != sha256.Size {
		return AutoRenewal{}, errors.New("library: invalid stored session hash")
	}
	copy(item.SessionTokenHash[:], sessionHash)
	item.ExecuteAt = time.UnixMilli(executeAt).In(autoRenewalLocation())
	if completedAt.Valid {
		completed := time.UnixMilli(completedAt.Int64).In(autoRenewalLocation())
		item.CompletedAt = &completed
	}
	return item, nil
}

func autoRenewalLocation() *time.Location {
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		return time.FixedZone("Asia/Shanghai", 8*60*60)
	}
	return location
}
