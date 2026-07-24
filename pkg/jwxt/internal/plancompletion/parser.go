package plancompletion

import (
	"bytes"
	"fmt"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/PuerkitoBio/goquery"
)

var expectedHeaders = []string{
	"序号",
	"课程序号",
	"课程名称",
	"要求学分",
	"实修学分",
	"成绩",
	"是否通过",
	"备注",
}

// ParsePlanCompletion 解析页面顶部摘要和完成情况表。
func ParsePlanCompletion(body []byte) (PlanCompletion, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return PlanCompletion{}, jwxterr.WithMessage(jwxterr.ErrPlanCompletionQueryFailed, "invalid plan completion response")
	}
	summary, err := parseSummary(doc)
	if err != nil {
		return PlanCompletion{}, err
	}
	items, err := parseItems(doc)
	if err != nil {
		return PlanCompletion{}, err
	}
	return PlanCompletion{Summary: summary, Items: items}, nil
}

func parseSummary(doc *goquery.Document) (PlanCompletionSummary, error) {
	table := doc.Find("table.infoTable").First()
	if table.Length() == 0 {
		return PlanCompletionSummary{}, jwxterr.WithMessage(jwxterr.ErrPlanCompletionQueryFailed, "plan completion summary not found")
	}
	fields := make(map[string]string)
	table.Find("td.title").Each(func(_ int, label *goquery.Selection) {
		value := label.NextFiltered("td").First()
		if value.Length() != 0 {
			fields[normalizeLabel(label.Text())] = normalizeText(value.Text())
		}
	})
	requiredCredits, earnedCredits, err := splitCredits(fields["要求学分/实修学分"])
	if err != nil {
		return PlanCompletionSummary{}, err
	}
	summary := PlanCompletionSummary{
		StudentNo:       fields["学号"],
		Name:            fields["姓名"],
		Grade:           fields["年级"],
		EducationLevel:  fields["学历层次"],
		StudentCategory: fields["学生类别"],
		College:         fields["院系"],
		Major:           fields["专业/专业方向"],
		RequiredCredits: requiredCredits,
		EarnedCredits:   earnedCredits,
		GPA:             fields["GPA"],
		AuditResult:     fields["审核结果"],
		AuditTime:       fields["审核时间"],
		Auditor:         fields["审核人"],
		Remark:          fields["备注"],
	}
	if summary.StudentNo == "" || summary.Name == "" {
		return PlanCompletionSummary{}, jwxterr.WithMessage(jwxterr.ErrPlanCompletionQueryFailed, "student number or name not found")
	}
	return summary, nil
}

func parseItems(doc *goquery.Document) ([]PlanCompletionItem, error) {
	table := doc.Find("table.formTable").First()
	if table.Length() == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrPlanCompletionQueryFailed, "plan completion detail table not found")
	}
	rows := table.Find("tr")
	if rows.Length() == 0 || !headersMatch(rows.First()) {
		return nil, jwxterr.WithMessage(jwxterr.ErrPlanCompletionQueryFailed, "unexpected plan completion headers")
	}
	items := make([]PlanCompletionItem, 0, rows.Length()-1)
	var parseErr error
	rows.Slice(1, rows.Length()).EachWithBreak(func(index int, row *goquery.Selection) bool {
		item, err := parseItem(row)
		if err != nil {
			safeErr := jwxterr.WithMessage(
				jwxterr.ErrPlanCompletionQueryFailed,
				fmt.Sprintf("invalid plan completion row: row=%d", index+1),
			)
			parseErr = fmt.Errorf("%w: %w", safeErr, err)
			return false
		}
		items = append(items, item)
		return true
	})
	if parseErr != nil {
		return nil, parseErr
	}
	return items, nil
}

func parseItem(row *goquery.Selection) (PlanCompletionItem, error) {
	cells := row.ChildrenFiltered("td")
	if row.HasClass("darkColumn") && cells.Length() == 6 {
		colspan, _ := cells.First().Attr("colspan")
		if colspan != "3" {
			return PlanCompletionItem{}, fmt.Errorf("unexpected requirement colspan")
		}
		values := cellValues(cells)
		return PlanCompletionItem{
			Kind:            PlanCompletionRequirement,
			Name:            values[0],
			RequiredCredits: values[1],
			EarnedCredits:   values[2],
			Score:           values[3],
			Status:          values[4],
			Remark:          values[5],
		}, nil
	}
	if !row.HasClass("darkColumn") && cells.Length() == 8 {
		values := cellValues(cells)
		return PlanCompletionItem{
			Kind:            PlanCompletionCourse,
			Sequence:        values[0],
			CourseCode:      values[1],
			Name:            values[2],
			RequiredCredits: values[3],
			EarnedCredits:   values[4],
			Score:           values[5],
			Status:          values[6],
			Remark:          values[7],
		}, nil
	}
	return PlanCompletionItem{}, fmt.Errorf("unexpected row shape")
}

func headersMatch(row *goquery.Selection) bool {
	values := cellValues(row.ChildrenFiltered("td,th"))
	if len(values) != len(expectedHeaders) {
		return false
	}
	for index := range values {
		if values[index] != expectedHeaders[index] {
			return false
		}
	}
	return true
}

func cellValues(cells *goquery.Selection) []string {
	values := make([]string, cells.Length())
	cells.Each(func(index int, cell *goquery.Selection) {
		values[index] = cellText(cell)
	})
	return values
}

func cellText(cell *goquery.Selection) string {
	// 同一课程的多次成绩使用 br 分行，解析时保留为以空格分隔的原始成绩序列。
	clone := cell.Clone()
	clone.Find("br").Each(func(_ int, br *goquery.Selection) {
		br.ReplaceWithHtml(" ")
	})
	return normalizeText(clone.Text())
}

func splitCredits(value string) (string, string, error) {
	parts := strings.SplitN(value, "/", 2)
	if len(parts) != 2 {
		return "", "", jwxterr.WithMessage(jwxterr.ErrPlanCompletionQueryFailed, "invalid credit summary")
	}
	return strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1]), nil
}

func normalizeLabel(value string) string {
	value = normalizeText(value)
	value = strings.TrimSuffix(value, ":")
	return strings.TrimSuffix(value, "：")
}

func normalizeText(value string) string {
	return strings.Join(strings.Fields(value), " ")
}
