package migrations

import (
	"context"
	"path/filepath"
	"testing"

	"cuit-server/internal/platform/database"
)

func TestApplyMigratesLegacyAcademicSessionOnce(t *testing.T) {
	ctx := context.Background()
	db, err := database.OpenSQLite(ctx, filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	usersMigration, err := migrationFiles.ReadFile("001_create_users.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, string(usersMigration)); err != nil {
		t.Fatal(err)
	}
	legacyToken := []byte("legacy-session-token-hash")
	if _, err := db.ExecContext(ctx, `
INSERT INTO users (student_no, jwxt_password_enc, session_token_hash)
VALUES (?, ?, ?)`, "test-student", []byte("encrypted-password"), legacyToken); err != nil {
		t.Fatal(err)
	}

	if err := Apply(ctx, db); err != nil {
		t.Fatal(err)
	}
	if err := Apply(ctx, db); err != nil {
		t.Fatalf("migration should remain idempotent: %v", err)
	}

	var sessionCount int
	if err := db.QueryRowContext(ctx, `
SELECT COUNT(*)
FROM academic_sessions
WHERE token_hash = ?`, legacyToken).Scan(&sessionCount); err != nil {
		t.Fatal(err)
	}
	if sessionCount != 1 {
		t.Fatalf("legacy session count = %d, want 1", sessionCount)
	}

	var legacyCount int
	if err := db.QueryRowContext(ctx, `
SELECT COUNT(*)
FROM users
WHERE session_token_hash IS NOT NULL`).Scan(&legacyCount); err != nil {
		t.Fatal(err)
	}
	if legacyCount != 0 {
		t.Fatalf("legacy user session fields remaining = %d, want 0", legacyCount)
	}
}
