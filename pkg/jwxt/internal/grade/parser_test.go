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
	if first.UsualScore != "70" || first.FinalExamScore != "80" || first.MakeupScore != "" || first.OverallScore != "75" || first.FinalScore != "75" || first.GradePoint != "2.5" {
		t.Fatalf("unexpected scores: %+v", first)
	}

	second := grades[1]
	if second.Credits != "0.25" || second.FinalExamScore != "" || second.GradePoint != "3.5" {
		t.Fatalf("empty and decimal values should be preserved: %+v", second)
	}
}

func TestParseGradesSupportsMakeupScoreColumn(t *testing.T) {
	grades, err := ParseGrades([]byte(sampleMakeupGradeHTML))
	if err != nil {
		t.Fatalf("ParseGrades returned error: %v", err)
	}
	if len(grades) != 2 {
		t.Fatalf("unexpected grade count: %d", len(grades))
	}
	if grades[0].CourseName != "高等数学1C" || grades[0].MakeupScore != "44" ||
		grades[0].OverallScore != "56" || grades[0].FinalScore != "56" ||
		grades[0].GradePoint != "0" {
		t.Fatalf("unexpected makeup grade: %+v", grades[0])
	}
	if grades[1].CourseName != "大学英语1" || grades[1].MakeupScore != "" ||
		grades[1].OverallScore != "65" {
		t.Fatalf("empty makeup score should be preserved: %+v", grades[1])
	}
}

func TestParseGradesAllowsMissingScoreColumns(t *testing.T) {
	body := []byte(`<table class="gridtable">
<thead><tr>
<th>学年学期</th><th>课程代码</th><th>课程序号</th><th>课程名称</th><th>课程类别</th>
<th>学分</th><th>总评成绩</th><th>最终</th><th>绩点</th>
</tr></thead>
<tbody><tr>
<td>2026-2027 1</td><td>COURSE003</td><td>COURSE003.001</td><td>新学期课程</td><td>专业课</td>
<td>2</td><td>88</td><td>88</td><td>3.8</td>
</tr></tbody></table>`)

	grades, err := ParseGrades(body)
	if err != nil {
		t.Fatalf("ParseGrades returned error: %v", err)
	}
	if len(grades) != 1 {
		t.Fatalf("unexpected grade count: %d", len(grades))
	}
	grade := grades[0]
	if grade.UsualScore != "" || grade.FinalExamScore != "" ||
		grade.OverallScore != "88" || grade.FinalScore != "88" ||
		grade.GradePoint != "3.8" {
		t.Fatalf("unexpected score mapping with missing columns: %+v", grade)
	}
}

func TestParseGradesAllowsVariableRowLengths(t *testing.T) {
	body := []byte(`<table class="gridtable">
<thead><tr>
<th>课程名称</th><th>学分</th><th>期末成绩</th><th>最终成绩</th><th>绩点</th>
</tr></thead>
<tbody>
<tr><td>短行课程</td><td>2</td><td>80</td></tr>
<tr><td>长行课程</td><td>1</td><td>90</td><td>90</td><td>4</td><td>额外字段</td></tr>
</tbody></table>`)

	grades, err := ParseGrades(body)
	if err != nil {
		t.Fatalf("ParseGrades returned error for variable row lengths: %v", err)
	}
	if len(grades) != 2 {
		t.Fatalf("unexpected grade count: %d", len(grades))
	}
	if grades[0].CourseName != "短行课程" || grades[0].FinalExamScore != "80" ||
		grades[0].FinalScore != "" || grades[0].GradePoint != "" {
		t.Fatalf("unexpected short row: %+v", grades[0])
	}
	if grades[1].CourseName != "长行课程" || grades[1].FinalScore != "90" ||
		grades[1].GradePoint != "4" {
		t.Fatalf("unexpected long row: %+v", grades[1])
	}
}

func TestParseGradesTreatsPlaceholderRowAsEmpty(t *testing.T) {
	body := []byte(`<table class="gridtable">
<thead><tr>
<th>学年学期</th><th>课程代码</th><th>课程序号</th><th>课程名称</th><th>课程类别</th>
<th>学分</th><th>平时成绩</th><th>期末成绩</th><th>总评成绩</th><th>最终</th><th>绩点</th>
</tr></thead>
<tbody><tr><td colspan="11">暂无数据</td></tr></tbody></table>`)

	grades, err := ParseGrades(body)
	if err != nil {
		t.Fatalf("ParseGrades returned error for placeholder row: %v", err)
	}
	if len(grades) != 0 {
		t.Fatalf("unexpected grades parsed from placeholder row: %+v", grades)
	}
}

func TestParseGradesRejectsUnrecognizedTable(t *testing.T) {
	body := []byte(`<table class="gridtable">
<thead><tr><th>未知字段</th></tr></thead>
<tbody><tr><td>未知内容</td></tr></tbody>
</table>`)

	_, err := ParseGrades(body)
	if err == nil || !strings.Contains(err.Error(), "grade columns not recognized") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestParseGradesAllowsEmptyRowsInEmptyTable(t *testing.T) {
	body := []byte(`<table class="gridtable">
<thead><tr>
<th>学年学期</th><th>课程代码</th><th>课程序号</th><th>课程名称</th><th>课程类别</th>
<th>学分</th><th>平时成绩</th><th>期末成绩</th><th>总评成绩</th><th>最终</th><th>绩点</th>
</tr></thead>
<tbody><tr>
	</tr></tbody></table>`)
	grades, err := ParseGrades(body)
	if err != nil {
		t.Fatalf("ParseGrades returned error for an empty row: %v", err)
	}
	if len(grades) != 0 {
		t.Fatalf("unexpected grades parsed from an empty row: %+v", grades)
	}
}

func TestParseGradesAllowsEmptyTableWithoutScoreColumns(t *testing.T) {
	body := []byte(`<table class="gridtable">
<thead><tr>
<th>学年学期</th><th>课程代码</th><th>课程序号</th><th>课程名称</th><th>课程类别</th><th>学分</th>
</tr></thead>
<tbody><tr><td colspan="6"> </td></tr></tbody></table>`)
	grades, err := ParseGrades(body)
	if err != nil {
		t.Fatalf("ParseGrades returned error for an empty table without score columns: %v", err)
	}
	if len(grades) != 0 {
		t.Fatalf("unexpected grades parsed from an empty table: %+v", grades)
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

const sampleMakeupGradeHTML = `
<div class="grid">
<table class="gridtable">
<thead><tr>
<th>学年学期</th><th>课程代码</th><th>课程序号</th><th>课程名称</th><th>课程类别</th>
<th>学分</th><th>平时成绩</th><th>期末成绩</th><th>补考成绩</th><th>总评成绩</th><th>最终</th><th>绩点</th>
</tr></thead>
<tbody>
<tr>
<td>2024-2025 1</td><td>MS001C</td><td>MS001C.241011</td><td>高等数学1C</td><td>数理基础类</td>
<td>4.5</td><td>73</td><td>44</td><td>44</td><td>56</td><td>56</td><td>0</td>
</tr>
<tr>
<td>2024-2025 1</td><td>FL001A</td><td>FL001A.241011</td><td>大学英语1</td><td>外语类</td>
<td>3</td><td>71</td><td>61</td><td></td><td>65</td><td>65</td><td>1.5</td>
</tr>
</tbody>
</table>
</div>`
