package exam

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

func TestExamRequestsMatchEAMSProtocol(t *testing.T) {
	batchRequests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case entryPath:
			batchRequests++
			assertExamSemesterRequest(t, r, "906")
			_, _ = w.Write([]byte(`
<form id="semesterForm">
  <select name="examBatch.id">
    <option value="5027" selected>开学补考</option>
    <option value="4926">期末考试</option>
  </select>
</form>`))
		case examTablePath:
			assertExamTableRequest(t, r)
			_, _ = w.Write([]byte(sampleExamHTML))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	client := resty.New()

	batches, err := ListBatches(context.Background(), client, baseURL, "906")
	if err != nil {
		t.Fatalf("ListBatches returned error: %v", err)
	}
	if len(batches) != 2 || batches[1].ID != "4926" {
		t.Fatalf("unexpected batches: %+v", batches)
	}
	if batchRequests != 1 {
		t.Fatalf("semester batches must be queried once: %d", batchRequests)
	}

	exams, err := GetExamsByType(context.Background(), client, baseURL, "906", ExamTypeFinal)
	if err != nil {
		t.Fatalf("GetExamsByType returned error: %v", err)
	}
	if len(exams) != 2 || exams[0].Location != "A101" {
		t.Fatalf("unexpected exams: %+v", exams)
	}
	if batchRequests != 2 {
		t.Fatalf("each exam type query must read target semester batches: %d", batchRequests)
	}
}

func TestGetExamsByTypeReturnsEmptyWhenSemesterHasNoBatch(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != entryPath {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		assertExamSemesterRequest(t, r, "1106")
		_, _ = w.Write([]byte(`<form id="semesterForm"><select name="examBatch.id"></select></form>`))
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	exams, err := GetExamsByType(context.Background(), resty.New(), baseURL, "1106", ExamTypeFinal)
	if err != nil {
		t.Fatalf("GetExamsByType returned error: %v", err)
	}
	if len(exams) != 0 {
		t.Fatalf("expected no exams, got %+v", exams)
	}
}

func TestExamRequestClassifiesRedirectAsExpiredSession(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Location", "/login")
		w.WriteHeader(http.StatusFound)
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	client := resty.New().SetRedirectPolicy(resty.NoRedirectPolicy())
	_, err = ListBatches(context.Background(), client, baseURL, "906")
	if !errors.Is(err, jwxterr.ErrSessionExpired) {
		t.Fatalf("expected expired session error, got %v", err)
	}
}

func assertExamSemesterRequest(t *testing.T, r *http.Request, semesterID string) {
	t.Helper()
	if r.Method != http.MethodGet {
		t.Fatalf("unexpected semester request method: %s", r.Method)
	}
	if r.Header.Get("X-Requested-With") != "" {
		t.Fatalf("exam semester document must not use AJAX header: %q", r.Header.Get("X-Requested-With"))
	}
	if r.URL.RawQuery != "" {
		t.Fatalf("exam entry must not carry query parameters: %s", r.URL.RawQuery)
	}
	semesterCookie, err := r.Cookie("semester.id")
	if err != nil || semesterCookie.Value != semesterID {
		t.Fatalf("unexpected semester cookie: cookie=%v err=%v", semesterCookie, err)
	}
}

func assertExamTableRequest(t *testing.T, r *http.Request) {
	t.Helper()
	if r.Method != http.MethodGet {
		t.Fatalf("unexpected exam table method: %s", r.Method)
	}
	if r.URL.Query().Get("examBatch.id") != "4926" {
		t.Fatalf("unexpected exam batch ID: %q", r.URL.Query().Get("examBatch.id"))
	}
	if r.Header.Get("X-Requested-With") != "XMLHttpRequest" {
		t.Fatalf("unexpected X-Requested-With: %q", r.Header.Get("X-Requested-With"))
	}
	if r.Header.Get("Referer") == "" {
		t.Fatal("exam table request is missing referer")
	}
}
