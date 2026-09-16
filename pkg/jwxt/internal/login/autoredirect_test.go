package login

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/go-resty/resty/v2"
)

func TestParseAutoRedirectReadsSchoolBridgePages(t *testing.T) {
	cases := []struct {
		name     string
		pageURL  string
		body     string
		want     string
		wantNone bool
	}{
		{
			name:    "cas entry bridge keeps portal route",
			pageURL: "https://ywtb.cuit.edu.cn/authserver/login?service=redacted",
			body:    `<a id="jump" href="/#/login?loginType=cas&redirectUrl=http%3A%2F%2Fywtb.cuit.edu.cn%2Fthird_api%2Fyypt%2Fauthcenter%2FdoAuth%2Fuuid-1"></a>`,
			want:    "http://ywtb.cuit.edu.cn/third_api/yypt/authcenter/doAuth/uuid-1",
		},
		{
			name:    "authenticated cas bridge hands out ticket",
			pageURL: "https://ywtb.cuit.edu.cn/cas/login?service=redacted",
			body:    `<title>认证成功！页面跳转中</title><a id="jump" href="http://ywtb.cuit.edu.cn/third_api/yypt/authcenter/doAuth/uuid-2?ticket=ST-1"></a>`,
			want:    "http://ywtb.cuit.edu.cn/third_api/yypt/authcenter/doAuth/uuid-2?ticket=ST-1",
		},
		{
			name:    "ticket consumer page uses script redirect",
			pageURL: "https://ywtb.cuit.edu.cn/third_api/yypt/authcenter/doAuth/uuid-3?ticket=ST-2",
			body:    "<html><head><script>window.location.href = 'https://ywtb.cuit.edu.cn/third_api/yypt/ic-web//auth/token?uuid=uuid-3';\r\n</script></head></html>",
			want:    "https://ywtb.cuit.edu.cn/third_api/yypt/ic-web//auth/token?uuid=uuid-3",
		},
		{
			name:    "location.replace is honoured",
			pageURL: "https://ywtb.cuit.edu.cn/cas/login",
			body:    `<script>location.replace("/third_api/yypt/ic-web//auth/token?uuid=uuid-4")</script>`,
			want:    "https://ywtb.cuit.edu.cn/third_api/yypt/ic-web//auth/token?uuid=uuid-4",
		},
		{
			name:     "external target is rejected",
			pageURL:  "https://ywtb.cuit.edu.cn/cas/login",
			body:     `<script>window.location.href = "https://evil.example.com/steal";</script>`,
			wantNone: true,
		},
		{
			name:     "large page is not treated as a bridge",
			pageURL:  "https://ywtb.cuit.edu.cn/cas/login",
			body:     "<html><body>" + strings.Repeat("x", 5000) + `<script>window.location.href = "https://ywtb.cuit.edu.cn/x";</script></body></html>`,
			wantNone: true,
		},
	}

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			baseURL, err := url.Parse(testCase.pageURL)
			if err != nil {
				t.Fatal(err)
			}
			next, ok := parseAutoRedirect(baseURL, []byte(testCase.body))
			if testCase.wantNone {
				if ok {
					t.Fatalf("expected no redirect, got %s", next)
				}
				return
			}
			if !ok {
				t.Fatal("expected a redirect target")
			}
			if next.String() != testCase.want {
				t.Fatalf("redirect = %s, want %s", next, testCase.want)
			}
		})
	}
}

func TestFollowPortalRedirectWalksBridgeAndTicketPages(t *testing.T) {
	requests := make([]string, 0, 4)
	tokenHits := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests = append(requests, r.URL.Path)
		switch r.URL.Path {
		case "/cas/login":
			w.Header().Set("Content-Type", "text/html;charset=utf-8")
			_, _ = w.Write([]byte(`<title>认证成功！页面跳转中</title><a id="jump" href="/doAuth/uuid-1?ticket=ST-1"></a>`))
		case "/doAuth/uuid-1":
			w.Header().Set("Content-Type", "text/html;UTF-8")
			_, _ = w.Write([]byte("<html><head><script>window.location.href = '/token?uuid=uuid-1&uniToken=jwt';</script></head></html>"))
		case "/token":
			tokenHits++
			http.SetCookie(w, &http.Cookie{Name: "ic-cookie", Value: "session"})
			_, _ = w.Write([]byte("library session ready"))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	entry, err := url.Parse(server.URL + "/cas/login?service=" + url.QueryEscape(server.URL+"/doAuth/uuid-1"))
	if err != nil {
		t.Fatal(err)
	}
	if err := followPortalRedirect(context.Background(), resty.New(), Config{MaxRedirects: 5}, entry); err != nil {
		t.Fatalf("followPortalRedirect returned error: %v", err)
	}
	if tokenHits != 1 {
		t.Fatalf("library token endpoint hits = %d, want 1 (requests: %v)", tokenHits, requests)
	}
}

func TestFollowPortalRedirectStopsOnCyclicScriptRedirects(t *testing.T) {
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		next := "/b"
		if strings.HasSuffix(r.URL.Path, "/b") {
			next = "/a"
		}
		_, _ = fmt.Fprintf(w, `<script>window.location.href = %q;</script>`, next)
	}))
	defer server.Close()

	entry, err := url.Parse(server.URL + "/a")
	if err != nil {
		t.Fatal(err)
	}
	if err := followPortalRedirect(context.Background(), resty.New(), Config{MaxRedirects: 5}, entry); err != nil {
		t.Fatalf("followPortalRedirect returned error: %v", err)
	}
	if requests > autoRedirectLimit+1 {
		t.Fatalf("cyclic redirects should be bounded, got %d requests", requests)
	}
}
