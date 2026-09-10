package store

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"testing"
	"time"

	"cuit-server/internal/platform/database"
	"cuit-server/migrations"
)

const testEncryptionSecret = "0123456789abcdef"

func newTestRepository(t *testing.T) (*Repository, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	db, err := database.OpenSQLite(ctx, ":memory:")
	if err != nil {
		t.Fatalf("OpenSQLite() error = %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := migrations.Apply(ctx, db); err != nil {
		t.Fatalf("migrations.Apply() error = %v", err)
	}
	return NewRepository(db, testEncryptionSecret), db
}

func TestRepositorySessionRoundTripAndReplacement(t *testing.T) {
	repository, db := newTestRepository(t)
	ctx := context.Background()
	saved, err := repository.SaveSession(ctx, " 13900000000 ", Session{
		Token:      "upstream-token-a",
		UserID:     11,
		StudentID:  22,
		SchoolID:   33,
		SessionKey: "session-key-000000000001",
	})
	if err != nil {
		t.Fatalf("SaveSession() error = %v", err)
	}
	if saved.PhoneHash != HashPhone("13900000000") || saved.SessionKey != "session-key-000000000001" {
		t.Fatalf("SaveSession() metadata = %+v", saved)
	}

	var ciphertext string
	if err := db.QueryRowContext(ctx, "SELECT token_ciphertext FROM sessions WHERE student_id = 22").Scan(&ciphertext); err != nil {
		t.Fatalf("read ciphertext: %v", err)
	}
	if ciphertext == "" || ciphertext == saved.Token {
		t.Fatalf("token was stored in plaintext: %q", ciphertext)
	}

	byKey, err := repository.GetSessionByKey(ctx, saved.SessionKey)
	if err != nil {
		t.Fatalf("GetSessionByKey() error = %v", err)
	}
	if byKey == nil || byKey.Token != saved.Token || byKey.StudentID != saved.StudentID {
		t.Fatalf("GetSessionByKey() = %+v", byKey)
	}
	byStudent, err := repository.GetSessionByStudentID(ctx, saved.StudentID)
	if err != nil {
		t.Fatalf("GetSessionByStudentID() error = %v", err)
	}
	if byStudent == nil || byStudent.SessionKey != saved.SessionKey {
		t.Fatalf("GetSessionByStudentID() = %+v", byStudent)
	}

	replacement, err := repository.SaveSession(ctx, "13900000001", Session{
		Token:     "upstream-token-b",
		UserID:    12,
		StudentID: 22,
		SchoolID:  34,
	}, "session-key-000000000002")
	if err != nil {
		t.Fatalf("SaveSession() replacement error = %v", err)
	}
	old, err := repository.GetSessionByKey(ctx, saved.SessionKey)
	if err != nil {
		t.Fatalf("GetSessionByKey(old) error = %v", err)
	}
	if old != nil {
		t.Fatalf("old session key still resolves: %+v", old)
	}
	current, err := repository.GetSessionByStudentID(ctx, 22)
	if err != nil {
		t.Fatalf("GetSessionByStudentID(current) error = %v", err)
	}
	if current == nil || current.Token != replacement.Token || current.PhoneHash != HashPhone("13900000001") {
		t.Fatalf("current session = %+v", current)
	}
}

func TestRepositorySchedulesEventsAndAuditStates(t *testing.T) {
	repository, db := newTestRepository(t)
	ctx := context.Background()
	base := time.Date(2026, 9, 10, 10, 0, 0, 0, time.UTC)
	if _, err := repository.SaveSchedule(ctx, 22, 33, "session-key-000000000001", true, base); err != nil {
		t.Fatalf("SaveSchedule() error = %v", err)
	}

	event := Event{
		StudentID:   22,
		ActionKey:   "2026-09-10:100:1",
		ActivityID:  100,
		SignType:    SignInType,
		EventAt:     base,
		WindowStart: base.Add(-10 * time.Minute),
		WindowEnd:   base.Add(10 * time.Minute),
	}
	lateEvent := Event{
		StudentID:   22,
		ActionKey:   "2026-09-10:100:2",
		ActivityID:  100,
		SignType:    SignBackType,
		EventAt:     base.Add(2 * time.Hour),
		WindowStart: base.Add(110 * time.Minute),
		WindowEnd:   base.Add(130 * time.Minute),
	}
	if err := repository.ReplaceEvents(ctx, 22, "2026-09-10", []Event{event, lateEvent}, base, base.Add(4*time.Hour)); err != nil {
		t.Fatalf("ReplaceEvents() error = %v", err)
	}
	stored, err := repository.GetEvent(ctx, 22, event.ActionKey)
	if err != nil {
		t.Fatalf("GetEvent() error = %v", err)
	}
	if stored == nil || stored.Status != EventPending || !stored.AvailableAt.Equal(event.WindowStart) {
		t.Fatalf("stored event = %+v", stored)
	}

	claimed, err := repository.ClaimDueEvents(ctx, base, 10, 0)
	if err != nil {
		t.Fatalf("ClaimDueEvents() error = %v", err)
	}
	if len(claimed) != 1 || claimed[0].ActionKey != event.ActionKey || claimed[0].QueuedAt == nil {
		t.Fatalf("ClaimDueEvents() = %+v", claimed)
	}
	claimedAgain, err := repository.ClaimDueEvents(ctx, base, 10, 0)
	if err != nil {
		t.Fatalf("ClaimDueEvents() second error = %v", err)
	}
	if len(claimedAgain) != 0 {
		t.Fatalf("ClaimDueEvents() claimed a queued event twice: %+v", claimedAgain)
	}
	if err := repository.DeferEvent(ctx, 22, event.ActionKey, base.Add(2*time.Minute)); err != nil {
		t.Fatalf("DeferEvent() error = %v", err)
	}
	if due, err := repository.ListDueEvents(ctx, base, 10, 0); err != nil {
		t.Fatalf("ListDueEvents() error = %v", err)
	} else if len(due) != 0 {
		t.Fatalf("deferred event is due too early: %+v", due)
	}
	if due, err := repository.ListDueEvents(ctx, base.Add(2*time.Minute), 10, 0); err != nil {
		t.Fatalf("ListDueEvents() later error = %v", err)
	} else if len(due) != 1 || due[0].ActionKey != event.ActionKey {
		t.Fatalf("ListDueEvents() later = %+v", due)
	}

	if err := repository.CompleteScheduledAction(ctx, 22, event.ActionKey, SignInType, base.Add(3*time.Minute), "自动签到成功"); err != nil {
		t.Fatalf("CompleteScheduledAction() error = %v", err)
	}
	done, err := repository.GetEvent(ctx, 22, event.ActionKey)
	if err != nil {
		t.Fatalf("GetEvent(done) error = %v", err)
	}
	if done == nil || done.Status != EventDone || done.QueuedAt != nil {
		t.Fatalf("done event = %+v", done)
	}

	// A refresh expires absent pending rows but preserves a completed row.
	if err := repository.ReplaceEvents(ctx, 22, "2026-09-10", []Event{event}, base.Add(4*time.Hour), base.Add(8*time.Hour)); err != nil {
		t.Fatalf("ReplaceEvents() audit refresh error = %v", err)
	}
	done, err = repository.GetEvent(ctx, 22, event.ActionKey)
	if err != nil || done == nil || done.Status != EventDone {
		t.Fatalf("completed event was reactivated: (%+v, %v)", done, err)
	}

	// Reinsert a pending event and expire it by window boundary.  The row stays
	// queryable so its expired status remains an audit record.
	if err := repository.ReplaceEvents(ctx, 22, "2026-09-10", []Event{lateEvent}, base.Add(5*time.Hour), base.Add(9*time.Hour)); err != nil {
		t.Fatalf("ReplaceEvents() pending reinsert error = %v", err)
	}
	expired, err := repository.ExpireOverdue(ctx, base.Add(3*time.Hour))
	if err != nil {
		t.Fatalf("ExpireOverdue() error = %v", err)
	}
	if expired != 1 {
		t.Fatalf("ExpireOverdue() = %d, want 1", expired)
	}
	late, err := repository.GetEvent(ctx, 22, lateEvent.ActionKey)
	if err != nil || late == nil || late.Status != EventExpired {
		t.Fatalf("expired event = (%+v, %v)", late, err)
	}

	debug, err := repository.Debug(ctx)
	if err != nil {
		t.Fatalf("Debug() error = %v", err)
	}
	if !debug.Enabled || debug.Database != "SQLite" || debug.SessionCount != 0 || debug.ScheduleCount != 1 {
		t.Fatalf("Debug() = %+v", debug)
	}
	var status string
	if err := db.QueryRowContext(ctx, "SELECT status FROM club_schedule_events WHERE student_id = 22 AND action_key = ?", lateEvent.ActionKey).Scan(&status); err != nil {
		t.Fatalf("read event status: %v", err)
	}
	if status != string(EventExpired) {
		t.Fatalf("stored event status = %q, want expired", status)
	}
}

func TestRepositoryActionClaimLifecycleAndAtomicity(t *testing.T) {
	repository, _ := newTestRepository(t)
	ctx := context.Background()
	base := time.Date(2026, 9, 10, 10, 0, 0, 0, time.UTC)

	claimed, err := repository.TryClaimAction(ctx, 22, "2026-09-10:100:1", base)
	if err != nil || !claimed {
		t.Fatalf("TryClaimAction(first) = (%v, %v)", claimed, err)
	}
	claimed, err = repository.TryClaimAction(ctx, 22, "2026-09-10:100:1", base.Add(time.Second))
	if err != nil || claimed {
		t.Fatalf("TryClaimAction(duplicate) = (%v, %v)", claimed, err)
	}
	claim, err := repository.GetActionClaim(ctx, 22, "2026-09-10:100:1")
	if err != nil || claim == nil || claim.Status != ActionInFlight {
		t.Fatalf("GetActionClaim() = (%+v, %v)", claim, err)
	}
	if err := repository.CompleteAction(ctx, 22, "2026-09-10:100:1", base.Add(2*time.Minute)); err != nil {
		t.Fatalf("CompleteAction() error = %v", err)
	}
	claimed, err = repository.TryClaimAction(ctx, 22, "2026-09-10:100:1", base.Add(3*time.Minute))
	if err != nil || claimed {
		t.Fatalf("TryClaimAction(done) = (%v, %v)", claimed, err)
	}
	complete, err := repository.IsActionComplete(ctx, 22, "2026-09-10:100:1")
	if err != nil || !complete {
		t.Fatalf("IsActionComplete() = (%v, %v)", complete, err)
	}

	const failedKey = "2026-09-10:100:2"
	if claimed, err := repository.TryClaimAction(ctx, 22, failedKey, base); err != nil || !claimed {
		t.Fatalf("TryClaimAction(failed first) = (%v, %v)", claimed, err)
	}
	if err := repository.FailAction(ctx, 22, failedKey); err != nil {
		t.Fatalf("FailAction() error = %v", err)
	}
	if claimed, err := repository.TryClaimAction(ctx, 22, failedKey, base.Add(time.Second)); err != nil || !claimed {
		t.Fatalf("TryClaimAction(failed retry) = (%v, %v)", claimed, err)
	}

	const concurrentKey = "2026-09-10:100:3"
	results := make(chan bool, 8)
	var group sync.WaitGroup
	for i := 0; i < 8; i++ {
		group.Add(1)
		go func() {
			defer group.Done()
			ok, err := repository.TryClaimAction(ctx, 22, concurrentKey, base)
			if err != nil {
				t.Errorf("concurrent TryClaimAction() error = %v", err)
			}
			results <- ok
		}()
	}
	group.Wait()
	close(results)
	trueCount := 0
	for result := range results {
		if result {
			trueCount++
		}
	}
	if trueCount != 1 {
		t.Fatalf("concurrent TryClaimAction() success count = %d, want 1", trueCount)
	}
}

func TestRepositoryRejectsInvalidSessionWithoutWritingPasswordLikeValues(t *testing.T) {
	repository, db := newTestRepository(t)
	ctx := context.Background()
	if _, err := repository.SaveSession(ctx, "13900000000", Session{Token: "", UserID: 1, StudentID: 2, SchoolID: 3}); !errors.Is(err, ErrInvalidArgument) {
		t.Fatalf("SaveSession(invalid) error = %v, want ErrInvalidArgument", err)
	}
	var count int
	if err := db.QueryRowContext(ctx, "SELECT COUNT(*) FROM sessions").Scan(&count); err != nil {
		t.Fatalf("count sessions: %v", err)
	}
	if count != 0 {
		t.Fatalf("invalid session changed database, count = %d", count)
	}
	if _, err := repository.SaveSchedule(ctx, 0, 1, "", true); !errors.Is(err, ErrInvalidArgument) {
		t.Fatalf("SaveSchedule(invalid) error = %v", err)
	}
}
