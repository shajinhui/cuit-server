// Package grade 实现了成绩页面的 HTML 解析逻辑。
//
// 提供的功能：
// - 解析学期选择控件以获取可用学期列表
// - 解析成绩表格为结构化的 Grade 列表
package grade

import (
	"bytes"
	"regexp"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/PuerkitoBio/goquery"
)

var (
	currentSemesterPattern = regexp.MustCompile(`person!search\.action\?semesterId=([0-9]+)`)
	semesterPattern        = regexp.MustCompile(`\{id:([0-9]+),schoolYear:"([^"]+)",name:"([^"]+)"\}`)
)

func ParseSemesterPage(body []byte) (string, string, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return "", "", jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "invalid semester page")
	}
	tagID, ok := doc.Find(`input.calendar-text[title="学年学期"]`).First().Attr("id")
	if !ok || strings.TrimSpace(tagID) == "" {
		return "", "", jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "semester tag ID not found")
	}
	match := currentSemesterPattern.FindSubmatch(body)
	if len(match) != 2 {
		return "", "", jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "current semester ID not found")
	}
	return strings.TrimSpace(tagID), string(match[1]), nil
}

func ParseSemesters(body []byte) ([]Semester, error) {
	matches := semesterPattern.FindAllSubmatch(body, -1)
	if len(matches) == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "semester list not found")
	}
	semesters := make([]Semester, 0, len(matches))
	for _, match := range matches {
		semesters = append(semesters, Semester{
			ID:         string(match[1]),
			SchoolYear: string(match[2]),
			Term:       string(match[3]),
		})
	}
	return semesters, nil
}

func ParseGrades(body []byte) ([]Grade, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "invalid grade response")
	}
	table := doc.Find("table.gridtable").First()
	if table.Length() == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "grade table not found")
	}
	if !hasGradeRows(table) {
		return []Grade{}, nil
	}
	columns, err := parseGradeColumns(table)
	if err != nil {
		return nil, err
	}
	grades := make([]Grade, 0)
	table.Find("tbody tr").Each(func(_ int, row *goquery.Selection) {
		cells := row.Find("td")
		if isEmptyGradeRow(row, cells) {
			return
		}
		grade := gradeFromCells(cells, columns)
		if !isEmptyGrade(grade) {
			grades = append(grades, grade)
		}
	})
	return grades, nil
}

func hasGradeRows(table *goquery.Selection) bool {
	hasRows := false
	table.Find("tbody tr").EachWithBreak(func(_ int, row *goquery.Selection) bool {
		if isEmptyGradeRow(row, row.Find("td")) {
			return true
		}
		hasRows = true
		return false
	})
	return hasRows
}

type gradeColumns struct {
	schoolYearTerm int
	courseCode     int
	courseSequence int
	courseName     int
	courseCategory int
	credits        int
	usualScore     int
	finalExamScore int
	makeupScore    int
	overallScore   int
	finalScore     int
	gradePoint     int
}

func parseGradeColumns(table *goquery.Selection) (gradeColumns, error) {
	headerCells := table.Find("thead").First().Find("th")
	if headerCells.Length() == 0 {
		return gradeColumns{}, jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "grade table header not found")
	}
	headers := make([]string, headerCells.Length())
	headerCells.Each(func(index int, cell *goquery.Selection) {
		headers[index] = normalizeText(cell.Text())
	})

	find := func(names ...string) int {
		for index, header := range headers {
			for _, name := range names {
				if header == name {
					return index
				}
			}
		}
		return -1
	}

	columns := gradeColumns{
		schoolYearTerm: find("学年学期", "学期"),
		courseCode:     find("课程代码", "课程编号"),
		courseSequence: find("课程序号"),
		courseName:     find("课程名称", "课程"),
		courseCategory: find("课程类别", "课程性质"),
		credits:        find("学分"),
		usualScore:     find("平时成绩", "平时", "过程成绩", "平时分"),
		finalExamScore: find("期末成绩", "期末", "考试成绩"),
		makeupScore:    find("补考成绩", "补考"),
		overallScore:   find("总评成绩", "总评"),
		finalScore:     find("最终", "最终成绩", "成绩"),
		gradePoint:     find("绩点"),
	}
	if !columns.hasRecognizedColumn() {
		return gradeColumns{}, jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, "grade columns not recognized")
	}
	return columns, nil
}

func (columns gradeColumns) hasRecognizedColumn() bool {
	return columns.schoolYearTerm >= 0 ||
		columns.courseCode >= 0 ||
		columns.courseSequence >= 0 ||
		columns.courseName >= 0 ||
		columns.courseCategory >= 0 ||
		columns.credits >= 0 ||
		columns.usualScore >= 0 ||
		columns.finalExamScore >= 0 ||
		columns.makeupScore >= 0 ||
		columns.overallScore >= 0 ||
		columns.finalScore >= 0 ||
		columns.gradePoint >= 0
}

func gradeFromCells(cells *goquery.Selection, columns gradeColumns) Grade {
	return Grade{
		SchoolYearTerm: gradeCellText(cells, columns.schoolYearTerm),
		CourseCode:     gradeCellText(cells, columns.courseCode),
		CourseSequence: gradeCellText(cells, columns.courseSequence),
		CourseName:     gradeCellText(cells, columns.courseName),
		CourseCategory: gradeCellText(cells, columns.courseCategory),
		Credits:        gradeCellText(cells, columns.credits),
		UsualScore:     gradeCellText(cells, columns.usualScore),
		FinalExamScore: gradeCellText(cells, columns.finalExamScore),
		MakeupScore:    gradeCellText(cells, columns.makeupScore),
		OverallScore:   gradeCellText(cells, columns.overallScore),
		FinalScore:     gradeCellText(cells, columns.finalScore),
		GradePoint:     gradeCellText(cells, columns.gradePoint),
	}
}

func isEmptyGradeRow(row *goquery.Selection, cells *goquery.Selection) bool {
	text := normalizeText(row.Text())
	if text == "" {
		return true
	}
	if cells.Length() != 1 {
		return false
	}
	placeholder := strings.ReplaceAll(text, " ", "")
	return strings.Contains(placeholder, "暂无") ||
		strings.Contains(placeholder, "无数据") ||
		strings.Contains(placeholder, "未查询到") ||
		strings.Contains(placeholder, "没有")
}

func isEmptyGrade(grade Grade) bool {
	return grade.SchoolYearTerm == "" &&
		grade.CourseCode == "" &&
		grade.CourseSequence == "" &&
		grade.CourseName == "" &&
		grade.CourseCategory == "" &&
		grade.Credits == "" &&
		grade.UsualScore == "" &&
		grade.FinalExamScore == "" &&
		grade.MakeupScore == "" &&
		grade.OverallScore == "" &&
		grade.FinalScore == "" &&
		grade.GradePoint == ""
}

func gradeCellText(cells *goquery.Selection, index int) string {
	if index < 0 || index >= cells.Length() {
		return ""
	}
	return normalizeText(cells.Eq(index).Text())
}

func normalizeText(text string) string {
	return strings.Join(strings.Fields(text), " ")
}
