package coursetable

import (
	"bytes"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/PuerkitoBio/goquery"
)

var (
	classroomPageInfoPattern = regexp.MustCompile(`\.pageInfo\(\s*[0-9]+\s*,\s*[0-9]+\s*,\s*([0-9]+)\s*\)`)
	roomTableIndexPattern    = regexp.MustCompile(`var\s+table([0-9]+)\s*=\s*new\s+CourseTable\(`)
)

type occupiedPeriod struct {
	weekday      int
	startSection int
	endSection   int
	weeks        []int
}

// ParseClassroomPage 解析公共课表页面中的一页教室列表和总记录数。
func ParseClassroomPage(body []byte) ([]Classroom, int, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, 0, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid classroom response")
	}
	table := findClassroomTable(doc)
	if table == nil {
		return nil, 0, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "classroom list not found")
	}

	rooms := make([]Classroom, 0)
	var parseErr error
	table.Find("tbody tr").EachWithBreak(func(rowIndex int, row *goquery.Selection) bool {
		cells := row.Find("td")
		if cells.Length() != 7 {
			parseErr = jwxterr.WithMessage(
				jwxterr.ErrCourseTableQueryFailed,
				fmt.Sprintf("unexpected classroom column count: row=%d columns=%d", rowIndex+1, cells.Length()),
			)
			return false
		}
		room, err := classroomFromCells(cells)
		if err != nil {
			parseErr = err
			return false
		}
		rooms = append(rooms, room)
		return true
	})
	if parseErr != nil {
		return nil, 0, parseErr
	}

	totalMatch := classroomPageInfoPattern.FindSubmatch(body)
	if len(totalMatch) != 2 {
		return nil, 0, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "classroom page information not found")
	}
	total, _ := strconv.Atoi(string(totalMatch[1]))
	return rooms, total, nil
}

func findClassroomTable(doc *goquery.Document) *goquery.Selection {
	var classroomTable *goquery.Selection
	doc.Find("table.gridtable").EachWithBreak(func(_ int, table *goquery.Selection) bool {
		headings := normalizeText(table.Find("thead").First().Text())
		if strings.Contains(headings, "教室设备配置") && strings.Contains(headings, "容纳听课人数") {
			classroomTable = table
			return false
		}
		return true
	})
	return classroomTable
}

func classroomFromCells(cells *goquery.Selection) (Classroom, error) {
	id, ok := cells.Eq(0).Find(`input[name="classroom.id"]`).First().Attr("value")
	if !ok || strings.TrimSpace(id) == "" {
		return Classroom{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "classroom ID not found")
	}

	values := make([]string, 6)
	for index := range values {
		values[index] = normalizeText(cells.Eq(index + 1).Text())
	}
	capacity, err := strconv.Atoi(values[5])
	if err != nil {
		return Classroom{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid classroom capacity")
	}
	return Classroom{
		ID:       strings.TrimSpace(id),
		Code:     values[0],
		Name:     values[1],
		Building: values[2],
		Campus:   values[3],
		Type:     values[4],
		Capacity: capacity,
	}, nil
}

// ParseClassroomOptions 读取教室查询页面中的校区和教室类型下拉选项。
func ParseClassroomOptions(body []byte) (ClassroomOptions, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return ClassroomOptions{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid classroom option response")
	}
	campuses := parseSelectOptions(doc, `select[name="classroom.campus.id"]`)
	classroomTypes := parseSelectOptions(doc, `select[name="classroom.type.id"]`)
	if len(campuses) == 0 || len(classroomTypes) == 0 {
		return ClassroomOptions{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "classroom options not found")
	}
	return ClassroomOptions{
		Campuses:       campuses,
		ClassroomTypes: classroomTypes,
		Buildings:      []ClassroomOption{},
	}, nil
}

// ParseBuildingOptions 解析校区联动请求返回的 option HTML 片段。
func ParseBuildingOptions(body []byte) ([]ClassroomOption, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid building option response")
	}
	options := parseOptions(doc.Find("option"))
	if len(options) == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "building options not found")
	}
	return options, nil
}

func parseSelectOptions(doc *goquery.Document, selector string) []ClassroomOption {
	return parseOptions(doc.Find(selector).First().Find("option"))
}

func parseOptions(selection *goquery.Selection) []ClassroomOption {
	options := make([]ClassroomOption, 0)
	selection.Each(func(_ int, option *goquery.Selection) {
		id, ok := option.Attr("value")
		name := normalizeText(option.Text())
		if !ok || strings.TrimSpace(id) == "" || name == "" || name == "..." {
			return
		}
		options = append(options, ClassroomOption{ID: strings.TrimSpace(id), Name: name})
	})
	return options
}

// ParseRoomOccupancies 按 rooms 顺序返回每间教室的占用时间。
//
// 教务处批量课表响应中的 table0、table1 不保证与请求 ids 的顺序一致，
// 因此优先使用每张课表前的“教室XXX课程安排”标题建立对应关系。
func ParseRoomOccupancies(body []byte, rooms []Classroom) ([][]occupiedPeriod, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid classroom course table response")
	}

	roomCount := len(rooms)
	occupancies := make([][]occupiedPeriod, roomCount)
	seen := make([]bool, roomCount)
	var parseErr error
	currentRoomIndex := -1
	doc.Find("h2, script").EachWithBreak(func(_ int, element *goquery.Selection) bool {
		if goquery.NodeName(element) == "h2" {
			currentRoomIndex = classroomIndexFromHeading(element.Text(), rooms)
			return true
		}

		content := element.Text()
		indexMatch := roomTableIndexPattern.FindStringSubmatch(content)
		if len(indexMatch) != 2 {
			return true
		}
		tableIndex, _ := strconv.Atoi(indexMatch[1])
		roomIndex := currentRoomIndex
		if roomIndex < 0 {
			roomIndex = tableIndex
		}
		if roomIndex < 0 || roomIndex >= roomCount || seen[roomIndex] {
			parseErr = jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid classroom table index")
			return false
		}
		periods, err := parseOccupiedPeriods(content)
		if err != nil {
			parseErr = err
			return false
		}
		occupancies[roomIndex] = periods
		seen[roomIndex] = true
		currentRoomIndex = -1
		return true
	})
	if parseErr != nil {
		return nil, parseErr
	}
	for index, found := range seen {
		if !found {
			return nil, jwxterr.WithMessage(
				jwxterr.ErrCourseTableQueryFailed,
				fmt.Sprintf("classroom table not found: index=%d", index),
			)
		}
	}
	return occupancies, nil
}

func classroomIndexFromHeading(heading string, rooms []Classroom) int {
	roomLabel := normalizeText(heading)
	roomLabel = strings.TrimPrefix(roomLabel, "教室")
	roomLabel = strings.TrimSuffix(roomLabel, "课程安排")
	roomLabel = normalizeText(roomLabel)
	if roomLabel == "" {
		return -1
	}

	for index, room := range rooms {
		if roomLabel == normalizeText(room.Code) || roomLabel == normalizeText(room.Name) {
			return index
		}
	}
	return -1
}

func parseOccupiedPeriods(script string) ([]occupiedPeriod, error) {
	meta, err := parseTableMeta([]byte(script))
	if err != nil {
		return nil, err
	}
	calls, err := findActivityCalls(script)
	if err != nil {
		return nil, err
	}

	periods := make([]occupiedPeriod, 0, len(calls))
	for _, call := range calls {
		parsed, err := occupiedPeriodsFromCall(call, meta)
		if err != nil {
			return nil, err
		}
		periods = append(periods, parsed...)
	}
	return periods, nil
}

func occupiedPeriodsFromCall(call activityCall, meta tableMeta) ([]occupiedPeriod, error) {
	arguments := splitArguments(call.arguments)
	if len(arguments) < 7 {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "unexpected classroom activity arguments")
	}
	validWeeks, err := parseJSString(arguments[6])
	if err != nil {
		return nil, err
	}
	weeks, err := parseWeeks(validWeeks, meta)
	if err != nil {
		return nil, err
	}

	matches := indexPattern.FindAllStringSubmatch(call.tail, -1)
	if len(matches) == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "classroom activity position not found")
	}
	sectionsByDay := make(map[int][]int)
	for _, match := range matches {
		day, _ := strconv.Atoi(match[1])
		section, _ := strconv.Atoi(match[2])
		if day < 0 || day > 6 || section < 0 || section >= meta.unitCount {
			return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid classroom activity position")
		}
		sectionsByDay[day] = append(sectionsByDay[day], section+1)
	}

	periods := make([]occupiedPeriod, 0, len(sectionsByDay))
	for day, sections := range sectionsByDay {
		for _, sectionRange := range consecutiveRanges(sections) {
			periods = append(periods, occupiedPeriod{
				weekday:      day + 1,
				startSection: sectionRange[0],
				endSection:   sectionRange[1],
				weeks:        append([]int(nil), weeks...),
			})
		}
	}
	return periods, nil
}
