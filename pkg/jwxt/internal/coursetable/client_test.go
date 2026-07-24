package coursetable

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

func TestGetCourseTableMatchesEAMSProtocol(t *testing.T) {
	courseRequests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case entryPath:
			assertEntryRequest(t, r)
			semesterCookie, err := r.Cookie("semester.id")
			if err != nil || semesterCookie.Value != "1106" {
				t.Fatalf("entry request must carry target semester cookie: cookie=%v err=%v", semesterCookie, err)
			}
			_, _ = w.Write([]byte(strings.ReplaceAll(sampleEntryHTML, "1006", "1106")))
		case projectDataPath:
			handleDataQuery(t, w, r, "1106")
		case courseTablePath:
			courseRequests++
			assertCourseTableRequest(t, r, "1106", "", entryPath)
			_, _ = w.Write([]byte(sampleCourseTableHTML))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	table, err := GetCourseTable(context.Background(), newTestClient(t), baseURL, "1106")
	if err != nil {
		t.Fatalf("GetCourseTable returned error: %v", err)
	}
	if table.SemesterID != "1106" || len(table.Courses) != 2 {
		t.Fatalf("unexpected course table: %+v", table)
	}
	if courseRequests != 1 {
		t.Fatalf("unexpected course table request count: %d", courseRequests)
	}
}

func assertEntryRequest(t *testing.T, r *http.Request) {
	t.Helper()
	if r.Method != http.MethodGet {
		t.Fatalf("unexpected entry method: %s", r.Method)
	}
	if r.Header.Get("X-Requested-With") != "XMLHttpRequest" {
		t.Fatalf("unexpected X-Requested-With: %q", r.Header.Get("X-Requested-With"))
	}
}

func handleDataQuery(t *testing.T, w http.ResponseWriter, r *http.Request, semesterID string) {
	t.Helper()
	assertFormHeaders(t, r)
	if !strings.HasSuffix(r.Referer(), "/eams/home.action") {
		t.Fatalf("unexpected data query referer: %q", r.Referer())
	}
	rawBody, err := io.ReadAll(r.Body)
	if err != nil {
		t.Fatal(err)
	}
	r.Body = io.NopCloser(bytes.NewReader(rawBody))
	if err := r.ParseForm(); err != nil {
		t.Fatal(err)
	}
	switch string(rawBody) {
	case "tagId=semesterBar123Semester&dataType=semesterCalendar&value=" + semesterID + "&empty=false":
		if r.Header.Get("Accept") != "text/plain, */*; q=0.01" {
			t.Fatalf("unexpected calendar Accept: %q", r.Header.Get("Accept"))
		}
		_, _ = w.Write([]byte(`{semesterId:"` + semesterID + `"}`))
	case "dataType=projectId":
		if r.Header.Get("Accept") != "*/*" {
			t.Fatalf("unexpected project Accept: %q", r.Header.Get("Accept"))
		}
		_, _ = w.Write([]byte("1"))
	case "entityId=":
		if r.Header.Get("Accept") != "text/plain, */*; q=0.01" {
			t.Fatalf("unexpected project options Accept: %q", r.Header.Get("Accept"))
		}
		_, _ = w.Write([]byte(`<option value="1" selected>本科</option>`))
	default:
		t.Fatalf("unexpected data query request: %q", rawBody)
	}
}

func assertCourseTableRequest(t *testing.T, r *http.Request, semesterID string, projectID string, refererPath string) {
	t.Helper()
	assertFormHeaders(t, r)
	if r.RequestURI != courseTablePath {
		t.Fatalf("course table path must keep literal !: %q", r.RequestURI)
	}
	if !strings.HasSuffix(r.Referer(), refererPath) {
		t.Fatalf("unexpected course table referer: %q", r.Referer())
	}
	rawBody, err := io.ReadAll(r.Body)
	if err != nil {
		t.Fatal(err)
	}
	r.Body = io.NopCloser(bytes.NewReader(rawBody))
	expectedBody := "ignoreHead=1&setting.kind=std&startWeek="
	if projectID != "" {
		expectedBody += "&project.id=" + projectID
	}
	expectedBody += "&semester.id=" + semesterID + "&ids=12345"
	if string(rawBody) != expectedBody {
		t.Fatalf("unexpected raw form: %q", rawBody)
	}
	semesterCookie, err := r.Cookie("semester.id")
	if err != nil || semesterCookie.Value != "1106" {
		t.Fatalf("course table request must carry target semester cookie: cookie=%v err=%v", semesterCookie, err)
	}
	if err := r.ParseForm(); err != nil {
		t.Fatal(err)
	}
	expected := map[string]string{
		"ignoreHead":   "1",
		"setting.kind": "std",
		"startWeek":    "",
		"semester.id":  semesterID,
		"ids":          "12345",
	}
	if projectID != "" {
		expected["project.id"] = projectID
	} else if r.Form.Has("project.id") {
		t.Fatalf("initial request must not contain project.id: %#v", r.Form)
	}
	for key, value := range expected {
		if r.Form.Get(key) != value {
			t.Fatalf("unexpected %s: %q", key, r.Form.Get(key))
		}
	}
}

func assertFormHeaders(t *testing.T, r *http.Request) {
	t.Helper()
	if r.Method != http.MethodPost {
		t.Fatalf("unexpected method: %s", r.Method)
	}
	if r.Header.Get("Content-Type") != "application/x-www-form-urlencoded; charset=UTF-8" {
		t.Fatalf("unexpected content type: %q", r.Header.Get("Content-Type"))
	}
	if r.Header.Get("Origin") == "" || r.Header.Get("Referer") == "" {
		t.Fatal("request is missing origin or referer")
	}
	if r.Header.Get("X-Requested-With") != "XMLHttpRequest" {
		t.Fatalf("unexpected X-Requested-With: %q", r.Header.Get("X-Requested-With"))
	}
	if r.Header.Get("Priority") != "" {
		t.Fatalf("unexpected Priority: %q", r.Header.Get("Priority"))
	}
}

func TestGetCourseTableIncludesRemoteErrorBody(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case entryPath:
			_, _ = w.Write([]byte(sampleEntryHTML))
		case projectDataPath:
			handleDataQuery(t, w, r, "1006")
		case courseTablePath:
			if err := r.ParseForm(); err != nil {
				t.Fatal(err)
			}
			if r.Form.Get("semester.id") == "1006" {
				_, _ = w.Write([]byte(sampleCourseTableHTML))
				return
			}
			w.Header().Set("Content-Type", "text/html;charset=UTF-8")
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(`<html><body><script>ignored()</script><h1>课表参数错误</h1></body></html>`))
		}
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	_, err = GetCourseTable(context.Background(), newTestClient(t), baseURL, "1106")
	if !errors.Is(err, jwxterr.ErrCourseTableQueryFailed) || !strings.Contains(err.Error(), `<h1>课表参数错误</h1>`) {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(err.Error(), "ignored()") || !strings.Contains(err.Error(), "<html>") {
		t.Fatalf("error does not contain original response body: %v", err)
	}
	if !strings.Contains(err.Error(), "request_debug:") || !strings.Contains(err.Error(), `semester_cookie_matches_form=true`) {
		t.Fatalf("error does not contain request diagnostics: %v", err)
	}
}

const sampleEntryHTML = `<script>
if(jQuery("#courseTableType").val()=="std"){
  bg.form.addInput(form,"ids","12345");
}
jQuery("#semesterBar123Semester").semesterCalendar({empty:"false",onChange:"",value:"1006"},"searchTable()");
</script>`

func newTestClient(t *testing.T) *resty.Client {
	t.Helper()
	jar, err := cookiejar.New(nil)
	if err != nil {
		t.Fatal(err)
	}
	return resty.New().SetCookieJar(jar)
}
