package library

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"path/filepath"
	"testing"
	"time"

	"cuit-server/internal/platform/database"
	"cuit-server/migrations"
)

func TestAutoRenewalRepositoryClaimsOnceAndCompletes(t *testing.T) {
	ctx := context.Background()
	db, userID, sessionHash := openAutoRenewalTestDB(t)
	defer db.Close()
	repository := NewAutoRenewalRepository(db)
	now := time.Date(2026, 9, 17, 10, 0, 0, 0, time.UTC)
	scheduled, err := repository.Schedule(ctx, ScheduleAutoRenewalInput{
		UserID: userID, SessionTokenHash: sessionHash,
		ReservationID: "88", ReservationUUID: "uuid-88", DurationMinutes: 60,
		ReservationEnd: "2026-09-17 18:00:00", ExecuteAt: now,
	}, now.Add(-time.Minute))
	if err != nil {
		t.Fatal(err)
	}
	if scheduled.Status != AutoRenewalScheduled {
		t.Fatalf("unexpected scheduled item: %+v", scheduled)
	}
	claimed, err := repository.ClaimDue(ctx, now, 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(claimed) != 1 || claimed[0].AttemptCount != 1 || claimed[0].Status != AutoRenewalRunning {
		t.Fatalf("unexpected claimed items: %+v", claimed)
	}
	claimedAgain, err := repository.ClaimDue(ctx, now.Add(time.Second), 10)
	if err != nil || len(claimedAgain) != 0 {
		t.Fatalf("claim should be idempotent: items=%+v err=%v", claimedAgain, err)
	}
	if err := repository.Complete(ctx, claimed[0].ID, AutoRenewalSucceeded, "续座成功", now.Add(time.Second)); err != nil {
		t.Fatal(err)
	}
	stored, err := repository.GetByReservation(ctx, userID, "88")
	if err != nil || stored == nil || stored.Status != AutoRenewalSucceeded || stored.LastMessage != "续座成功" {
		t.Fatalf("unexpected completed item: item=%+v err=%v", stored, err)
	}
}

func TestAcademicLogoutCancelsScheduledAutoRenewal(t *testing.T) {
	ctx := context.Background()
	db, userID, sessionHash := openAutoRenewalTestDB(t)
	defer db.Close()
	repository := NewAutoRenewalRepository(db)
	now := time.Date(2026, 9, 17, 10, 0, 0, 0, time.UTC)
	if _, err := repository.Schedule(ctx, ScheduleAutoRenewalInput{
		UserID: userID, SessionTokenHash: sessionHash,
		ReservationID: "88", DurationMinutes: 60,
		ReservationEnd: "2026-09-17 18:00:00", ExecuteAt: now.Add(time.Hour),
	}, now); err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, `DELETE FROM academic_sessions WHERE token_hash = ?`, sessionHash[:]); err != nil {
		t.Fatal(err)
	}
	stored, err := repository.GetByReservation(ctx, userID, "88")
	if err != nil || stored == nil || stored.Status != AutoRenewalCancelled {
		t.Fatalf("logout should cancel schedule: item=%+v err=%v", stored, err)
	}
}

func openAutoRenewalTestDB(t *testing.T) (*sql.DB, int64, [sha256.Size]byte) {
	t.Helper()
	ctx := context.Background()
	db, err := database.OpenSQLite(ctx, filepath.Join(t.TempDir(), "library-auto-renewal.db"))
	if err != nil {
		t.Fatal(err)
	}
	if err := migrations.Apply(ctx, db); err != nil {
		db.Close()
		t.Fatal(err)
	}
	const userID = int64(1)
	sessionHash := sha256.Sum256([]byte("test-session"))
	if _, err := db.ExecContext(ctx, `
INSERT INTO users (id, student_no, jwxt_password_enc) VALUES (?, 'test-student', X'01')`, userID); err != nil {
		db.Close()
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, `
INSERT INTO academic_sessions (token_hash, user_id) VALUES (?, ?)`, sessionHash[:], userID); err != nil {
		db.Close()
		t.Fatal(err)
	}
	return db, userID, sessionHash
}
