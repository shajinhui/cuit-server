package exam

import (
	"bytes"
	"fmt"
	"net/url"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/PuerkitoBio/goquery"
)

const examRoomDownloadPath = "/eams/stdExamTable!downloadExamroomSeat.action"

// ParseBatches 解析指定学期的考试批次。未来学期可能尚未设置排考批次，
// 此时 select 存在但没有 option，应返回空列表。
func ParseBatches(body []byte) ([]Batch, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrExamQueryFailed, "invalid exam batch page")
	}
	selectBox := doc.Find(`form#semesterForm select[name="examBatch.id"]`).First()
	if selectBox.Length() == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrExamQueryFailed, "exam batch selector not found")
	}

	batches := make([]Batch, 0)
	selectBox.Find("option").Each(func(_ int, option *goquery.Selection) {
		id, ok := option.Attr("value")
		name := normalizeText(option.Text())
		if !ok || strings.TrimSpace(id) == "" || name == "" {
			return
		}
		batches = append(batches, Batch{ID: strings.TrimSpace(id), Name: name})
	})
	return batches, nil
}

// ParseExams 按页面九列表头解析考场数据。未安排的日期、时间和地点是 EAMS
// 返回的业务文本，SDK 原样保留，不自行改写为空值。
func ParseExams(body []byte) ([]Exam, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrExamQueryFailed, "invalid exam response")
	}
	table := findExamTable(doc)
	if table == nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrExamQueryFailed, "exam table not found")
	}

	exams := make([]Exam, 0)
	var parseErr error
	table.Find("tbody tr").EachWithBreak(func(rowIndex int, row *goquery.Selection) bool {
		cells := row.Find("td")
		// EAMS 的空批次会保留一个没有 td 的空 tr。
		if cells.Length() == 0 {
			return true
		}
		if cells.Length() != 9 {
			parseErr = jwxterr.WithMessage(
				jwxterr.ErrExamQueryFailed,
				fmt.Sprintf("unexpected exam column count: row=%d columns=%d", rowIndex+1, cells.Length()),
			)
			return false
		}
		exams = append(exams, examFromCells(cells))
		return true
	})
	return exams, parseErr
}

func findExamTable(doc *goquery.Document) *goquery.Selection {
	var result *goquery.Selection
	doc.Find("table.gridtable").EachWithBreak(func(_ int, table *goquery.Selection) bool {
		headings := normalizeText(table.Find("thead").Text())
		if strings.Contains(headings, "考试日期") &&
			strings.Contains(headings, "考试地点") &&
			strings.Contains(headings, "考试状态") {
			result = table
			return false
		}
		return true
	})
	return result
}

func examFromCells(cells *goquery.Selection) Exam {
	values := make([]string, 9)
	for index := range values {
		values[index] = normalizeText(cells.Eq(index).Text())
	}
	return Exam{
		CourseSequence: values[0],
		CourseName:     values[1],
		ExamType:       values[2],
		ExamDate:       values[3],
		ExamTime:       values[4],
		Location:       values[5],
		ExamRoomID:     parseExamRoomID(cells.Eq(5)),
		Credits:        values[6],
		Status:         values[7],
		Remark:         values[8],
	}
}

func parseExamRoomID(cell *goquery.Selection) string {
	href, ok := cell.Find("a").First().Attr("href")
	if !ok {
		return ""
	}
	target, err := url.Parse(strings.TrimSpace(href))
	if err != nil || target.Path != examRoomDownloadPath {
		return ""
	}
	return strings.TrimSpace(target.Query().Get("examRoom.id"))
}

func normalizeText(text string) string {
	return strings.Join(strings.Fields(text), " ")
}
