package login

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/go-resty/resty/v2"
)

func TestRedirectCandidatesFollowBrowserOrderAndDedupe(t *testing.T) {
	route := &PortalRoute{RedirectURL: "https://ywtb.cuit.edu.cn/doAuth/1"}
	result := portalLoginResponse{Code: http.StatusFound, RedirectURI: "https://ywtb.cuit.edu.cn/authserver/login?service=x"}

	candidates := redirectCandidates(route, result, "https://ywtb.cuit.edu.cn/switch")
	want := []string{
		"https://ywtb.cuit.edu.cn/switch",
		"https://ywtb.cuit.edu.cn/authserver/login?service=x",
		"https://ywtb.cuit.edu.cn/doAuth/1",
	}
	if len(candidates) != len(want) {
		t.Fatalf("unexpected candidates: %v", candidates)
	}
	for index := range want {
		if candidates[index] != want[index] {
			t.Fatalf("candidate %d = %s, want %s", index, candidates[index], want[index])
		}
	}

	duplicated := redirectCandidates(&PortalRoute{RedirectURL: "https://ywtb.cuit.edu.cn/doAuth/1"}, portalLoginResponse{Code: 0}, "https://ywtb.cuit.edu.cn/doAuth/1")
	if len(duplicated) != 1 {
		t.Fatalf("duplicate candidates should collapse: %v", duplicated)
	}
}

func TestLoginTargetVerifierTriesNextCandidateWhenSessionIsNotReady(t *testing.T) {
	switchRedirectHits := 0
	switchRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		switchRedirectHits++
		_, _ = w.Write([]byte("still on login page"))
	}))
	defer switchRedirectServer.Close()

	routeRedirectHits := 0
	routeRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		routeRedirectHits++
		_, _ = w.Write([]byte("library session established"))
	}))
	defer routeRedirectServer.Close()

	portalServer := newSwitchRedirectPortalServer(t, switchRedirectServer.URL)
	defer portalServer.Close()
	portalURL, err := url.Parse(portalServer.URL)
	if err != nil {
		t.Fatal(err)
	}

	verifyCalls := 0
	err = loginTargetViaPortal(context.Background(), resty.New(), Config{
		PortalBaseURL: portalURL,
		MaxRedirects:  5,
	}, &PortalRoute{
		PageURL:     mustTestURL(t, "https://ywtb.cuit.edu.cn/"),
		LoginType:   "cas",
		RedirectURL: routeRedirectServer.URL + "/doAuth",
	}, "student-id", "password", func(context.Context) error {
		verifyCalls++
		if verifyCalls == 1 {
			return errors.New("session not ready")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("loginTargetViaPortal returned error: %v", err)
	}
	if switchRedirectHits != 1 || routeRedirectHits != 1 {
		t.Fatalf("unexpected hits: switch=%d route=%d", switchRedirectHits, routeRedirectHits)
	}
	if verifyCalls != 2 {
		t.Fatalf("verifier should be called per candidate, got %d", verifyCalls)
	}
}

func TestLoginTargetVerifierReportsLastFailure(t *testing.T) {
	routeRedirectHits := 0
	routeRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		routeRedirectHits++
		_, _ = w.Write([]byte("not ready"))
	}))
	defer routeRedirectServer.Close()

	portalServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/base/login":
			_, _ = w.Write([]byte(`{"code":0}`))
		case "/api/user/ref/list":
			_, _ = w.Write([]byte(`[{"id":"school-account","dataType":0}]`))
		case "/api/user/switch":
			_, _ = w.Write([]byte(`{"code":0}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer portalServer.Close()
	portalURL, err := url.Parse(portalServer.URL)
	if err != nil {
		t.Fatal(err)
	}

	err = loginTargetViaPortal(context.Background(), resty.New(), Config{
		PortalBaseURL: portalURL,
		MaxRedirects:  5,
	}, &PortalRoute{
		PageURL:     mustTestURL(t, "https://ywtb.cuit.edu.cn/"),
		LoginType:   "cas",
		RedirectURL: routeRedirectServer.URL + "/doAuth",
	}, "student-id", "password", func(context.Context) error {
		return errors.New("library login incomplete")
	})
	if err == nil || !strings.Contains(err.Error(), "library login incomplete") {
		t.Fatalf("unexpected error: %v", err)
	}
	if routeRedirectHits != 1 {
		t.Fatalf("route redirect should be tried once, got %d", routeRedirectHits)
	}
}
