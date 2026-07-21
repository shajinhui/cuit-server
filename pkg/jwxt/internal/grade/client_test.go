package grade

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/go-resty/resty/v2"
)

func TestSemesterAndGradeRequestsMatchEAMSProtocol(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case semesterPagePath:
			if r.Method != http.MethodGet {
				t.Fatalf("unexpected semester page method: %s", r.Method)
			}
			_, _ = w.Write([]byte(`<input id="semesterBar42Semester" class="calendar-text" title="学年学期" />
<script>bg.Go('/eams/teach/grade/course/person!search.action?semesterId=1006&projectType=','semesterGrade');</script>`))
		case semesterDataPath:
			assertSemesterForm(t, r)
			_, _ = w.Write([]byte(`{semesters:{y0:[{id:906,schoolYear:"2025-2026",name:"1"},{id:1006,schoolYear:"2025-2026",name:"2"}]}}`))
		case gradeSearchPath:
			assertGradeQuery(t, r)
			_, _ = w.Write([]byte(sampleGradeHTML))
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

	semesters, err := ListSemesters(context.Background(), client, baseURL)
	if err != nil {
		t.Fatalf("ListSemesters returned error: %v", err)
	}
	if len(semesters) != 2 {
		t.Fatalf("unexpected semester count: %d", len(semesters))
	}

	grades, err := GetGrades(context.Background(), client, baseURL, "906")
	if err != nil {
		t.Fatalf("GetGrades returned error: %v", err)
	}
	if len(grades) != 2 {
		t.Fatalf("unexpected grade count: %d", len(grades))
	}
}

func assertSemesterForm(t *testing.T, r *http.Request) {
	t.Helper()
	if r.Method != http.MethodPost {
		t.Fatalf("unexpected semester data method: %s", r.Method)
	}
	if r.Header.Get("Origin") == "" || r.Header.Get("Referer") == "" {
		t.Fatal("semester data request is missing origin or referer")
	}
	if r.Header.Get("Content-Type") != "application/x-www-form-urlencoded; charset=UTF-8" {
		t.Fatalf("unexpected content type: %q", r.Header.Get("Content-Type"))
	}
	if err := r.ParseForm(); err != nil {
		t.Fatal(err)
	}
	expected := map[string]string{
		"tagId":    "semesterBar42Semester",
		"dataType": "semesterCalendar",
		"value":    "1006",
		"empty":    "false",
	}
	for key, value := range expected {
		if r.Form.Get(key) != value {
			t.Fatalf("unexpected %s: %q", key, r.Form.Get(key))
		}
	}
}

func assertGradeQuery(t *testing.T, r *http.Request) {
	t.Helper()
	if r.Method != http.MethodGet {
		t.Fatalf("unexpected grade method: %s", r.Method)
	}
	if r.URL.Query().Get("semesterId") != "906" {
		t.Fatalf("unexpected semesterId: %q", r.URL.Query().Get("semesterId"))
	}
	if _, ok := r.URL.Query()["projectType"]; !ok {
		t.Fatal("projectType query parameter is missing")
	}
	if r.URL.Query().Get("_") == "" {
		t.Fatal("cache-busting query parameter is missing")
	}
	if r.Header.Get("X-Requested-With") != "XMLHttpRequest" {
		t.Fatalf("unexpected X-Requested-With: %q", r.Header.Get("X-Requested-With"))
	}
}
