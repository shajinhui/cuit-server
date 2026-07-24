package grade

import (
	"strings"
	"testing"
)

func TestParseSemesterPage(t *testing.T) {
	body := []byte(`
<input id="semesterBar13572391471Semester" class="calendar-text" title="学年学期" />
<script>bg.Go('/eams/teach/grade/course/person!search.action?semesterId=906&projectType=','semesterGrade');</script>`)

	tagID, semesterID, err := ParseSemesterPage(body)
	if err != nil {
		t.Fatalf("ParseSemesterPage returned error: %v", err)
	}
	if tagID != "semesterBar13572391471Semester" {
		t.Fatalf("unexpected tag ID: %s", tagID)
	}
	if semesterID != "906" {
		t.Fatalf("unexpected semester ID: %s", semesterID)
	}
}

func TestParseSemesters(t *testing.T) {
	body := []byte(`{semesters:{y0:[{id:906,schoolYear:"2025-2026",name:"1"},{id:1006,schoolYear:"2025-2026",name:"2"}],y1:[{id:1106,schoolYear:"2026-2027",name:"1"}]}}`)

	semesters, err := ParseSemesters(body)
	if err != nil {
		t.Fatalf("ParseSemesters returned error: %v", err)
	}
	if len(semesters) != 3 {
		t.Fatalf("unexpected semester count: %d", len(semesters))
	}
	if semesters[1].ID != "1006" || semesters[1].SchoolYear != "2025-2026" || semesters[1].Term != "2" {
		t.Fatalf("unexpected semester: %+v", semesters[1])
	}
}

func TestParseGradesKeepsAllColumns(t *testing.T) {
	grades, err := ParseGrades([]byte(sampleGradeHTML))
	if err != nil {
		t.Fatalf("ParseGrades returned error: %v", err)
	}
	if len(grades) != 2 {
		t.Fatalf("unexpected grade count: %d", len(grades))
	}

	first := grades[0]
	if first.CourseName != "体育4 排球" {
		t.Fatalf("unexpected course name: %q", first.CourseName)
	}
	if first.SchoolYearTerm != "2025-2026 2" || first.CourseCode != "COURSE001" || first.CourseSequence != "COURSE001.001" {
		t.Fatalf("unexpected course identity: %+v", first)
	}
	if first.CourseCategory != "体育类" || first.Credits != "1" {
		t.Fatalf("unexpected course metadata: %+v", first)
	}
	if first.UsualScore != "70" || first.FinalExamScore != "80" || first.OverallScore != "75" || first.FinalScore != "75" || first.GradePoint != "2.5" {
		t.Fatalf("unexpected scores: %+v", first)
	}

	second := grades[1]
	if second.Credits != "0.25" || second.FinalExamScore != "" || second.GradePoint != "3.5" {
		t.Fatalf("empty and decimal values should be preserved: %+v", second)
	}
}

func TestParseGradesReportsUnexpectedRowAndColumn(t *testing.T) {
	body := []byte(`<table class="gridtable"><tbody><tr><td colspan="11">暂无数据</td></tr></tbody></table>`)
	_, err := ParseGrades(body)
	if err == nil || !strings.Contains(err.Error(), "row=1 columns=1") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestParseGradesAllowsEmptyRowsInEmptyTable(t *testing.T) {
	body := []byte(`<table class="gridtable"><tbody><tr>
	</tr></tbody></table>`)
	grades, err := ParseGrades(body)
	if err != nil {
		t.Fatalf("ParseGrades returned error for an empty row: %v", err)
	}
	if len(grades) != 0 {
		t.Fatalf("unexpected grades parsed from an empty row: %+v", grades)
	}
}

const sampleGradeHTML = `
<div class="grid">
<table id="grid123" class="gridtable">
<thead><tr>
<th>学年学期</th><th>课程代码</th><th>课程序号</th><th>课程名称</th><th>课程类别</th>
<th>学分</th><th>平时成绩</th><th>期末成绩</th><th>总评成绩</th><th>最终</th><th>绩点</th>
</tr></thead>
<tbody id="grid123_data">
<tr>
<td>2025-2026 2</td><td>COURSE001</td><td>COURSE001.001</td><td>体育4 <sup>排球</sup></td><td>体育类</td>
<td>1</td><td>70</td><td>80</td><td>75</td><td>75</td><td>2.5</td>
</tr>
<tr>
<td>2025-2026 2</td><td>COURSE002</td><td>COURSE002.001</td><td>示例课程</td><td>公共课</td>
<td>0.25</td><td>85</td><td></td><td>85</td><td>85</td><td>3.5</td>
</tr>
</tbody>
</table>
</div>`
