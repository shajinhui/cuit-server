package login

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/go-resty/resty/v2"
)

type portalSwitchTestServers struct {
	portal              *httptest.Server
	loginRedirect       *httptest.Server
	routeRedirect       *httptest.Server
	switchHits          *int
	loginRedirectHits   *int
	routeRedirectHits   *int
	portalBaseURL       *url.URL
	routeRedirectRawURL string
}

func TestParsePortalRouteExtractsLoginTypeAndRedirectURL(t *testing.T) {
	baseURL := mustTestURL(t, "https://sso.cuit.edu.cn:443/authserver/login?service=redacted")
	html := `
<html>
<head><title>页面跳转中</title></head>
<body>
  <a id="jump" href="/#/login?loginType=cas&redirectUrl=https%3A%2F%2Fsso.cuit.edu.cn%2Fauthserver%2Flogin%3Fservice%3Dredacted">jump</a>
</body>
</html>`

	route, err := ParsePortalRoute(baseURL, []byte(html))
	if err != nil {
		t.Fatalf("ParsePortalRoute returned error: %v", err)
	}
	if route.PageURL.Host != "sso.cuit.edu.cn:443" {
		t.Fatalf("unexpected route host: %s", route.PageURL.Host)
	}
	if route.LoginType != "cas" {
		t.Fatalf("unexpected login type: %s", route.LoginType)
	}
	if route.RedirectURL == "" {
		t.Fatal("redirect URL should be extracted")
	}
}

func TestParsePortalRouteSupportsRedirectURLNotLast(t *testing.T) {
	baseURL := mustTestURL(t, "https://sso.cuit.edu.cn/authserver/login")
	html := `
<html><body>
  <a id="jump" href="/#/login?loginType=cas&redirectUrl=https%3A%2F%2Fsso.cuit.edu.cn%2Fauthserver%2Flogin%3Fservice%3Dredacted&source=eams">jump</a>
</body></html>`

	route, err := ParsePortalRoute(baseURL, []byte(html))
	if err != nil {
		t.Fatalf("ParsePortalRoute returned error: %v", err)
	}
	if route.RedirectURL == "" {
		t.Fatal("redirect URL should not be empty")
	}
	if strings.Contains(route.RedirectURL, "source=eams") {
		t.Fatalf("redirect URL should stop before next query parameter: %q", route.RedirectURL)
	}
}

func TestParsePortalRouteSupportsHistoryMode(t *testing.T) {
	baseURL := mustTestURL(t, "https://sso.cuit.edu.cn/authserver/login")
	html := `
<html><body>
  <a id="jump" href="/login?loginType=cas&redirectUrl=https%3A%2F%2Fsso.cuit.edu.cn%2Fauthserver%2Flogin%3Fservice%3Dredacted">jump</a>
</body></html>`

	route, err := ParsePortalRoute(baseURL, []byte(html))
	if err != nil {
		t.Fatalf("ParsePortalRoute returned error: %v", err)
	}
	if route.PageURL.Path != "/login" {
		t.Fatalf("history route path not preserved: %s", route.PageURL.Path)
	}
	if route.LoginType != "cas" {
		t.Fatalf("unexpected login type: %s", route.LoginType)
	}
}

func TestFollowPortalRedirectContinuesFromCASBridge(t *testing.T) {
	callbackHits := 0
	callbackServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		callbackHits++
		_, _ = w.Write([]byte("eams ok"))
	}))
	defer callbackServer.Close()

	bridgeServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		href := "/#/login?loginType=cas&redirectUrl=" + url.QueryEscape(callbackServer.URL)
		_, _ = w.Write([]byte(`<html><body><a id="jump" href="` + href + `"></a></body></html>`))
	}))
	defer bridgeServer.Close()

	err := followPortalRedirect(context.Background(), resty.New(), Config{MaxRedirects: 5}, mustTestURL(t, bridgeServer.URL+"/cas/login"))
	if err != nil {
		t.Fatalf("followPortalRedirect returned error: %v", err)
	}
	if callbackHits != 1 {
		t.Fatalf("callback should be followed once, got %d", callbackHits)
	}
}

func TestFollowPortalRedirectSupportsDirectBridgeJump(t *testing.T) {
	callbackHits := 0
	callbackServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		callbackHits++
		_, _ = w.Write([]byte("eams ok"))
	}))
	defer callbackServer.Close()

	bridgeServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`<html><body><a id="jump" href="` + callbackServer.URL + `"></a></body></html>`))
	}))
	defer bridgeServer.Close()

	err := followPortalRedirect(context.Background(), resty.New(), Config{MaxRedirects: 5}, mustTestURL(t, bridgeServer.URL+"/cas/login"))
	if err != nil {
		t.Fatalf("followPortalRedirect returned error: %v", err)
	}
	if callbackHits != 1 {
		t.Fatalf("direct callback should be followed once, got %d", callbackHits)
	}
}

func TestLoginViaPortalSwitchesSchoolAccountAndFollowsLoginRedirect(t *testing.T) {
	servers := newPortalSwitchTestServers(t)
	defer servers.close()

	err := loginViaPortal(context.Background(), resty.New(), Config{
		PortalBaseURL: servers.portalBaseURL,
		MaxRedirects:  5,
	}, &PortalRoute{
		PageURL:     mustTestURL(t, "https://sso.cuit.edu.cn/"),
		LoginType:   "cas",
		RedirectURL: servers.routeRedirectRawURL + "/cas",
	}, "student-id", "password")
	if err != nil {
		t.Fatalf("loginViaPortal returned error: %v", err)
	}
	if *servers.switchHits != 1 {
		t.Fatalf("school account should be switched once, got %d", *servers.switchHits)
	}
	if *servers.loginRedirectHits != 1 {
		t.Fatalf("login redirect URI should be followed once, got %d", *servers.loginRedirectHits)
	}
	if *servers.routeRedirectHits != 0 {
		t.Fatalf("route redirect URL should be fallback only, got %d hits", *servers.routeRedirectHits)
	}
}

func TestLoginViaPortalUsesSwitchRedirectWhenLoginHasNoRedirect(t *testing.T) {
	switchRedirectHits := 0
	switchRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		switchRedirectHits++
		_, _ = w.Write([]byte("eams ok"))
	}))
	defer switchRedirectServer.Close()

	routeRedirectHits := 0
	routeRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		routeRedirectHits++
		_, _ = w.Write([]byte("old route redirect"))
	}))
	defer routeRedirectServer.Close()

	portalServer := newSwitchRedirectPortalServer(t, switchRedirectServer.URL)
	defer portalServer.Close()
	portalURL, err := url.Parse(portalServer.URL)
	if err != nil {
		t.Fatal(err)
	}

	err = loginViaPortal(context.Background(), resty.New(), Config{
		PortalBaseURL: portalURL,
		MaxRedirects:  5,
	}, &PortalRoute{
		PageURL:     mustTestURL(t, "https://sso.cuit.edu.cn/"),
		LoginType:   "cas",
		RedirectURL: routeRedirectServer.URL + "/cas",
	}, "student-id", "password")
	if err != nil {
		t.Fatalf("loginViaPortal returned error: %v", err)
	}
	if switchRedirectHits != 1 {
		t.Fatalf("switch redirect URI should be followed once, got %d", switchRedirectHits)
	}
	if routeRedirectHits != 0 {
		t.Fatalf("route redirect URL should be fallback only, got %d hits", routeRedirectHits)
	}
}

func TestLoginViaPortalIgnoresLoginRedirectWhenCodeIsZero(t *testing.T) {
	wrongRedirectHits := 0
	wrongRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		wrongRedirectHits++
		_, _ = w.Write([]byte("wrong redirect"))
	}))
	defer wrongRedirectServer.Close()

	routeRedirectHits := 0
	routeRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		routeRedirectHits++
		_, _ = w.Write([]byte("eams ok"))
	}))
	defer routeRedirectServer.Close()

	portalServer := newCodeZeroRedirectPortalServer(t, wrongRedirectServer.URL)
	defer portalServer.Close()
	portalURL, err := url.Parse(portalServer.URL)
	if err != nil {
		t.Fatal(err)
	}

	err = loginViaPortal(context.Background(), resty.New(), Config{
		PortalBaseURL: portalURL,
		MaxRedirects:  5,
	}, &PortalRoute{
		PageURL:     mustTestURL(t, "https://sso.cuit.edu.cn/"),
		LoginType:   "cas",
		RedirectURL: routeRedirectServer.URL + "/cas",
	}, "student-id", "password")
	if err != nil {
		t.Fatalf("loginViaPortal returned error: %v", err)
	}
	if wrongRedirectHits != 0 {
		t.Fatalf("code=0 login redirect should be ignored, got %d hits", wrongRedirectHits)
	}
	if routeRedirectHits != 1 {
		t.Fatalf("route redirect URL should be used once, got %d", routeRedirectHits)
	}
}

func newPortalSwitchTestServers(t *testing.T) portalSwitchTestServers {
	t.Helper()
	loginRedirectHits := 0
	loginRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		loginRedirectHits++
		_, _ = w.Write([]byte("eams ok"))
	}))

	routeRedirectHits := 0
	routeRedirectServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		routeRedirectHits++
		_, _ = w.Write([]byte("old route redirect"))
	}))

	switchHits := 0
	portalServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/base/login":
			_, _ = w.Write([]byte(`{"code":302,"redirect_uri":"` + loginRedirectServer.URL + `/cas"}`))
		case "/api/user/ref/list":
			_, _ = w.Write([]byte(`[{"id":123,"dataType":0}]`))
		case "/api/user/switch":
			switchHits++
			if r.URL.Query().Get("id") != "123" || r.URL.Query().Get("main") != "true" {
				t.Fatalf("unexpected switch query: %s", r.URL.RawQuery)
			}
			_, _ = w.Write([]byte(`{"code":0,"data":{"ok":true}}`))
		default:
			http.NotFound(w, r)
		}
	}))

	portalURL, err := url.Parse(portalServer.URL)
	if err != nil {
		t.Fatal(err)
	}
	return portalSwitchTestServers{
		portal:              portalServer,
		loginRedirect:       loginRedirectServer,
		routeRedirect:       routeRedirectServer,
		switchHits:          &switchHits,
		loginRedirectHits:   &loginRedirectHits,
		routeRedirectHits:   &routeRedirectHits,
		portalBaseURL:       portalURL,
		routeRedirectRawURL: routeRedirectServer.URL,
	}
}

func newCodeZeroRedirectPortalServer(t *testing.T, wrongRedirectBase string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/base/login":
			_, _ = w.Write([]byte(`{"code":0,"redirect_uri":"` + wrongRedirectBase + `/wrong"}`))
		case "/api/user/ref/list":
			_, _ = w.Write([]byte(`[{"id":123,"dataType":0}]`))
		case "/api/user/switch":
			_, _ = w.Write([]byte(`{"code":0}`))
		default:
			http.NotFound(w, r)
		}
	}))
}

func newSwitchRedirectPortalServer(t *testing.T, redirectBase string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/base/login":
			_, _ = w.Write([]byte(`{"code":0}`))
		case "/api/user/ref/list":
			_, _ = w.Write([]byte(`[{"id":"school-account","dataType":0}]`))
		case "/api/user/switch":
			if r.URL.Query().Get("id") != "school-account" {
				t.Fatalf("unexpected switch id: %s", r.URL.Query().Get("id"))
			}
			_, _ = w.Write([]byte(`{"code":302,"redirect_uri":"` + redirectBase + `/cas"}`))
		default:
			http.NotFound(w, r)
		}
	}))
}

func (s portalSwitchTestServers) close() {
	s.portal.Close()
	s.loginRedirect.Close()
	s.routeRedirect.Close()
}
