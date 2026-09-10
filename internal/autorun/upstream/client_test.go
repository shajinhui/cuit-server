package upstream

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestGenerateSignMatchesTypeScriptVectors(t *testing.T) {
	if got := MD5Hex(""); got != "d41d8cd98f00b204e9800998ecf8427e" {
		t.Fatalf("empty MD5 = %q", got)
	}
	if got := MD5Hex("abc"); got != "900150983cd24fb0d6963f7d28e17f72" {
		t.Fatalf("abc MD5 = %q", got)
	}
	if got := GenerateSign(map[string]string{"b": "2", "a": "1", "empty": ""}, `{"x":1}`, "test-key", "test-secret"); got != "99B0BC5B9FED7E26B027C5BDA055F0BD" {
		t.Fatalf("normal signature = %q", got)
	}
	if got := GenerateSign(map[string]string{"b": "2", "a": "1"}, "a b/", "test-key", "test-secret"); got != "B3195656779E8A53F778082EB014CFFBencodeutf8" {
		t.Fatalf("sanitized signature = %q", got)
	}
}

func TestClientUsesEndpointHeadersAndOrderedQuery(t *testing.T) {
	var (
		mu       sync.Mutex
		requests []*http.Request
		bodies   [][]byte
	)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Errorf("read body: %v", err)
			return
		}
		mu.Lock()
		requests = append(requests, r.Clone(r.Context()))
		bodies = append(bodies, body)
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/v1/auth/login/password":
			_, _ = io.WriteString(w, `{"code":10000,"msg":"ok","response":{"userId":11,"studentId":22,"schoolId":33,"oauthToken":{"token":"upstream-token"}}}`)
		case "/v1/clubactivity/queryActivityList":
			_, _ = io.WriteString(w, `{"code":"1000","message":"ok","response":{"records":[{"clubActivityId":"9","activityName":"morning","optionStatus":1}]}}`)
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	client := NewClient(Options{AppKey: "test-key", AppSecret: "test-secret", BaseURL: server.URL})
	login, err := client.Login(context.Background(), "13900000000", "test-password", "1.8.5", "Xiaomi", "", "1", "Mi 11", "Android 11")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	if login.Token != "upstream-token" || login.StudentID != 22 {
		t.Fatalf("login = %+v", login)
	}
	activities, err := client.GetClubActivities(context.Background(), login.Token, login.StudentID, "2026-09-07", login.SchoolID)
	if err != nil {
		t.Fatalf("activities: %v", err)
	}
	if len(activities) != 1 || activities[0].ClubActivityID != 9 || activities[0].OptionStatus != "1" {
		t.Fatalf("activities = %+v", activities)
	}

	mu.Lock()
	defer mu.Unlock()
	if len(requests) != 2 {
		t.Fatalf("request count = %d", len(requests))
	}
	loginRequest := requests[0]
	if loginRequest.URL.Path != "/v1/auth/login/password" {
		t.Fatalf("login path = %s", loginRequest.URL.Path)
	}
	if got := loginRequest.Header.Get("appkey"); got != "test-key" {
		t.Fatalf("appkey = %q", got)
	}
	if got := loginRequest.Header.Get("token"); got != "" {
		t.Fatalf("login token header = %q", got)
	}
	if got := loginRequest.Header.Get("User-Agent"); got != UserAgent {
		t.Fatalf("user agent = %q", got)
	}
	if got := loginRequest.Header.Get("Content-Type"); got != "application/json; charset=UTF-8" {
		t.Fatalf("content type = %q", got)
	}
	if !strings.Contains(string(bodies[0]), `"password":"`) || strings.Contains(string(bodies[0]), "test-password") {
		t.Fatalf("login body did not contain only the protocol password digest")
	}

	activityRequest := requests[1]
	if got := activityRequest.URL.RequestURI(); got != "/v1/clubactivity/queryActivityList?queryTime=2026-09-07&studentId=22&schoolId=33&pageNo=1&pageSize=15" {
		t.Fatalf("activity URI = %s", got)
	}
	if got := activityRequest.Header.Get("token"); got != "upstream-token" {
		t.Fatalf("activity token header = %q", got)
	}
	wantSign := GenerateSign(map[string]string{
		"queryTime": "2026-09-07",
		"studentId": "22",
		"schoolId":  "33",
		"pageNo":    "1",
		"pageSize":  "15",
	}, "", "test-key", "test-secret")
	if got := activityRequest.Header.Get("sign"); got != wantSign {
		t.Fatalf("activity sign = %q, want %q", got, wantSign)
	}
}

func TestClientAcceptsMutationNullOrMissingResponseAndStringClubCode(t *testing.T) {
	var calls int
	transport := roundTripFunc(func(r *http.Request) (*http.Response, error) {
		calls++
		body := `{"code":10000,"msg":"ok","response":null}`
		if calls == 2 {
			body = `{"code":"1000","message":"ok"}`
		}
		return jsonResponse(r, body), nil
	})
	client := NewClient(Options{AppKey: "test-key", AppSecret: "test-secret", Transport: transport})

	if _, err := client.SignInOrSignBack(context.Background(), "token", SignRequestBody{ActivityID: 8, Latitude: "30.1", Longitude: "104.1", SignType: "1", StudentID: 2}); err != nil {
		t.Fatalf("sign response:null: %v", err)
	}
	if _, err := client.JoinClubActivity(context.Background(), "token", 2, 8); err != nil {
		t.Fatalf("join omitted response: %v", err)
	}
	if calls != 2 {
		t.Fatalf("calls = %d, want 2", calls)
	}
}

func TestClientMarksAuthEnvelopeErrorsAsExpired(t *testing.T) {
	for _, body := range []string{
		`{"code":30005,"msg":"expired","response":null}`,
		`{"code":10001,"msg":"not_login","response":null}`,
		`{"error":"unauthorized"}`,
	} {
		client := NewClient(Options{
			AppKey:    "test-key",
			AppSecret: "test-secret",
			Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
				return jsonResponse(r, body), nil
			}),
		})
		_, err := client.GetRunStandard(context.Background(), "stale-token", 33)
		if err == nil || !IsTokenExpired(err) {
			t.Fatalf("body %s: err=%v, expired=%v", body, err, IsTokenExpired(err))
		}
	}
}

func TestMutationIsSentOnlyOnceWhenOutcomeIsUnknown(t *testing.T) {
	var calls int
	client := NewClient(Options{
		AppKey:    "test-key",
		AppSecret: "test-secret",
		Transport: roundTripFunc(func(_ *http.Request) (*http.Response, error) {
			calls++
			return nil, errors.New("connection closed after write")
		}),
		Timeout: 100 * time.Millisecond,
	})
	_, err := client.SignInOrSignBack(context.Background(), "token", SignRequestBody{ActivityID: 8, Latitude: "30.1", Longitude: "104.1", SignType: "1", StudentID: 2})
	if err == nil || !strings.Contains(err.Error(), "签到/签退失败：上游网络请求失败") {
		t.Fatalf("error = %v", err)
	}
	if calls != 1 {
		t.Fatalf("mutation calls = %d, want 1", calls)
	}
}

func TestClientHonorsContextTimeout(t *testing.T) {
	client := NewClient(Options{
		AppKey:    "test-key",
		AppSecret: "test-secret",
		Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
			<-r.Context().Done()
			return nil, r.Context().Err()
		}),
		Timeout: 10 * time.Millisecond,
	})
	_, err := client.GetRunStandard(context.Background(), "token", 33)
	if err == nil || !strings.Contains(err.Error(), "上游请求超时") {
		t.Fatalf("timeout error = %v", err)
	}
	if IsTokenExpired(err) {
		t.Fatalf("transient timeout must not be classified as token expiry")
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func jsonResponse(request *http.Request, body string) *http.Response {
	return &http.Response{
		StatusCode: http.StatusOK,
		Status:     "200 OK",
		Body:       io.NopCloser(strings.NewReader(body)),
		Header:     make(http.Header),
		Request:    request,
	}
}
