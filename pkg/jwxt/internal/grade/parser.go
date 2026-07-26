// Package grade 实现了成绩页面的 HTML 解析逻辑。
//
// 提供的功能：
// - 解析学期选择控件以获取可用学期列表
// - 解析成绩表格为结构化的 Grade 列表
package grade

import (
	"bytes"
	"fmt"
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
	var parseErr error
	table.Find("tbody tr").EachWithBreak(func(index int, row *goquery.Selection) bool {
		cells := row.Find("td")
		if cells.Length() == 0 && normalizeText(row.Text()) == "" {
			return true
		}
		if cells.Length() != columns.count {
			message := fmt.Sprintf("unexpected grade column count: row=%d columns=%d", index+1, cells.Length())
			parseErr = jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, message)
			return false
		}
		grades = append(grades, gradeFromCells(cells, columns))
		return true
	})
	return grades, parseErr
}

func hasGradeRows(table *goquery.Selection) bool {
	hasRows := false
	table.Find("tbody tr").EachWithBreak(func(_ int, row *goquery.Selection) bool {
		if normalizeText(row.Text()) == "" {
			return true
		}
		hasRows = true
		return false
	})
	return hasRows
}

type gradeColumns struct {
	count          int
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

	required := func(names ...string) (int, error) {
		for index, header := range headers {
			for _, name := range names {
				if header == name {
					return index, nil
				}
			}
		}
		return -1, jwxterr.WithMessage(
			jwxterr.ErrGradeQueryFailed,
			fmt.Sprintf("grade column not found: %s", names[0]),
		)
	}
	optional := func(names ...string) int {
		index, _ := required(names...)
		return index
	}

	columns := gradeColumns{count: len(headers), makeupScore: optional("补考成绩")}
	var err error
	if columns.schoolYearTerm, err = required("学年学期"); err != nil {
		return gradeColumns{}, err
	}
	if columns.courseCode, err = required("课程代码"); err != nil {
		return gradeColumns{}, err
	}
	if columns.courseSequence, err = required("课程序号"); err != nil {
		return gradeColumns{}, err
	}
	if columns.courseName, err = required("课程名称"); err != nil {
		return gradeColumns{}, err
	}
	if columns.courseCategory, err = required("课程类别"); err != nil {
		return gradeColumns{}, err
	}
	if columns.credits, err = required("学分"); err != nil {
		return gradeColumns{}, err
	}
	if columns.usualScore, err = required("平时成绩"); err != nil {
		return gradeColumns{}, err
	}
	if columns.finalExamScore, err = required("期末成绩"); err != nil {
		return gradeColumns{}, err
	}
	if columns.overallScore, err = required("总评成绩"); err != nil {
		return gradeColumns{}, err
	}
	if columns.finalScore, err = required("最终", "最终成绩"); err != nil {
		return gradeColumns{}, err
	}
	if columns.gradePoint, err = required("绩点"); err != nil {
		return gradeColumns{}, err
	}
	return columns, nil
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

func gradeCellText(cells *goquery.Selection, index int) string {
	if index < 0 || index >= cells.Length() {
		return ""
	}
	return normalizeText(cells.Eq(index).Text())
}

func normalizeText(text string) string {
	return strings.Join(strings.Fields(text), " ")
}
