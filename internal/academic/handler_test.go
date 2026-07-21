package academic

import (
	"bytes"
	"context"
	"strings"
	"testing"

	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

type fakeGradeService struct{}

func (fakeGradeService) Login(context.Context, string, string) (string, error) {
	return "test-session", nil
}

func (fakeGradeService) ListSemesters(context.Context, string) ([]jwxt.Semester, error) {
	return nil, ErrUnauthenticated
}

func (fakeGradeService) GetGrades(context.Context, string, string) ([]jwxt.Grade, error) {
	return nil, ErrUnauthenticated
}

func (fakeGradeService) Authenticated(_ context.Context, sessionID string) (bool, error) {
	return sessionID == "test-session", nil
}

func (fakeGradeService) Logout(context.Context, string) error { return nil }

func TestLoginSetsHttpOnlySessionCookie(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)
	body := []byte(`{"username":"20240001","password":"secret"}`)

	recorder := ut.PerformRequest(
		h.Engine,
		"POST",
		"/api/v1/jwxt/session",
		&ut.Body{Body: bytes.NewReader(body), Len: len(body)},
		ut.Header{Key: "Content-Type", Value: "application/json"},
	)
	response := recorder.Result()
	if response.StatusCode() != 200 {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
	cookie := string(response.Header.Peek("Set-Cookie"))
	if !strings.Contains(cookie, "campus_session=test-session") || !strings.Contains(cookie, "HttpOnly") {
		t.Fatalf("session cookie is missing required attributes: %s", cookie)
	}
}

func TestSemestersRequiresAuthenticatedSession(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	recorder := ut.PerformRequest(h.Engine, "GET", "/api/v1/jwxt/semesters", nil)
	response := recorder.Result()
	if response.StatusCode() != 401 {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
	if !strings.Contains(string(response.Body()), `"code":40101`) {
		t.Fatalf("unexpected response: %s", response.Body())
	}
}

func TestSessionStatusDoesNotCallRemoteSystem(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	recorder := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/session",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
	)
	response := recorder.Result()
	if response.StatusCode() != 200 || !strings.Contains(string(response.Body()), `"authenticated":true`) {
		t.Fatalf("unexpected response: %s", response.Body())
	}
}
