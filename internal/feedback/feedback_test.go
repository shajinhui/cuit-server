package feedback

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"path/filepath"
	"testing"
	"time"

	"cuit-server/internal/academic"
	"cuit-server/internal/platform/database"
	"cuit-server/migrations"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

type fixedUserResolver struct {
	userID int64
	err    error
}

func (r fixedUserResolver) ResolveUserID(context.Context, string) (int64, error) {
	return r.userID, r.err
}

func TestFeedbackEndpointPersistsAuthenticatedSubmission(t *testing.T) {
	db := openTestDatabase(t)
	userID := insertTestUser(t, db)
	repository := NewRepository(db)
	repository.now = func() time.Time {
		return time.Date(2026, 7, 28, 3, 4, 5, 0, time.UTC)
	}
	h := server.Default()
	NewHandler(fixedUserResolver{userID: userID}, repository).Register(h)

	body := []byte(`{"type":"bug","platform":"android","content":"课表页面在横屏时课程卡片发生重叠"}`)
	response := ut.PerformRequest(
		h.Engine,
		http.MethodPost,
		"/api/v1/feedback",
		&ut.Body{Body: bytes.NewReader(body), Len: len(body)},
		ut.Header{Key: "Content-Type", Value: "application/json"},
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
		ut.Header{Key: "User-Agent", Value: "test-device"},
	).Result()
	if response.StatusCode() != http.StatusOK {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}

	var count int
	var feedbackType, platform, content, userAgent string
	if err := db.QueryRow(`
SELECT COUNT(*), feedback_type, platform, content, user_agent
FROM feedback
WHERE user_id = ?`, userID).Scan(&count, &feedbackType, &platform, &content, &userAgent); err != nil {
		t.Fatal(err)
	}
	if count != 1 || feedbackType != TypeBug || platform != PlatformAndroid ||
		content != "课表页面在横屏时课程卡片发生重叠" || userAgent != "test-device" {
		t.Fatalf("unexpected saved feedback: count=%d type=%s platform=%s content=%s userAgent=%s", count, feedbackType, platform, content, userAgent)
	}
}

func TestFeedbackEndpointRejectsInvalidOrAnonymousSubmission(t *testing.T) {
	h := server.Default()
	NewHandler(fixedUserResolver{err: academic.ErrUnauthenticated}, rejectingRepository{}).Register(h)

	invalidBody := []byte(`{"type":"question","platform":"web","content":"太短"}`)
	invalid := ut.PerformRequest(
		h.Engine,
		http.MethodPost,
		"/api/v1/feedback",
		&ut.Body{Body: bytes.NewReader(invalidBody), Len: len(invalidBody)},
		ut.Header{Key: "Content-Type", Value: "application/json"},
	).Result()
	if invalid.StatusCode() != http.StatusBadRequest {
		t.Fatalf("unexpected invalid status: %d", invalid.StatusCode())
	}

	validBody := []byte(`{"type":"suggestion","platform":"ios","content":"希望增加桌面小组件展示下一节课程"}`)
	anonymous := ut.PerformRequest(
		h.Engine,
		http.MethodPost,
		"/api/v1/feedback",
		&ut.Body{Body: bytes.NewReader(validBody), Len: len(validBody)},
		ut.Header{Key: "Content-Type", Value: "application/json"},
	).Result()
	if anonymous.StatusCode() != http.StatusUnauthorized {
		t.Fatalf("unexpected anonymous status: %d body=%s", anonymous.StatusCode(), anonymous.Body())
	}
	var payload struct {
		Code int `json:"code"`
	}
	if err := json.Unmarshal(anonymous.Body(), &payload); err != nil {
		t.Fatal(err)
	}
	if payload.Code != 40101 {
		t.Fatalf("unexpected anonymous response code: %d", payload.Code)
	}
}

func TestRepositoryListsRecentFeedback(t *testing.T) {
	db := openTestDatabase(t)
	userID := insertTestUser(t, db)
	repository := NewRepository(db)
	times := []time.Time{
		time.Date(2026, 7, 28, 1, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 28, 2, 0, 0, 0, time.UTC),
	}
	for _, createdAt := range times {
		repository.now = func() time.Time { return createdAt }
		if _, err := repository.Create(context.Background(), userID, Submission{
			Type:      TypeSuggestion,
			Platform:  PlatformAndroid,
			Content:   "用于测试排序的反馈内容",
			UserAgent: "test-device",
		}); err != nil {
			t.Fatal(err)
		}
	}

	records, err := repository.ListRecent(context.Background(), 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(records) != 1 || !records[0].CreatedAt.Equal(times[1]) {
		t.Fatalf("unexpected recent feedback: %+v", records)
	}
}

type rejectingRepository struct{}

func (rejectingRepository) Create(context.Context, int64, Submission) (Record, error) {
	return Record{}, errors.New("unexpected repository call")
}

func openTestDatabase(t *testing.T) *sql.DB {
	t.Helper()
	db, err := database.OpenSQLite(context.Background(), filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := db.Close(); err != nil {
			t.Error(err)
		}
	})
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	return db
}

func insertTestUser(t *testing.T, db *sql.DB) int64 {
	t.Helper()
	result, err := db.Exec(`
INSERT INTO users (student_no, name, jwxt_password_enc)
VALUES (?, ?, ?)`,
		"feedback-test-user",
		"反馈测试",
		[]byte("encrypted"),
	)
	if err != nil {
		t.Fatal(err)
	}
	userID, err := result.LastInsertId()
	if err != nil {
		t.Fatal(err)
	}
	return userID
}
