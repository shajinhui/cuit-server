package academic

import (
	"context"
	"crypto/sha256"
	"errors"
	"path/filepath"
	"testing"
	"time"

	"cuit-server/internal/platform/database"
	"cuit-server/migrations"
)

func TestSQLiteRepositoryKeepsOnlyLatestSession(t *testing.T) {
	ctx := context.Background()
	db, err := database.OpenSQLite(ctx, filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := migrations.Apply(ctx, db); err != nil {
		t.Fatal(err)
	}

	repository := NewSQLiteRepository(db)
	user := LoginUser{
		StudentNo:      "test-student",
		Name:           "测试同学",
		College:        "测试学院",
		Major:          "测试专业",
		EnrollmentYear: 2024,
	}
	firstToken := sha256.Sum256([]byte("first-session"))
	secondToken := sha256.Sum256([]byte("second-session"))
	if _, err := repository.UpsertLogin(ctx, user, []byte("encrypted-one"), firstToken, time.Now()); err != nil {
		t.Fatal(err)
	}
	if _, err := repository.UpsertLogin(ctx, user, []byte("encrypted-two"), secondToken, time.Now()); err != nil {
		t.Fatal(err)
	}

	if _, err := repository.FindUserBySession(ctx, firstToken); !errors.Is(err, ErrStoredSessionNotFound) {
		t.Fatalf("old session should be overwritten, got %v", err)
	}
	stored, err := repository.FindUserBySession(ctx, secondToken)
	if err != nil {
		t.Fatal(err)
	}
	if stored.StudentNo != user.StudentNo || string(stored.EncryptedPassword) != "encrypted-two" {
		t.Fatalf("unexpected stored user: %+v", stored)
	}
}
