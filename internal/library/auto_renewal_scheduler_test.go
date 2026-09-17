package library

import (
	"context"
	"testing"
	"time"

	"cuit-server/pkg/jwxt"
)

type fakeAutoRenewalExecutor struct {
	calls int
}

func (executor *fakeAutoRenewalExecutor) ExecuteLibraryAutoRenewal(
	context.Context,
	int64,
	string,
	int,
	string,
) (jwxt.LibraryOperationResult, error) {
	executor.calls++
	return jwxt.LibraryOperationResult{Message: "续座成功"}, nil
}

func TestAutoRenewalSchedulerProcessesClaimedJobOnce(t *testing.T) {
	ctx := context.Background()
	db, userID, sessionHash := openAutoRenewalTestDB(t)
	defer db.Close()
	repository := NewAutoRenewalRepository(db)
	now := time.Date(2026, 9, 17, 10, 0, 0, 0, time.UTC)
	if _, err := repository.Schedule(ctx, ScheduleAutoRenewalInput{
		UserID: userID, SessionTokenHash: sessionHash,
		ReservationID: "88", DurationMinutes: 60,
		ReservationEnd: "2026-09-17 18:00:00", ExecuteAt: now,
	}, now.Add(-time.Minute)); err != nil {
		t.Fatal(err)
	}
	claimed, err := repository.ClaimDue(ctx, now, 1)
	if err != nil || len(claimed) != 1 {
		t.Fatalf("unexpected claim: jobs=%+v err=%v", claimed, err)
	}
	executor := &fakeAutoRenewalExecutor{}
	scheduler := NewAutoRenewalScheduler(repository, executor, AutoRenewalSchedulerConfig{})
	scheduler.process(ctx, claimed[0])
	stored, err := repository.GetByReservation(ctx, userID, "88")
	if err != nil || stored == nil || stored.Status != AutoRenewalSucceeded || executor.calls != 1 {
		t.Fatalf("unexpected scheduler result: item=%+v calls=%d err=%v", stored, executor.calls, err)
	}
}

func TestAutoRenewalSchedulerSkipsAfterLogoutWithoutCallingExecutor(t *testing.T) {
	ctx := context.Background()
	db, userID, sessionHash := openAutoRenewalTestDB(t)
	defer db.Close()
	repository := NewAutoRenewalRepository(db)
	now := time.Date(2026, 9, 17, 10, 0, 0, 0, time.UTC)
	if _, err := repository.Schedule(ctx, ScheduleAutoRenewalInput{
		UserID: userID, SessionTokenHash: sessionHash,
		ReservationID: "88", DurationMinutes: 60,
		ReservationEnd: "2026-09-17 18:00:00", ExecuteAt: now,
	}, now.Add(-time.Minute)); err != nil {
		t.Fatal(err)
	}
	claimed, err := repository.ClaimDue(ctx, now, 1)
	if err != nil || len(claimed) != 1 {
		t.Fatalf("unexpected claim: jobs=%+v err=%v", claimed, err)
	}
	if _, err := db.ExecContext(ctx, `DELETE FROM academic_sessions WHERE token_hash = ?`, sessionHash[:]); err != nil {
		t.Fatal(err)
	}
	executor := &fakeAutoRenewalExecutor{}
	scheduler := NewAutoRenewalScheduler(repository, executor, AutoRenewalSchedulerConfig{})
	scheduler.process(ctx, claimed[0])
	stored, err := repository.GetByReservation(ctx, userID, "88")
	if err != nil || stored == nil || stored.Status != AutoRenewalSkipped || executor.calls != 0 {
		t.Fatalf("unexpected scheduler result: item=%+v calls=%d err=%v", stored, executor.calls, err)
	}
}
