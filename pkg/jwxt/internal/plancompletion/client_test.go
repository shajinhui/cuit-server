package plancompletion

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

func TestGetPlanCompletionMatchesEAMSRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != planCompletionPath {
			t.Fatalf("unexpected request: method=%s path=%s", r.Method, r.URL.Path)
		}
		if r.URL.RawQuery != "" {
			t.Fatalf("unexpected query: %q", r.URL.RawQuery)
		}
		if r.Header.Get("Referer") == "" {
			t.Fatal("plan completion request is missing referer")
		}
		if r.Header.Get("X-Requested-With") != "" {
			t.Fatalf("document request must not use AJAX header: %q", r.Header.Get("X-Requested-With"))
		}
		_, _ = w.Write([]byte(samplePlanCompletionHTML))
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	result, err := GetPlanCompletion(context.Background(), resty.New(), baseURL)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Items) != 2 || result.Summary.StudentNo != "test-student" {
		t.Fatalf("unexpected result: %+v", result)
	}
}

func TestGetPlanCompletionClassifiesRedirectAsExpiredSession(t *testing.T) {
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
	_, err = GetPlanCompletion(context.Background(), client, baseURL)
	if !errors.Is(err, jwxterr.ErrSessionExpired) {
		t.Fatalf("expected expired session error, got %v", err)
	}
}
