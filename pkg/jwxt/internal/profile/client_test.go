package profile

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

func TestGetStudentProfileMatchesEAMSRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != profilePath {
			t.Fatalf("unexpected request: method=%s path=%s", r.Method, r.URL.Path)
		}
		if r.URL.RawQuery != "" {
			t.Fatalf("unexpected query: %q", r.URL.RawQuery)
		}
		if r.Header.Get("Referer") == "" {
			t.Fatal("profile request is missing referer")
		}
		if r.Header.Get("X-Requested-With") != "" {
			t.Fatalf("profile document request must not use AJAX header: %q", r.Header.Get("X-Requested-With"))
		}
		_, _ = w.Write([]byte(`
<table id="studentInfoTb" class="infoTable">
  <tr>
    <td class="title">学号：</td><td>test-student</td>
    <td class="title">姓名：</td><td>测试同学</td>
  </tr>
</table>`))
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	result, err := GetStudentProfile(context.Background(), resty.New(), baseURL)
	if err != nil {
		t.Fatal(err)
	}
	if result.StudentNo != "test-student" || result.Name != "测试同学" {
		t.Fatalf("unexpected profile: %+v", result)
	}
}

func TestGetStudentProfileClassifiesRedirectAsExpiredSession(t *testing.T) {
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
	_, err = GetStudentProfile(context.Background(), client, baseURL)
	if !errors.Is(err, jwxterr.ErrSessionExpired) {
		t.Fatalf("expected expired session error, got %v", err)
	}
}
