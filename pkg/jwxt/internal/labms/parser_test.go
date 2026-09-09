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
	if table.Courses[0].Name != "示例课程1" || table.Courses[1].Name != "实验 示例课程2" {
		t.Fatalf("unexpected display names: %+v", table.Courses)
	}
	if experiment.Weekday != 3 || experiment.StartSection != 10 || experiment.EndSection != 12 {
		t.Fatalf("unexpected experiment sections: %+v", experiment)
	}
	if experiment.StartTime != "18:30" || experiment.EndTime != "21:30" || experiment.ActivityType != "实验" {
		t.Fatalf("precise LABMS fields were not preserved: %+v", experiment)
	}
}

func TestLABMSDisplayFieldsStayCompactAndSeparateExperiments(t *testing.T) {
	items := []ScheduleItem{
		{
			CourseID:    "same-course",
			CourseNo:    "COURSE001",
			CourseName:  "【理论】 网络空间安全智能决策",
			ProjectType: "理论",
			Location:    "航空港＞航空港第一教学楼＞H6407",
			Weekday:     1,
			Sections:    []int{1, 2},
			Weeks:       []int{1, 2},
		},
		{
			CourseID:    "same-course",
			CourseNo:    "COURSE001",
			CourseName:  "网络空间安全智能决策实验",
			ProjectType: "实验",
			Location:    "数值分析与算法实验室-H6407",
			Weekday:     3,
			Sections:    []int{10, 11},
			Weeks:       []int{1, 2},
		},
	}

	table, err := ToCourseTable(items, "1106")
	if err != nil {
		t.Fatal(err)
	}
	if len(table.Courses) != 2 {
		t.Fatalf("regular and experimental activities were merged: %+v", table.Courses)
	}
	if table.Courses[0].Name != "网络空间安全智能决策" || table.Courses[0].Activities[0].RoomName != "H6407" {
		t.Fatalf("regular display fields were not cleaned: %+v", table.Courses[0])
	}
	if table.Courses[1].Name != "实验 网络空间安全智能决策" || table.Courses[1].Activities[0].RoomName != "H6407" {
		t.Fatalf("experiment display fields were not cleaned: %+v", table.Courses[1])
	}
}

func TestLABMSDisplayCleaningPreservesCourseWordsAndShortVenues(t *testing.T) {
	if got := displayCourseName("数据安全理论与实践", "理论"); got != "数据安全理论与实践" {
		t.Fatalf("course word was removed: %q", got)
	}
	if got := displayCourseName("理论力学", "理论"); got != "理论力学" {
		t.Fatalf("legitimate leading word was removed: %q", got)
	}
	if got := displayCourseName("实验心理学", "实验"); got != "实验心理学" {
		t.Fatalf("experiment marker was duplicated: %q", got)
	}
	if got := displayLocation("第二篮球场1"); got != "第二篮球场1" {
		t.Fatalf("short venue changed: %q", got)
	}
	if got := displayLocation("航空港>航空港第二篮球场>第二篮球场1"); got != "第二篮球场1" {
		t.Fatalf("venue hierarchy was not cleaned: %q", got)
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
