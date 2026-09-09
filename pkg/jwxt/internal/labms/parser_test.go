package labms

import (
	"encoding/json"
	"net/url"
	"os"
	"testing"
)

func TestSanitizedLABMSFixtureMapsPreciseSchedule(t *testing.T) {
	// 样本来自 2026-09 的真实成功响应，只替换了课程、教师、班级、地点和内部 ID。
	body, err := os.ReadFile("testdata/schedule.json")
	if err != nil {
		t.Fatal(err)
	}
	var response envelope
	if err := json.Unmarshal(body, &response); err != nil {
		t.Fatal(err)
	}
	if err := response.check("fixture"); err != nil {
		t.Fatal(err)
	}
	items, err := decodeScheduleItems(response.Data)
	if err != nil {
		t.Fatal(err)
	}
	table, err := ToCourseTable(items, "1106")
	if err != nil {
		t.Fatal(err)
	}
	if table.SemesterID != "1106" || table.WeekCount != 16 || table.SectionsPerDay != 12 {
		t.Fatalf("unexpected table metadata: %+v", table)
	}
	if len(table.Courses) != 2 || len(table.Courses[1].Activities) != 1 {
		t.Fatalf("real response items were not mapped: %+v", table.Courses)
	}
	experiment := table.Courses[1].Activities[0]
	if experiment.Weekday != 3 || experiment.StartSection != 10 || experiment.EndSection != 12 {
		t.Fatalf("unexpected experiment sections: %+v", experiment)
	}
	if experiment.StartTime != "18:30" || experiment.EndTime != "21:30" || experiment.ActivityType != "实验" {
		t.Fatalf("precise LABMS fields were not preserved: %+v", experiment)
	}
}

func TestSemesterNameMatchesLABMSLabel(t *testing.T) {
	name, err := SemesterName("2026-2027", "1")
	if err != nil || name != "2026-2027学年第一学期" {
		t.Fatalf("unexpected semester name: name=%q err=%v", name, err)
	}
}

func TestLoginURLKeepsCourseRouteAsFragment(t *testing.T) {
	baseURL, err := url.Parse("https://sjjx.example.edu:56443/")
	if err != nil {
		t.Fatal(err)
	}
	loginURL := LoginURL(baseURL)
	redirectURL, err := url.Parse(loginURL.Query().Get("redirect_url"))
	if err != nil {
		t.Fatal(err)
	}
	if loginURL.Path != loginDirectionPath || redirectURL.Path != "/labms/" || redirectURL.Fragment != "/course/my?lang=zh-CN" {
		t.Fatalf("unexpected LABMS login URL: login_path=%q redirect_path=%q fragment=%q", loginURL.Path, redirectURL.Path, redirectURL.Fragment)
	}
}
