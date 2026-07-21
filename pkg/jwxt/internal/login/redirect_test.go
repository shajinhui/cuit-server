package login

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/go-resty/resty/v2"
)

func TestFollowHandlesRestyNoRedirectPolicy(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/start":
			http.Redirect(w, r, "/login", http.StatusFound)
		case "/login":
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(`ok`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	restyClient := resty.New().SetRedirectPolicy(resty.NoRedirectPolicy())
	page, err := follow(context.Background(), restyClient, mustTestURL(t, server.URL+"/start"), 5)
	if err != nil {
		t.Fatalf("follow returned error: %v", err)
	}
	if page.Status != http.StatusOK {
		t.Fatalf("unexpected status: %d", page.Status)
	}
	if page.URL.Path != "/login" {
		t.Fatalf("unexpected final path: %s", page.URL.Path)
	}
	if len(page.Steps) != 2 {
		t.Fatalf("unexpected steps: %d", len(page.Steps))
	}
}

func TestCASLoginURLAllowsDefaultHTTPSPort(t *testing.T) {
	u := mustTestURL(t, "https://sso.cuit.edu.cn:443/authserver/login")
	if !isCASLoginURL(u) {
		t.Fatal("CAS login URL with :443 should be accepted")
	}
}

func mustTestURL(t *testing.T, raw string) *url.URL {
	t.Helper()
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	return u
}
