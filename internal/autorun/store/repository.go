package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

const (
	defaultActionStaleAfter = 2 * time.Minute
	defaultQueueStaleAfter  = 5 * time.Minute
	maxReadLimit            = 100
)

var (
	// ErrInvalidArgument marks values that cannot identify a durable AutoRun
	// record.  Callers can use errors.Is to map it to a client-side error.
	ErrInvalidArgument = errors.New("autorun store: invalid argument")
	// ErrNotFound is available to callers that prefer an explicit sentinel;
	// read methods in this package return (nil, nil) for a missing row.
	ErrNotFound = errors.New("autorun store: record not found")
)

// Repository persists AutoRun session, schedule, event, and mutation-claim
// state in the application's SQLite database.  It has no Redis dependency;
// after a process restart all scheduling decisions can be recovered from the
// tables created by migrations/005_create_autorun.sql.
type Repository struct {
	db               *sql.DB
	encryptionSecret string
}

// NewRepository constructs a SQLite AutoRun repository.  The encryption key
// is validated on the first token encrypt/decrypt operation so construction
// stays compatible with the existing application bootstrap style.
func NewRepository(db *sql.DB, encryptionSecret string) *Repository {
	return &Repository{db: db, encryptionSecret: encryptionSecret}
}

// SaveSession encrypts and upserts the login state.  One student has exactly
// one persisted session; a fresh login replaces the previous session key and
// ciphertext.  requestedSessionKey is optional and overrides SessionKey when
// supplied, which lets the HTTP compatibility layer preserve an existing key.
func (r *Repository) SaveSession(ctx context.Context, phone string, session Session, requestedSessionKey ...string) (Session, error) {
	if err := r.validateDB(); err != nil {
		return Session{}, err
	}
	if session.StudentID <= 0 || session.UserID <= 0 || session.SchoolID <= 0 || session.Token == "" {
		return Session{}, fmt.Errorf("%w: incomplete session", ErrInvalidArgument)
	}

	sessionKey := strings.TrimSpace(session.SessionKey)
	if len(requestedSessionKey) > 0 && strings.TrimSpace(requestedSessionKey[0]) != "" {
		sessionKey = strings.TrimSpace(requestedSessionKey[0])
	}
	if sessionKey == "" {
		var err error
		sessionKey, err = GenerateSessionKey()
		if err != nil {
			return Session{}, err
		}
	}
	if len(sessionKey) < 20 || len(sessionKey) > 256 {
		return Session{}, fmt.Errorf("%w: invalid session key length", ErrInvalidArgument)
	}

	ciphertext, err := EncryptToken(session.Token, r.encryptionSecret)
	if err != nil {
		return Session{}, fmt.Errorf("autorun store: encrypt session token: %w", err)
	}
	now := time.Now().UTC()
	phoneHash := HashPhone(phone)
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Session{}, fmt.Errorf("autorun store: begin session save: %w", err)
	}
	defer tx.Rollback()
	_, err = tx.ExecContext(ctx, `
INSERT INTO sessions (
    session_key, student_id, user_id, school_id, phone_hash,
    token_ciphertext, updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(student_id) DO UPDATE SET
    session_key = excluded.session_key,
    user_id = excluded.user_id,
    school_id = excluded.school_id,
    phone_hash = excluded.phone_hash,
    token_ciphertext = excluded.token_ciphertext,
    updated_at = excluded.updated_at`,
		sessionKey,
		session.StudentID,
		session.UserID,
		session.SchoolID,
		phoneHash,
		ciphertext,
		now.UnixMilli(),
	)
	if err != nil {
		return Session{}, fmt.Errorf("autorun store: save session: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return Session{}, fmt.Errorf("autorun store: commit session save: %w", err)
	}

	return Session{
		Token:      session.Token,
		UserID:     session.UserID,
		StudentID:  session.StudentID,
		SchoolID:   session.SchoolID,
		SessionKey: sessionKey,
		PhoneHash:  phoneHash,
		UpdatedAt:  now,
	}, nil
}

// GetSessionByKey returns a session for an exact application session key.
func (r *Repository) GetSessionByKey(ctx context.Context, sessionKey string) (*Session, error) {
	sessionKey = strings.TrimSpace(sessionKey)
	if sessionKey == "" {
		return nil, nil
	}
	return r.getSession(ctx, "SELECT session_key, student_id, user_id, school_id, phone_hash, token_ciphertext, updated_at FROM sessions WHERE session_key = ? LIMIT 1", sessionKey)
}

// GetSessionByStudentID returns the one session currently associated with a
// student.  It is intentionally separate from HTTP lookup by session key and
// is used by the local scheduler only.
func (r *Repository) GetSessionByStudentID(ctx context.Context, studentID int64) (*Session, error) {
	if studentID <= 0 {
		return nil, nil
	}
	return r.getSession(ctx, "SELECT session_key, student_id, user_id, school_id, phone_hash, token_ciphertext, updated_at FROM sessions WHERE student_id = ? LIMIT 1", studentID)
}

// GetSessionBySessionKey is a descriptive alias for GetSessionByKey.
func (r *Repository) GetSessionBySessionKey(ctx context.Context, sessionKey string) (*Session, error) {
	return r.GetSessionByKey(ctx, sessionKey)
}

// Save stores the schedule switch and resets its activity refresh cursor.
// UpdatedAt is used as the operation time when non-zero, which is convenient
// for deterministic callers and tests; otherwise the current UTC time is used.
func (r *Repository) Save(ctx context.Context, schedule Schedule) (*Schedule, error) {
	now := schedule.UpdatedAt
	if now.IsZero() {
		now = time.Now().UTC()
	}
	return r.SaveSchedule(ctx, schedule.StudentID, schedule.SchoolID, schedule.SessionKey, schedule.Enabled, now)
}

// SaveSchedule enables or disables one student's club schedule.  Disabling a
// schedule removes only unfinished events; done and expired rows remain as
// audit history.
func (r *Repository) SaveSchedule(
	ctx context.Context,
	studentID, schoolID int64,
	sessionKey string,
	enabled bool,
	operationTime ...time.Time,
) (*Schedule, error) {
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	if studentID <= 0 {
		return nil, fmt.Errorf("%w: missing student ID", ErrInvalidArgument)
	}
	now := time.Now().UTC()
	if len(operationTime) > 0 && !operationTime[0].IsZero() {
		now = operationTime[0].UTC()
	}
	message := "定时已关闭"
	if enabled {
		message = "定时已开启：活动开始前 10 分钟试探签到，结束前 10 分钟试探签退"
	}

	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("autorun store: begin schedule save: %w", err)
	}
	defer tx.Rollback()
	_, err = tx.ExecContext(ctx, `
INSERT INTO club_schedules (
    student_id, school_id, session_key, enabled,
    last_sign_in_key, last_sign_back_key, last_probe_at, last_action_at,
    last_message, updated_at, refresh_date, refresh_after, refresh_queued_at
)
VALUES (?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, ?, '', 0, NULL)
ON CONFLICT(student_id) DO UPDATE SET
    school_id = excluded.school_id,
    session_key = excluded.session_key,
    enabled = excluded.enabled,
    last_message = excluded.last_message,
    refresh_date = '',
    refresh_after = 0,
    refresh_queued_at = NULL,
    updated_at = excluded.updated_at`,
		studentID,
		schoolID,
		strings.TrimSpace(sessionKey),
		boolInt(enabled),
		message,
		now.UnixMilli(),
	)
	if err != nil {
		return nil, fmt.Errorf("autorun store: save schedule: %w", err)
	}
	if !enabled {
		if _, err := tx.ExecContext(ctx, `
DELETE FROM club_schedule_events
WHERE student_id = ? AND status != 'done'`, studentID); err != nil {
			return nil, fmt.Errorf("autorun store: remove disabled schedule events: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("autorun store: commit schedule save: %w", err)
	}
	return r.GetSchedule(ctx, studentID)
}

// GetSchedule reads a student's persisted switch and runtime status.
func (r *Repository) GetSchedule(ctx context.Context, studentID int64) (*Schedule, error) {
	if studentID <= 0 {
		return nil, nil
	}
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	ctx = normalizeContext(ctx)
	row := r.db.QueryRowContext(ctx, `
SELECT student_id, school_id, session_key, enabled,
       last_sign_in_key, last_sign_back_key, last_probe_at, last_action_at,
       last_message, updated_at, refresh_date, refresh_after, refresh_queued_at
FROM club_schedules
WHERE student_id = ?
LIMIT 1`, studentID)
	schedule, found, err := scanSchedule(row)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("autorun store: get schedule: %w", err)
	}
	if !found {
		return nil, nil
	}
	return &schedule, nil
}

// ListEnabledSchedules returns all schedules eligible for local execution.
func (r *Repository) ListEnabledSchedules(ctx context.Context) ([]Schedule, error) {
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	ctx = normalizeContext(ctx)
	rows, err := r.db.QueryContext(ctx, `
SELECT student_id, school_id, session_key, enabled,
       last_sign_in_key, last_sign_back_key, last_probe_at, last_action_at,
       last_message, updated_at, refresh_date, refresh_after, refresh_queued_at
FROM club_schedules
WHERE enabled = 1
ORDER BY student_id`)
	if err != nil {
		return nil, fmt.Errorf("autorun store: list enabled schedules: %w", err)
	}
	defer rows.Close()
	result := make([]Schedule, 0)
	for rows.Next() {
		schedule, _, err := scanSchedule(rows)
		if err != nil {
			return nil, fmt.Errorf("autorun store: scan enabled schedule: %w", err)
		}
		result = append(result, schedule)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("autorun store: iterate enabled schedules: %w", err)
	}
	return result, nil
}

// ListSchedulesNeedingRefresh finds enabled schedules whose activity snapshot
// is stale for queryDate.  refreshQueuedAt reservations older than staleAfter
// are considered abandoned and become eligible again.
func (r *Repository) ListSchedulesNeedingRefresh(
	ctx context.Context,
	queryDate string,
	now time.Time,
	limit int,
	staleAfter ...time.Duration,
) ([]Schedule, error) {
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	stale := durationOrDefault(staleAfter, defaultQueueStaleAfter)
	nowMS := nowOrCurrent(now).UnixMilli()
	ctx = normalizeContext(ctx)
	rows, err := r.db.QueryContext(ctx, `
SELECT student_id, school_id, session_key, enabled,
       last_sign_in_key, last_sign_back_key, last_probe_at, last_action_at,
       last_message, updated_at, refresh_date, refresh_after, refresh_queued_at
FROM club_schedules
WHERE enabled = 1
  AND (refresh_date != ? OR refresh_after <= ?)
  AND (refresh_queued_at IS NULL OR refresh_queued_at <= ?)
ORDER BY refresh_after, student_id
LIMIT ?`, strings.TrimSpace(queryDate), nowMS, nowMS-stale.Milliseconds(), boundedLimit(limit))
	if err != nil {
		return nil, fmt.Errorf("autorun store: list schedules needing refresh: %w", err)
	}
	defer rows.Close()
	result := make([]Schedule, 0)
	for rows.Next() {
		schedule, _, err := scanSchedule(rows)
		if err != nil {
			return nil, fmt.Errorf("autorun store: scan refresh schedule: %w", err)
		}
		result = append(result, schedule)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("autorun store: iterate refresh schedules: %w", err)
	}
	return result, nil
}

// ClaimScheduleRefreshes atomically reserves refresh work for the supplied
// student IDs.  Returning only rows whose UPDATE changed avoids the
// publish-before-mark race between overlapping scheduler ticks.
func (r *Repository) ClaimScheduleRefreshes(
	ctx context.Context,
	studentIDs []int64,
	queryDate string,
	now time.Time,
	staleAfter ...time.Duration,
) ([]int64, error) {
	if len(studentIDs) == 0 {
		return []int64{}, nil
	}
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	stale := durationOrDefault(staleAfter, defaultQueueStaleAfter)
	now = nowOrCurrent(now)
	nowMS := now.UnixMilli()
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("autorun store: begin refresh claim: %w", err)
	}
	defer tx.Rollback()
	claimed := make([]int64, 0, len(studentIDs))
	seen := make(map[int64]struct{}, len(studentIDs))
	for _, studentID := range studentIDs {
		if studentID <= 0 {
			continue
		}
		if _, ok := seen[studentID]; ok {
			continue
		}
		seen[studentID] = struct{}{}
		result, err := tx.ExecContext(ctx, `
UPDATE club_schedules
SET refresh_queued_at = ?
WHERE student_id = ? AND enabled = 1
  AND (refresh_date != ? OR refresh_after <= ?)
  AND (refresh_queued_at IS NULL OR refresh_queued_at <= ?)`,
			nowMS,
			studentID,
			strings.TrimSpace(queryDate),
			nowMS,
			nowMS-stale.Milliseconds(),
		)
		if err != nil {
			return nil, fmt.Errorf("autorun store: claim schedule refresh: %w", err)
		}
		changes, err := result.RowsAffected()
		if err != nil {
			return nil, fmt.Errorf("autorun store: count schedule refresh claim: %w", err)
		}
		if changes > 0 {
			claimed = append(claimed, studentID)
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("autorun store: commit refresh claim: %w", err)
	}
	return claimed, nil
}

// ReleaseScheduleRefreshes releases reservations made at queuedAt after a
// failed publish.  A later tick can safely claim them again.
func (r *Repository) ReleaseScheduleRefreshes(ctx context.Context, studentIDs []int64, queuedAt time.Time) error {
	if len(studentIDs) == 0 {
		return nil
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("autorun store: begin refresh release: %w", err)
	}
	defer tx.Rollback()
	for _, studentID := range studentIDs {
		if _, err := tx.ExecContext(ctx, `
UPDATE club_schedules SET refresh_queued_at = NULL
WHERE student_id = ? AND refresh_queued_at = ?`, studentID, queuedAt.UnixMilli()); err != nil {
			return fmt.Errorf("autorun store: release schedule refresh: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("autorun store: commit refresh release: %w", err)
	}
	return nil
}

// UpdateScheduleRuntime updates only the supplied runtime fields.
func (r *Repository) UpdateScheduleRuntime(ctx context.Context, studentID int64, update ScheduleRuntimeUpdate) error {
	if studentID <= 0 {
		return fmt.Errorf("%w: missing student ID", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	assignments := make([]string, 0, 6)
	values := make([]any, 0, 7)
	if !update.LastProbeAt.IsZero() {
		assignments = append(assignments, "last_probe_at = ?")
		values = append(values, update.LastProbeAt.UnixMilli())
	}
	if !update.LastActionAt.IsZero() {
		assignments = append(assignments, "last_action_at = ?")
		values = append(values, update.LastActionAt.UnixMilli())
	}
	if update.LastMessage != nil {
		assignments = append(assignments, "last_message = ?")
		values = append(values, truncateString(*update.LastMessage, 500))
	}
	if update.LastSignInKey != nil {
		assignments = append(assignments, "last_sign_in_key = ?")
		values = append(values, *update.LastSignInKey)
	}
	if update.LastSignBackKey != nil {
		assignments = append(assignments, "last_sign_back_key = ?")
		values = append(values, *update.LastSignBackKey)
	}
	if len(assignments) == 0 {
		return nil
	}
	now := time.Now().UTC().UnixMilli()
	assignments = append(assignments, "updated_at = ?")
	values = append(values, now, studentID)
	ctx = normalizeContext(ctx)
	_, err := r.db.ExecContext(ctx, fmt.Sprintf(
		"UPDATE club_schedules SET %s WHERE student_id = ?", strings.Join(assignments, ", "),
	), values...)
	if err != nil {
		return fmt.Errorf("autorun store: update schedule runtime: %w", err)
	}
	return nil
}

// UpdateRuntime is a short alias for UpdateScheduleRuntime.
func (r *Repository) UpdateRuntime(ctx context.Context, studentID int64, update ScheduleRuntimeUpdate) error {
	return r.UpdateScheduleRuntime(ctx, studentID, update)
}

// ReplaceEvents refreshes one student's activity-boundary snapshot in one
// short transaction.  Pending rows missing from the new snapshot become
// expired, while done rows are retained and never reactivated by a refresh.
func (r *Repository) ReplaceEvents(
	ctx context.Context,
	studentID int64,
	queryDate string,
	events []Event,
	now time.Time,
	refreshAfter time.Time,
) error {
	if studentID <= 0 {
		return fmt.Errorf("%w: missing student ID", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	now = nowOrCurrent(now)
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("autorun store: begin event replacement: %w", err)
	}
	defer tx.Rollback()
	// Preserve audit history.  Upserts below reactivate matching pending or
	// previously expired events, but an already completed row stays done.
	if _, err := tx.ExecContext(ctx, `
UPDATE club_schedule_events
SET status = 'expired', queued_at = NULL
WHERE student_id = ? AND status = 'pending'`, studentID); err != nil {
		return fmt.Errorf("autorun store: expire missing schedule events: %w", err)
	}

	for _, event := range events {
		normalized, err := normalizeEvent(studentID, event)
		if err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, `
INSERT INTO club_schedule_events (
    student_id, action_key, activity_id, sign_type, event_at,
    window_start, window_end, available_at, status, queued_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', NULL)
ON CONFLICT(student_id, action_key) DO UPDATE SET
    activity_id = excluded.activity_id,
    sign_type = excluded.sign_type,
    event_at = excluded.event_at,
    window_start = excluded.window_start,
    window_end = excluded.window_end,
    available_at = CASE WHEN club_schedule_events.status = 'done'
        THEN club_schedule_events.available_at ELSE excluded.available_at END,
    status = CASE WHEN club_schedule_events.status = 'done'
        THEN 'done' ELSE 'pending' END,
    queued_at = CASE WHEN club_schedule_events.status = 'done'
        THEN club_schedule_events.queued_at ELSE NULL END`,
			normalized.StudentID,
			normalized.ActionKey,
			normalized.ActivityID,
			normalized.SignType,
			millis(normalized.EventAt),
			millis(normalized.WindowStart),
			millis(normalized.WindowEnd),
			millis(eventAvailableAt(normalized)),
		)
		if err != nil {
			return fmt.Errorf("autorun store: upsert schedule event: %w", err)
		}
	}
	if _, err := tx.ExecContext(ctx, `
UPDATE club_schedules
SET refresh_date = ?, refresh_after = ?, refresh_queued_at = NULL,
    last_message = ?, updated_at = ?
WHERE student_id = ? AND enabled = 1`,
		strings.TrimSpace(queryDate),
		millis(refreshAfter),
		truncateString(fmt.Sprintf("活动时间已同步：%d 个签到/签退节点", len(events)), 500),
		now.UnixMilli(),
		studentID,
	); err != nil {
		return fmt.Errorf("autorun store: update event refresh cursor: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("autorun store: commit event replacement: %w", err)
	}
	return nil
}

// ReplaceScheduleEvents is a descriptive alias for ReplaceEvents.
func (r *Repository) ReplaceScheduleEvents(
	ctx context.Context,
	studentID int64,
	queryDate string,
	events []Event,
	now time.Time,
	refreshAfter time.Time,
) error {
	return r.ReplaceEvents(ctx, studentID, queryDate, events, now, refreshAfter)
}

// DeferScheduleRefresh moves the activity snapshot cursor forward after a
// failed refresh and clears the reservation held by the failed worker.
func (r *Repository) DeferScheduleRefresh(
	ctx context.Context,
	studentID int64,
	queryDate string,
	refreshAfter time.Time,
	message string,
	now time.Time,
) error {
	if studentID <= 0 {
		return fmt.Errorf("%w: missing student ID", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	now = nowOrCurrent(now)
	ctx = normalizeContext(ctx)
	_, err := r.db.ExecContext(ctx, `
UPDATE club_schedules
SET refresh_date = ?, refresh_after = ?, refresh_queued_at = NULL,
    last_message = ?, updated_at = ?
WHERE student_id = ?`,
		strings.TrimSpace(queryDate),
		millis(refreshAfter),
		truncateString(message, 500),
		now.UnixMilli(),
		studentID,
	)
	if err != nil {
		return fmt.Errorf("autorun store: defer schedule refresh: %w", err)
	}
	return nil
}

// ListDueEvents returns pending events in their execution windows.  Queued
// reservations older than staleAfter are considered abandoned.
func (r *Repository) ListDueEvents(
	ctx context.Context,
	now time.Time,
	limit int,
	windowGrace time.Duration,
	staleAfter ...time.Duration,
) ([]Event, error) {
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	stale := durationOrDefault(staleAfter, defaultQueueStaleAfter)
	nowMS := nowOrCurrent(now).UnixMilli()
	ctx = normalizeContext(ctx)
	return r.queryDueEvents(ctx, r.db, nowMS, limit, windowGrace, stale)
}

// ClaimDueEvents selects and reserves due events atomically.  The reservation
// is written before the caller publishes work or touches the upstream API.
func (r *Repository) ClaimDueEvents(
	ctx context.Context,
	now time.Time,
	limit int,
	windowGrace time.Duration,
	staleAfter ...time.Duration,
) ([]Event, error) {
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	stale := durationOrDefault(staleAfter, defaultQueueStaleAfter)
	now = nowOrCurrent(now)
	nowMS := now.UnixMilli()
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("autorun store: begin due event claim: %w", err)
	}
	defer tx.Rollback()
	candidates, err := r.queryDueEvents(ctx, tx, nowMS, limit, windowGrace, stale)
	if err != nil {
		return nil, err
	}
	claimed := make([]Event, 0, len(candidates))
	cutoff := nowMS - nonNegativeDuration(windowGrace).Milliseconds()
	staleCutoff := nowMS - stale.Milliseconds()
	for _, event := range candidates {
		result, err := tx.ExecContext(ctx, `
UPDATE club_schedule_events AS event
SET queued_at = ?
WHERE event.student_id = ? AND event.action_key = ?
  AND event.status = 'pending'
  AND event.window_start <= ?
  AND event.window_end >= ?
  AND event.available_at <= ?
  AND (event.queued_at IS NULL OR event.queued_at <= ?)`,
			nowMS,
			event.StudentID,
			event.ActionKey,
			nowMS,
			cutoff,
			nowMS,
			staleCutoff,
		)
		if err != nil {
			return nil, fmt.Errorf("autorun store: claim due event: %w", err)
		}
		changes, err := result.RowsAffected()
		if err != nil {
			return nil, fmt.Errorf("autorun store: count due event claim: %w", err)
		}
		if changes > 0 {
			queuedAt := now.UTC()
			event.QueuedAt = &queuedAt
			claimed = append(claimed, event)
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("autorun store: commit due event claim: %w", err)
	}
	return claimed, nil
}

// ClaimEvents atomically claims a caller-provided due-event list.  It is
// useful when a scheduler first reads events for diagnostics and then claims
// the exact snapshot it intends to publish.
func (r *Repository) ClaimEvents(
	ctx context.Context,
	events []Event,
	now time.Time,
	windowGrace time.Duration,
	staleAfter ...time.Duration,
) ([]Event, error) {
	if len(events) == 0 {
		return []Event{}, nil
	}
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	stale := durationOrDefault(staleAfter, defaultQueueStaleAfter)
	now = nowOrCurrent(now)
	nowMS := now.UnixMilli()
	cutoff := nowMS - nonNegativeDuration(windowGrace).Milliseconds()
	staleCutoff := nowMS - stale.Milliseconds()
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("autorun store: begin event list claim: %w", err)
	}
	defer tx.Rollback()
	claimed := make([]Event, 0, len(events))
	for _, event := range events {
		if event.StudentID <= 0 || strings.TrimSpace(event.ActionKey) == "" {
			continue
		}
		result, err := tx.ExecContext(ctx, `
UPDATE club_schedule_events
SET queued_at = ?
WHERE student_id = ? AND action_key = ? AND status = 'pending'
  AND window_start <= ? AND window_end >= ? AND available_at <= ?
  AND (queued_at IS NULL OR queued_at <= ?)`,
			nowMS,
			event.StudentID,
			strings.TrimSpace(event.ActionKey),
			nowMS,
			cutoff,
			nowMS,
			staleCutoff,
		)
		if err != nil {
			return nil, fmt.Errorf("autorun store: claim event list item: %w", err)
		}
		changes, err := result.RowsAffected()
		if err != nil {
			return nil, fmt.Errorf("autorun store: count event list claim: %w", err)
		}
		if changes > 0 {
			queuedAt := now.UTC()
			event.QueuedAt = &queuedAt
			claimed = append(claimed, event)
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("autorun store: commit event list claim: %w", err)
	}
	return claimed, nil
}

// ReleaseEventClaims clears reservations made at queuedAt after a failed
// queue publish.  It never changes a done or expired event.
func (r *Repository) ReleaseEventClaims(ctx context.Context, events []Event, queuedAt time.Time) error {
	if len(events) == 0 {
		return nil
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("autorun store: begin event claim release: %w", err)
	}
	defer tx.Rollback()
	for _, event := range events {
		if _, err := tx.ExecContext(ctx, `
UPDATE club_schedule_events
SET queued_at = NULL
WHERE student_id = ? AND action_key = ? AND status = 'pending' AND queued_at = ?`,
			event.StudentID,
			strings.TrimSpace(event.ActionKey),
			queuedAt.UnixMilli(),
		); err != nil {
			return fmt.Errorf("autorun store: release event claim: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("autorun store: commit event claim release: %w", err)
	}
	return nil
}

// GetEvent returns one event by its durable idempotency key.
func (r *Repository) GetEvent(ctx context.Context, studentID int64, actionKey string) (*Event, error) {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return nil, nil
	}
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	ctx = normalizeContext(ctx)
	row := r.db.QueryRowContext(ctx, `
SELECT student_id, action_key, activity_id, sign_type, event_at,
       window_start, window_end, available_at, status, queued_at
FROM club_schedule_events
WHERE student_id = ? AND action_key = ?
LIMIT 1`, studentID, strings.TrimSpace(actionKey))
	event, found, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("autorun store: get schedule event: %w", err)
	}
	if !found {
		return nil, nil
	}
	return &event, nil
}

// DeferEvent advances a pending event's next probe time and releases its
// queue reservation.  Done/expired events are intentionally untouched.
func (r *Repository) DeferEvent(ctx context.Context, studentID int64, actionKey string, availableAt time.Time) error {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return fmt.Errorf("%w: missing event identity", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	ctx = normalizeContext(ctx)
	_, err := r.db.ExecContext(ctx, `
UPDATE club_schedule_events
SET available_at = ?, queued_at = NULL
WHERE student_id = ? AND action_key = ? AND status = 'pending'`,
		millis(availableAt),
		studentID,
		strings.TrimSpace(actionKey),
	)
	if err != nil {
		return fmt.Errorf("autorun store: defer schedule event: %w", err)
	}
	return nil
}

// DeferScheduleEvent is a descriptive alias for DeferEvent.
func (r *Repository) DeferScheduleEvent(ctx context.Context, studentID int64, actionKey string, availableAt time.Time) error {
	return r.DeferEvent(ctx, studentID, actionKey, availableAt)
}

// ExpireOverdue marks all pending events whose window ended before the
// supplied instant as expired and clears stale queue reservations.
func (r *Repository) ExpireOverdue(ctx context.Context, expiredBefore time.Time) (int64, error) {
	if err := r.validateDB(); err != nil {
		return 0, err
	}
	ctx = normalizeContext(ctx)
	result, err := r.db.ExecContext(ctx, `
UPDATE club_schedule_events
SET status = 'expired', queued_at = NULL
WHERE status = 'pending' AND window_end < ?`, millis(expiredBefore))
	if err != nil {
		return 0, fmt.Errorf("autorun store: expire overdue events: %w", err)
	}
	changes, err := result.RowsAffected()
	if err != nil {
		return 0, fmt.Errorf("autorun store: count expired events: %w", err)
	}
	return changes, nil
}

// ExpireOverdueEvents is a descriptive alias for ExpireOverdue.
func (r *Repository) ExpireOverdueEvents(ctx context.Context, expiredBefore time.Time) (int64, error) {
	return r.ExpireOverdue(ctx, expiredBefore)
}

// ExpireEvent expires one pending event while retaining the row for audit.
func (r *Repository) ExpireEvent(ctx context.Context, studentID int64, actionKey string) error {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return fmt.Errorf("%w: missing event identity", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	ctx = normalizeContext(ctx)
	_, err := r.db.ExecContext(ctx, `
UPDATE club_schedule_events
SET status = 'expired', queued_at = NULL
WHERE student_id = ? AND action_key = ? AND status = 'pending'`,
		studentID,
		strings.TrimSpace(actionKey),
	)
	if err != nil {
		return fmt.Errorf("autorun store: expire schedule event: %w", err)
	}
	return nil
}

// MarkEventDone marks an event completed without changing the mutation claim
// or schedule runtime fields.  CompleteScheduledAction performs all three
// updates atomically for scheduler workers.
func (r *Repository) MarkEventDone(ctx context.Context, studentID int64, actionKey string) error {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return fmt.Errorf("%w: missing event identity", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	ctx = normalizeContext(ctx)
	_, err := r.db.ExecContext(ctx, `
UPDATE club_schedule_events
SET status = 'done', queued_at = NULL
WHERE student_id = ? AND action_key = ?`, studentID, strings.TrimSpace(actionKey))
	if err != nil {
		return fmt.Errorf("autorun store: complete schedule event: %w", err)
	}
	return nil
}

// TryClaimAction atomically reserves a mutation key before an upstream
// sign-in/sign-back request.  A done claim is never retried; an in-flight
// claim may be reclaimed only after staleAfter, while failed claims are
// immediately eligible because FailAction writes claimed_at = 0.
func (r *Repository) TryClaimAction(
	ctx context.Context,
	studentID int64,
	actionKey string,
	now time.Time,
	staleAfter ...time.Duration,
) (bool, error) {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return false, fmt.Errorf("%w: missing action identity", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return false, err
	}
	stale := durationOrDefault(staleAfter, defaultActionStaleAfter)
	now = nowOrCurrent(now)
	nowMS := now.UnixMilli()
	key := strings.TrimSpace(actionKey)
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return false, fmt.Errorf("autorun store: begin action claim: %w", err)
	}
	defer tx.Rollback()
	inserted, err := tx.ExecContext(ctx, `
INSERT OR IGNORE INTO club_action_claims (student_id, action_key, status, claimed_at)
VALUES (?, ?, 'in_flight', ?)`, studentID, key, nowMS)
	if err != nil {
		return false, fmt.Errorf("autorun store: insert action claim: %w", err)
	}
	changes, err := inserted.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("autorun store: count inserted action claim: %w", err)
	}
	if changes == 0 {
		var status ActionClaimStatus
		var claimedAt int64
		if err := tx.QueryRowContext(ctx, `
SELECT status, claimed_at
FROM club_action_claims
WHERE student_id = ? AND action_key = ?
LIMIT 1`, studentID, key).Scan(&status, &claimedAt); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return false, fmt.Errorf("autorun store: action claim disappeared: %w", ErrNotFound)
			}
			return false, fmt.Errorf("autorun store: read action claim: %w", err)
		}
		if status == ActionDone {
			if err := tx.Commit(); err != nil {
				return false, fmt.Errorf("autorun store: commit completed action claim: %w", err)
			}
			return false, nil
		}
		if status == ActionInFlight && nowMS-claimedAt < stale.Milliseconds() {
			if err := tx.Commit(); err != nil {
				return false, fmt.Errorf("autorun store: commit active action claim: %w", err)
			}
			return false, nil
		}
		refreshed, err := tx.ExecContext(ctx, `
UPDATE club_action_claims
SET status = 'in_flight', claimed_at = ?
WHERE student_id = ? AND action_key = ?
  AND status != 'done' AND claimed_at <= ?`,
			nowMS, studentID, key, nowMS-stale.Milliseconds())
		if err != nil {
			return false, fmt.Errorf("autorun store: reclaim action claim: %w", err)
		}
		changes, err = refreshed.RowsAffected()
		if err != nil {
			return false, fmt.Errorf("autorun store: count reclaimed action claim: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return false, fmt.Errorf("autorun store: commit action claim: %w", err)
	}
	return changes > 0, nil
}

// IsActionComplete reports whether the mutation key has a durable done claim.
func (r *Repository) IsActionComplete(ctx context.Context, studentID int64, actionKey string) (bool, error) {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return false, nil
	}
	if err := r.validateDB(); err != nil {
		return false, err
	}
	ctx = normalizeContext(ctx)
	var status ActionClaimStatus
	err := r.db.QueryRowContext(ctx, `
SELECT status FROM club_action_claims
WHERE student_id = ? AND action_key = ?
LIMIT 1`, studentID, strings.TrimSpace(actionKey)).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("autorun store: read action completion: %w", err)
	}
	return status == ActionDone, nil
}

// CompleteAction marks a mutation claim done.  The operation is idempotent;
// completing a missing claim is a no-op so recovery code can safely call it.
func (r *Repository) CompleteAction(ctx context.Context, studentID int64, actionKey string, completedAt ...time.Time) error {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return fmt.Errorf("%w: missing action identity", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	now := time.Now().UTC()
	if len(completedAt) > 0 && !completedAt[0].IsZero() {
		now = completedAt[0].UTC()
	}
	ctx = normalizeContext(ctx)
	_, err := r.db.ExecContext(ctx, `
UPDATE club_action_claims
SET status = 'done', claimed_at = ?
WHERE student_id = ? AND action_key = ?`,
		now.UnixMilli(), studentID, strings.TrimSpace(actionKey))
	if err != nil {
		return fmt.Errorf("autorun store: complete action claim: %w", err)
	}
	return nil
}

// FailAction releases a mutation claim for a retry while retaining its row.
func (r *Repository) FailAction(ctx context.Context, studentID int64, actionKey string) error {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return fmt.Errorf("%w: missing action identity", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	ctx = normalizeContext(ctx)
	_, err := r.db.ExecContext(ctx, `
UPDATE club_action_claims
SET status = 'failed', claimed_at = 0
WHERE student_id = ? AND action_key = ?`, studentID, strings.TrimSpace(actionKey))
	if err != nil {
		return fmt.Errorf("autorun store: fail action claim: %w", err)
	}
	return nil
}

// GetActionClaim reads a mutation claim for diagnostics and recovery.
func (r *Repository) GetActionClaim(ctx context.Context, studentID int64, actionKey string) (*ActionClaim, error) {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return nil, nil
	}
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	ctx = normalizeContext(ctx)
	var status ActionClaimStatus
	var claimedAt int64
	err := r.db.QueryRowContext(ctx, `
SELECT status, claimed_at
FROM club_action_claims
WHERE student_id = ? AND action_key = ?
LIMIT 1`, studentID, strings.TrimSpace(actionKey)).Scan(&status, &claimedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("autorun store: get action claim: %w", err)
	}
	return &ActionClaim{
		StudentID: studentID,
		ActionKey: strings.TrimSpace(actionKey),
		Status:    status,
		ClaimedAt: fromMillis(claimedAt),
	}, nil
}

// CompleteScheduledAction atomically marks the claim and event done and
// updates the schedule runtime.  This is the commit point after the upstream
// mutation has returned success.
func (r *Repository) CompleteScheduledAction(
	ctx context.Context,
	studentID int64,
	actionKey string,
	signType SignType,
	now time.Time,
	message string,
) error {
	if studentID <= 0 || strings.TrimSpace(actionKey) == "" {
		return fmt.Errorf("%w: missing action identity", ErrInvalidArgument)
	}
	if signType != SignInType && signType != SignBackType {
		return fmt.Errorf("%w: invalid sign type", ErrInvalidArgument)
	}
	if err := r.validateDB(); err != nil {
		return err
	}
	now = nowOrCurrent(now)
	keyColumn := "last_sign_in_key"
	if signType == SignBackType {
		keyColumn = "last_sign_back_key"
	}
	ctx = normalizeContext(ctx)
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("autorun store: begin scheduled action completion: %w", err)
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `
UPDATE club_action_claims
SET status = 'done', claimed_at = ?
WHERE student_id = ? AND action_key = ?`, now.UnixMilli(), studentID, strings.TrimSpace(actionKey)); err != nil {
		return fmt.Errorf("autorun store: complete scheduled action claim: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
UPDATE club_schedule_events
SET status = 'done', queued_at = NULL
WHERE student_id = ? AND action_key = ?`, studentID, strings.TrimSpace(actionKey)); err != nil {
		return fmt.Errorf("autorun store: complete scheduled event: %w", err)
	}
	if _, err := tx.ExecContext(ctx, fmt.Sprintf(`
UPDATE club_schedules
SET last_probe_at = ?, last_action_at = ?, %s = ?,
    last_message = ?, updated_at = ?
WHERE student_id = ?`, keyColumn),
		now.UnixMilli(),
		now.UnixMilli(),
		strings.TrimSpace(actionKey),
		truncateString(message, 500),
		now.UnixMilli(),
		studentID,
	); err != nil {
		return fmt.Errorf("autorun store: update completed schedule: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("autorun store: commit scheduled action completion: %w", err)
	}
	return nil
}

// Debug reports counts without exposing session keys, phone hashes, or token
// ciphertext.  It is safe to include in a protected administrator endpoint.
func (r *Repository) Debug(ctx context.Context) (DebugInfo, error) {
	if err := r.validateDB(); err != nil {
		return DebugInfo{}, err
	}
	ctx = normalizeContext(ctx)
	var sessions, schedules int64
	if err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM sessions").Scan(&sessions); err != nil {
		return DebugInfo{}, fmt.Errorf("autorun store: count sessions: %w", err)
	}
	if err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM club_schedules").Scan(&schedules); err != nil {
		return DebugInfo{}, fmt.Errorf("autorun store: count schedules: %w", err)
	}
	return DebugInfo{Enabled: true, Database: "SQLite", SessionCount: sessions, ScheduleCount: schedules}, nil
}

func (r *Repository) getSession(ctx context.Context, query string, arg any) (*Session, error) {
	if err := r.validateDB(); err != nil {
		return nil, err
	}
	ctx = normalizeContext(ctx)
	row := r.db.QueryRowContext(ctx, query, arg)
	var session Session
	var ciphertext string
	var updatedAt int64
	if err := row.Scan(
		&session.SessionKey,
		&session.StudentID,
		&session.UserID,
		&session.SchoolID,
		&session.PhoneHash,
		&ciphertext,
		&updatedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("autorun store: get session: %w", err)
	}
	token, err := DecryptToken(ciphertext, r.encryptionSecret)
	if err != nil {
		return nil, fmt.Errorf("autorun store: decrypt session token: %w", err)
	}
	session.Token = token
	session.UpdatedAt = fromMillis(updatedAt)
	return &session, nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanSchedule(row rowScanner) (Schedule, bool, error) {
	var schedule Schedule
	var enabled int
	var lastSignInKey, lastSignBackKey, lastMessage sql.NullString
	var lastProbeAt, lastActionAt, refreshQueuedAt sql.NullInt64
	var updatedAt, refreshAfter int64
	var refreshDate string
	if err := row.Scan(
		&schedule.StudentID,
		&schedule.SchoolID,
		&schedule.SessionKey,
		&enabled,
		&lastSignInKey,
		&lastSignBackKey,
		&lastProbeAt,
		&lastActionAt,
		&lastMessage,
		&updatedAt,
		&refreshDate,
		&refreshAfter,
		&refreshQueuedAt,
	); err != nil {
		return Schedule{}, false, err
	}
	schedule.Enabled = enabled == 1
	if lastSignInKey.Valid {
		schedule.LastSignInKey = lastSignInKey.String
	}
	if lastSignBackKey.Valid {
		schedule.LastSignBackKey = lastSignBackKey.String
	}
	if lastMessage.Valid {
		schedule.LastMessage = lastMessage.String
	}
	schedule.LastProbeAt = optionalTime(lastProbeAt)
	schedule.LastActionAt = optionalTime(lastActionAt)
	schedule.UpdatedAt = fromMillis(updatedAt)
	schedule.RefreshDate = refreshDate
	schedule.RefreshAfter = fromMillis(refreshAfter)
	schedule.RefreshQueuedAt = optionalTime(refreshQueuedAt)
	return schedule, true, nil
}

func scanEvent(row rowScanner) (Event, bool, error) {
	var event Event
	var status string
	var signType string
	var eventAt, windowStart, windowEnd, availableAt int64
	var queuedAt sql.NullInt64
	if err := row.Scan(
		&event.StudentID,
		&event.ActionKey,
		&event.ActivityID,
		&signType,
		&eventAt,
		&windowStart,
		&windowEnd,
		&availableAt,
		&status,
		&queuedAt,
	); err != nil {
		return Event{}, false, err
	}
	event.SignType = SignType(signType)
	event.EventAt = fromMillis(eventAt)
	event.WindowStart = fromMillis(windowStart)
	event.WindowEnd = fromMillis(windowEnd)
	event.AvailableAt = fromMillis(availableAt)
	event.Status = EventStatus(status)
	event.QueuedAt = optionalTime(queuedAt)
	return event, true, nil
}

func (r *Repository) queryDueEvents(ctx context.Context, queryer interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
}, nowMS int64, limit int, windowGrace, stale time.Duration) ([]Event, error) {
	graceMS := nonNegativeDuration(windowGrace).Milliseconds()
	staleMS := nonNegativeDuration(stale).Milliseconds()
	rows, err := queryer.QueryContext(ctx, `
SELECT event.student_id, event.action_key, event.activity_id, event.sign_type,
       event.event_at, event.window_start, event.window_end,
       event.available_at, event.status, event.queued_at
FROM club_schedule_events AS event
INNER JOIN club_schedules AS schedule ON schedule.student_id = event.student_id
WHERE schedule.enabled = 1
  AND event.status = 'pending'
  AND event.window_start <= ?
  AND event.window_end >= ?
  AND event.available_at <= ?
  AND (event.queued_at IS NULL OR event.queued_at <= ?)
ORDER BY event.event_at, event.student_id
LIMIT ?`,
		nowMS,
		nowMS-graceMS,
		nowMS,
		nowMS-staleMS,
		boundedLimit(limit),
	)
	if err != nil {
		return nil, fmt.Errorf("autorun store: list due events: %w", err)
	}
	defer rows.Close()
	result := make([]Event, 0)
	for rows.Next() {
		event, _, err := scanEvent(rows)
		if err != nil {
			return nil, fmt.Errorf("autorun store: scan due event: %w", err)
		}
		result = append(result, event)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("autorun store: iterate due events: %w", err)
	}
	return result, nil
}

func normalizeEvent(studentID int64, event Event) (Event, error) {
	if event.StudentID == 0 {
		event.StudentID = studentID
	}
	if event.StudentID != studentID {
		return Event{}, fmt.Errorf("%w: event student ID does not match schedule", ErrInvalidArgument)
	}
	event.ActionKey = strings.TrimSpace(event.ActionKey)
	if event.ActionKey == "" || len(event.ActionKey) > 160 {
		return Event{}, fmt.Errorf("%w: invalid event action key", ErrInvalidArgument)
	}
	if event.SignType != SignInType && event.SignType != SignBackType {
		return Event{}, fmt.Errorf("%w: invalid event sign type", ErrInvalidArgument)
	}
	if event.AvailableAt.IsZero() {
		event.AvailableAt = event.WindowStart
	}
	return event, nil
}

func eventAvailableAt(event Event) time.Time {
	if event.AvailableAt.IsZero() {
		return event.WindowStart
	}
	return event.AvailableAt
}

func (r *Repository) validateDB() error {
	if r == nil || r.db == nil {
		return errors.New("autorun store: database is nil")
	}
	return nil
}

func normalizeContext(ctx context.Context) context.Context {
	if ctx == nil {
		return context.Background()
	}
	return ctx
}

func nowOrCurrent(now time.Time) time.Time {
	if now.IsZero() {
		return time.Now().UTC()
	}
	return now.UTC()
}

func millis(value time.Time) int64 {
	if value.IsZero() {
		return 0
	}
	return value.UnixMilli()
}

func fromMillis(value int64) time.Time {
	if value == 0 {
		return time.Time{}
	}
	return time.UnixMilli(value).UTC()
}

func optionalTime(value sql.NullInt64) *time.Time {
	if !value.Valid || value.Int64 == 0 {
		return nil
	}
	result := fromMillis(value.Int64)
	return &result
}

func durationOrDefault(value []time.Duration, fallback time.Duration) time.Duration {
	if len(value) == 0 {
		return fallback
	}
	return nonNegativeDuration(value[0])
}

func nonNegativeDuration(value time.Duration) time.Duration {
	if value < 0 {
		return 0
	}
	return value
}

func boundedLimit(value int) int {
	if value <= 0 {
		return 1
	}
	if value > maxReadLimit {
		return maxReadLimit
	}
	return value
}

func boolInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func truncateString(value string, maxRunes int) string {
	runes := []rune(value)
	if len(runes) <= maxRunes {
		return value
	}
	return string(runes[:maxRunes])
}
