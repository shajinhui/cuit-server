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
	grades := make([]Grade, 0)
	var parseErr error
	table.Find("tbody tr").EachWithBreak(func(index int, row *goquery.Selection) bool {
		cells := row.Find("td")
		if cells.Length() == 0 && normalizeText(row.Text()) == "" {
			return true
		}
		if cells.Length() != 11 {
			message := fmt.Sprintf("unexpected grade column count: row=%d columns=%d", index+1, cells.Length())
			parseErr = jwxterr.WithMessage(jwxterr.ErrGradeQueryFailed, message)
			return false
		}
		values := make([]string, 11)
		cells.Each(func(index int, cell *goquery.Selection) {
			values[index] = normalizeText(cell.Text())
		})
		grades = append(grades, gradeFromValues(values))
		return true
	})
	return grades, parseErr
}

func gradeFromValues(values []string) Grade {
	return Grade{
		SchoolYearTerm: values[0],
		CourseCode:     values[1],
		CourseSequence: values[2],
		CourseName:     values[3],
		CourseCategory: values[4],
		Credits:        values[5],
		UsualScore:     values[6],
		FinalExamScore: values[7],
		OverallScore:   values[8],
		FinalScore:     values[9],
		GradePoint:     values[10],
	}
}

func normalizeText(text string) string {
	return strings.Join(strings.Fields(text), " ")
}
