package academic

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"testing"
	"time"

	"cuit-server/pkg/jwxt"
)

type fakeGradeClient struct {
	loginUsername string
	loginPassword string
	loginErr      error
	grades        []jwxt.Grade
	gradeErr      error
}

func (f *fakeGradeClient) Login(_ context.Context, username string, password string) error {
	f.loginUsername = username
	f.loginPassword = password
	return f.loginErr
}

func (f *fakeGradeClient) ListSemesters(context.Context) ([]jwxt.Semester, error) {
	return []jwxt.Semester{{ID: "906", SchoolYear: "2025-2026", Term: "2"}}, nil
}

func (f *fakeGradeClient) GetGrades(context.Context, string) ([]jwxt.Grade, error) {
	return f.grades, f.gradeErr
}

func TestLoginPersistsEncryptedCredentialAndSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	client := &fakeGradeClient{grades: []jwxt.Grade{{CourseName: "示例课程"}}}
	service := NewService(func() (GradeClient, error) { return client, nil }, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), " test-student ", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	authenticated, err := service.Authenticated(context.Background(), sessionID)
	if err != nil || !authenticated {
		t.Fatalf("new session should be authenticated: authenticated=%v err=%v", authenticated, err)
	}
	stored := repository.users[1]
	if stored.StudentNo != "test-student" || string(stored.EncryptedPassword) == "test-password" {
		t.Fatalf("credential was not stored correctly")
	}
	grades, err := service.GetGrades(context.Background(), sessionID, "906")
	if err != nil || len(grades) != 1 {
		t.Fatalf("unexpected grades: grades=%+v err=%v", grades, err)
	}
}

func TestQueryRestoresJWXTClientFromStoredSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeGradeClient{}
	service := NewService(func() (GradeClient, error) { return initial, nil }, repository, credentials, time.Hour)
	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}

	restored := &fakeGradeClient{}
	restartedService := NewService(func() (GradeClient, error) { return restored, nil }, repository, credentials, time.Hour)
	if _, err := restartedService.ListSemesters(context.Background(), sessionID); err != nil {
		t.Fatal(err)
	}
	if restored.loginUsername != "test-student" || restored.loginPassword != "test-password" {
		t.Fatal("stored credential was not used to restore the JWXT client")
	}
}

func TestGradeQueryReloginsAfterEAMSSessionExpires(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeGradeClient{gradeErr: jwxt.ErrSessionExpired}
	restored := &fakeGradeClient{grades: []jwxt.Grade{{CourseName: "恢复后的课程"}}}
	clients := []GradeClient{initial, restored}
	service := NewService(func() (GradeClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	grades, err := service.GetGrades(context.Background(), sessionID, "906")
	if err != nil {
		t.Fatal(err)
	}
	if len(grades) != 1 || grades[0].CourseName != "恢复后的课程" {
		t.Fatalf("unexpected grades after relogin: %+v", grades)
	}
	if restored.loginUsername != "test-student" {
		t.Fatal("replacement client was not logged in")
	}
}

func TestServiceRejectsExpiredStoredSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	service := NewService(func() (GradeClient, error) { return &fakeGradeClient{}, nil }, repository, credentials, time.Hour)
	now := time.Date(2026, 7, 21, 12, 0, 0, 0, time.Local)
	service.now = func() time.Time { return now }
	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}

	now = now.Add(2 * time.Hour)
	if _, err := service.ListSemesters(context.Background(), sessionID); !errors.Is(err, ErrUnauthenticated) {
		t.Fatalf("expected unauthenticated, got %v", err)
	}
}

func TestInvalidStoredCredentialRemovesSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	service := NewService(func() (GradeClient, error) { return &fakeGradeClient{}, nil }, repository, credentials, time.Hour)
	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}

	restartedService := NewService(func() (GradeClient, error) {
		return &fakeGradeClient{loginErr: jwxt.ErrInvalidCredentials}, nil
	}, repository, credentials, time.Hour)
	if _, err := restartedService.ListSemesters(context.Background(), sessionID); !errors.Is(err, jwxt.ErrInvalidCredentials) {
		t.Fatalf("expected invalid credentials, got %v", err)
	}
	authenticated, err := restartedService.Authenticated(context.Background(), sessionID)
	if err != nil || authenticated {
		t.Fatalf("invalid stored credential should remove session: authenticated=%v err=%v", authenticated, err)
	}
}

func testCredentialCipher(t *testing.T) *CredentialCipher {
	t.Helper()
	key := base64.StdEncoding.EncodeToString(make([]byte, 32))
	credentials, err := NewCredentialCipher(key)
	if err != nil {
		t.Fatal(err)
	}
	return credentials
}

type memorySession struct {
	userID    int64
	expiresAt time.Time
}

type memoryRepository struct {
	users      map[int64]StoredUser
	studentIDs map[string]int64
	sessions   map[[sha256.Size]byte]memorySession
	nextUserID int64
}

func newMemoryRepository() *memoryRepository {
	return &memoryRepository{
		users:      make(map[int64]StoredUser),
		studentIDs: make(map[string]int64),
		sessions:   make(map[[sha256.Size]byte]memorySession),
	}
}

func (r *memoryRepository) UpsertLogin(_ context.Context, studentNo string, encryptedPassword []byte, _ time.Time) (int64, error) {
	userID := r.studentIDs[studentNo]
	if userID == 0 {
		r.nextUserID++
		userID = r.nextUserID
		r.studentIDs[studentNo] = userID
	}
	r.users[userID] = StoredUser{ID: userID, StudentNo: studentNo, EncryptedPassword: append([]byte(nil), encryptedPassword...)}
	return userID, nil
}

func (r *memoryRepository) CreateSession(_ context.Context, userID int64, tokenHash [sha256.Size]byte, expiresAt time.Time) error {
	r.sessions[tokenHash] = memorySession{userID: userID, expiresAt: expiresAt}
	return nil
}

func (r *memoryRepository) FindUserBySession(_ context.Context, tokenHash [sha256.Size]byte, now time.Time) (StoredUser, error) {
	storedSession, ok := r.sessions[tokenHash]
	if !ok || !now.Before(storedSession.expiresAt) {
		return StoredUser{}, ErrStoredSessionNotFound
	}
	user := r.users[storedSession.userID]
	user.SessionExpiresAt = storedSession.expiresAt
	return user, nil
}

func (r *memoryRepository) DeleteSession(_ context.Context, tokenHash [sha256.Size]byte) error {
	delete(r.sessions, tokenHash)
	return nil
}
