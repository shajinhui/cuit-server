package coursetable

import (
	"bytes"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/PuerkitoBio/goquery"
)

var (
	// 入口页的 searchTable 同时包含学生和班级课表 ID，只读取 setting.kind=std 分支中的学生 ID。
	studentIDPattern = regexp.MustCompile(`(?s)if\s*\([^{}]*\.val\(\)\s*==\s*"std"\s*\)\s*\{.*?addInput\(\s*form\s*,\s*"ids"\s*,\s*"([0-9]+)"\s*\)`)
	// semesterCalendar 初始化参数同时给出动态 tagId 和入口页默认学期，后续请求必须原样使用。
	calendarPattern = regexp.MustCompile(`jQuery\("#([^"]+Semester)"\)\.semesterCalendar\(\{[^}]*value:"([0-9]+)"`)
	// unitCount 和 marshalTable(from,startWeek,endWeek) 决定节次数量以及53位教学周串的换算范围。
	unitCountPattern = regexp.MustCompile(`var\s+unitCount\s*=\s*([0-9]+)\s*;`)
	marshalPattern   = regexp.MustCompile(`table[0-9]+\.marshalTable\(\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*([0-9]+)\s*\)`)
	indexPattern     = regexp.MustCompile(`index\s*=\s*([0-9]+)\s*\*\s*unitCount\s*\+\s*([0-9]+)\s*;`)
	courseRefPattern = regexp.MustCompile(`^[^(]+\(([^()]+)\)$`)
	teacherPattern   = regexp.MustCompile(`\{\s*id:\s*([0-9]+)\s*,\s*name:\s*"((?:\\.|[^"])*)"`)
)

const activityMarker = "activity = new TaskActivity("

type tableMeta struct {
	unitCount int // 每天节次数量。
	weekFrom  int // 学期第一周在全年53位教学周串中的位置。
	weekStart int // 本次页面输出的起始教学周。
	weekEnd   int // 本次页面输出的结束教学周。
}

type activityCall struct {
	arguments    string
	tail         string
	teacherIDs   []string
	teacherNames []string
}

type parsedActivity struct {
	courseSequence string
	activity       CourseActivity
}

func ParseStudentID(body []byte) (string, error) {
	match := studentIDPattern.FindSubmatch(body)
	if len(match) != 2 {
		return "", jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "student course table ID not found")
	}
	return string(match[1]), nil
}

func ParseCalendarContext(body []byte) (string, string, error) {
	match := calendarPattern.FindSubmatch(body)
	if len(match) != 3 {
		return "", "", jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "course table calendar context not found")
	}
	return string(match[1]), string(match[2]), nil
}

func ParseProjectID(body []byte) (string, error) {
	projectID := strings.TrimSpace(string(body))
	if projectID == "" {
		return "", jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "project ID not found")
	}
	if _, err := strconv.ParseUint(projectID, 10, 64); err != nil {
		return "", jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid project ID")
	}
	return projectID, nil
}

func ParseCourseTable(body []byte, semesterID string) (CourseTable, error) {
	// 页面下方的课程列表提供学分、教学班等课程信息，TaskActivity 脚本提供时间和地点，两者缺一不可。
	meta, err := parseTableMeta(body)
	if err != nil {
		return CourseTable{}, err
	}
	courses, err := parseCourses(body)
	if err != nil {
		return CourseTable{}, err
	}
	activities, err := parseActivities(string(body), meta)
	if err != nil {
		return CourseTable{}, err
	}
	if err := attachActivities(courses, activities); err != nil {
		return CourseTable{}, err
	}
	return CourseTable{
		SemesterID:     semesterID,
		WeekCount:      meta.weekEnd,
		SectionsPerDay: meta.unitCount,
		Courses:        courses,
	}, nil
}

func parseTableMeta(body []byte) (tableMeta, error) {
	unitMatch := unitCountPattern.FindSubmatch(body)
	weekMatch := marshalPattern.FindSubmatch(body)
	if len(unitMatch) != 2 || len(weekMatch) != 4 {
		return tableMeta{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "course table metadata not found")
	}
	unitCount, _ := strconv.Atoi(string(unitMatch[1]))
	weekFrom, _ := strconv.Atoi(string(weekMatch[1]))
	weekStart, _ := strconv.Atoi(string(weekMatch[2]))
	weekEnd, _ := strconv.Atoi(string(weekMatch[3]))
	if unitCount == 0 || weekFrom == 0 || weekStart == 0 || weekEnd < weekStart {
		return tableMeta{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid course table metadata")
	}
	return tableMeta{unitCount: unitCount, weekFrom: weekFrom, weekStart: weekStart, weekEnd: weekEnd}, nil
}

func parseCourses(body []byte) ([]Course, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid course table response")
	}
	table := findCourseListTable(doc)
	if table == nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "course list not found")
	}

	courses := make([]Course, 0)
	var parseErr error
	table.Find("tbody tr").EachWithBreak(func(rowIndex int, row *goquery.Selection) bool {
		cells := row.Find("td")
		if cells.Length() == 0 {
			return true
		}
		if cells.Length() != 8 {
			parseErr = jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, fmt.Sprintf("unexpected course column count: row=%d columns=%d", rowIndex+1, cells.Length()))
			return false
		}
		course, err := courseFromCells(cells)
		if err != nil {
			parseErr = err
			return false
		}
		courses = append(courses, course)
		return true
	})
	return courses, parseErr
}

func findCourseListTable(doc *goquery.Document) *goquery.Selection {
	var courseTable *goquery.Selection
	// 页面中的课表网格和课程列表都使用 gridtable，必须通过表头识别课程列表，不能直接取第一张表。
	doc.Find("table.gridtable").EachWithBreak(func(_ int, table *goquery.Selection) bool {
		headings := normalizeText(table.Find("thead").First().Text())
		if strings.Contains(headings, "课程代码") && strings.Contains(headings, "课程序号") && strings.Contains(headings, "教学班") {
			courseTable = table
			return false
		}
		return true
	})
	return courseTable
}

func courseFromCells(cells *goquery.Selection) (Course, error) {
	values := make([]string, 8)
	cells.Each(func(index int, cell *goquery.Selection) {
		values[index] = normalizeText(cell.Text())
	})
	lessonHref, ok := cells.Eq(4).Find("a").First().Attr("href")
	if !ok {
		return Course{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "course lesson ID not found")
	}
	lessonURL, err := url.Parse(lessonHref)
	// lesson.id 只出现在课程序号链接中，是后续访问单个教学任务时需要的 EAMS 标识。
	if err != nil || lessonURL.Query().Get("lesson.id") == "" {
		return Course{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid course lesson ID")
	}
	return Course{
		LessonID:      lessonURL.Query().Get("lesson.id"),
		Code:          values[1],
		Name:          values[2],
		Credits:       values[3],
		Sequence:      values[4],
		TeachingClass: values[5],
		Teachers:      splitNames(values[6]),
		Activities:    make([]CourseActivity, 0),
	}, nil
}

func parseActivities(script string, meta tableMeta) ([]parsedActivity, error) {
	// EAMS 把课表数据写在 TaskActivity 调用中，解析参数和 index 即可，无需执行页面脚本。
	calls, err := findActivityCalls(script)
	if err != nil {
		return nil, err
	}
	activities := make([]parsedActivity, 0, len(calls))
	for _, call := range calls {
		parsed, err := activitiesFromCall(call, meta)
		if err != nil {
			return nil, err
		}
		activities = append(activities, parsed...)
	}
	return activities, nil
}

func findActivityCalls(script string) ([]activityCall, error) {
	// TaskActivity 的教师参数包含 join(',') 嵌套调用，不能用遇到第一个右括号就结束的简单正则截取。
	calls := make([]activityCall, 0)
	for searchStart := 0; ; {
		relativeStart := strings.Index(script[searchStart:], activityMarker)
		if relativeStart < 0 {
			return calls, nil
		}
		markerStart := searchStart + relativeStart
		argumentsStart := markerStart + len(activityMarker)
		argumentsEnd, err := findClosingParenthesis(script, argumentsStart)
		if err != nil {
			return nil, err
		}
		tailStart := argumentsEnd + 1
		tailEnd := nextActivityBoundary(script, tailStart)
		teacherIDs, teacherNames, err := parseCallTeachers(script[:markerStart])
		if err != nil {
			return nil, err
		}
		calls = append(calls, activityCall{
			arguments:    script[argumentsStart:argumentsEnd],
			tail:         script[tailStart:tailEnd],
			teacherIDs:   teacherIDs,
			teacherNames: teacherNames,
		})
		searchStart = tailEnd
	}
}

func findClosingParenthesis(script string, start int) (int, error) {
	depth := 1
	var quote byte
	escaped := false
	for index := start; index < len(script); index++ {
		char := script[index]
		if escaped {
			escaped = false
			continue
		}
		if quote != 0 && char == '\\' {
			escaped = true
			continue
		}
		if quote != 0 {
			if char == quote {
				quote = 0
			}
			continue
		}
		if char == '"' || char == '\'' {
			quote = char
			continue
		}
		if char == '(' {
			depth++
		}
		if char == ')' {
			depth--
			if depth == 0 {
				return index, nil
			}
		}
	}
	return 0, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "unterminated course activity")
}

func nextActivityBoundary(script string, start int) int {
	boundary := len(script)
	if next := strings.Index(script[start:], activityMarker); next >= 0 {
		boundary = start + next
	}
	if marshal := marshalPattern.FindStringIndex(script[start:boundary]); marshal != nil {
		boundary = start + marshal[0]
	}
	return boundary
}

func parseCallTeachers(prefix string) ([]string, []string, error) {
	// 真实页面传入 actTeacherId.join(',')，教师明细来自当前 TaskActivity 调用之前最近的 teachers 数组。
	arrayStart := strings.LastIndex(prefix, "var teachers =")
	if arrayStart < 0 {
		return nil, nil, nil
	}
	arrayEnd := strings.Index(prefix[arrayStart:], ";")
	if arrayEnd < 0 {
		return nil, nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "unterminated course teacher list")
	}
	matches := teacherPattern.FindAllStringSubmatch(prefix[arrayStart:arrayStart+arrayEnd], -1)
	teacherIDs := make([]string, 0, len(matches))
	teacherNames := make([]string, 0, len(matches))
	for _, match := range matches {
		name, err := strconv.Unquote(`"` + match[2] + `"`)
		if err != nil {
			return nil, nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid course teacher name")
		}
		teacherIDs = append(teacherIDs, match[1])
		teacherNames = append(teacherNames, name)
	}
	return teacherIDs, teacherNames, nil
}

func activitiesFromCall(call activityCall, meta tableMeta) ([]parsedActivity, error) {
	arguments := splitArguments(call.arguments)
	if len(arguments) < 7 {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "unexpected course activity arguments")
	}
	values := make([]string, 7)
	for index := 2; index < len(values); index++ {
		value, err := parseJSString(arguments[index])
		if err != nil {
			return nil, err
		}
		values[index] = value
	}
	if len(call.teacherIDs) == 0 || len(call.teacherNames) == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "course teacher list not found")
	}
	values[0] = strings.Join(call.teacherIDs, ",")
	values[1] = strings.Join(call.teacherNames, ",")
	sequenceMatch := courseRefPattern.FindStringSubmatch(values[2])
	if len(sequenceMatch) != 2 {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "course sequence not found in activity")
	}
	weeks, err := parseWeeks(values[6], meta)
	if err != nil {
		return nil, err
	}
	return activitiesForIndexes(call.tail, sequenceMatch[1], values, weeks, meta.unitCount)
}

func splitArguments(arguments string) []string {
	parts := make([]string, 0, 14)
	start := 0
	depth := 0
	var quote byte
	escaped := false
	for index := 0; index < len(arguments); index++ {
		char := arguments[index]
		if escaped {
			escaped = false
			continue
		}
		if quote != 0 && char == '\\' {
			escaped = true
			continue
		}
		if quote != 0 {
			if char == quote {
				quote = 0
			}
			continue
		}
		if char == '"' || char == '\'' {
			quote = char
			continue
		}
		if char == '(' || char == '[' || char == '{' {
			depth++
			continue
		}
		if char == ')' || char == ']' || char == '}' {
			depth--
			continue
		}
		if depth == 0 && char == ',' {
			parts = append(parts, strings.TrimSpace(arguments[start:index]))
			start = index + 1
		}
	}
	return append(parts, strings.TrimSpace(arguments[start:]))
}

func parseJSString(argument string) (string, error) {
	value, err := strconv.Unquote(strings.TrimSpace(argument))
	if err != nil {
		return "", jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid course activity string")
	}
	return value, nil
}

func parseWeeks(validWeeks string, meta tableMeta) ([]int, error) {
	weeks := make([]int, 0)
	for index, value := range validWeeks {
		if value != '0' && value != '1' {
			return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid teaching week data")
		}
		// 位串索引从0开始、教学周从1开始，因此换算式为 week = index - from + 2。
		week := index - meta.weekFrom + 2
		if value == '1' && week >= meta.weekStart && week <= meta.weekEnd {
			weeks = append(weeks, week)
		}
	}
	return weeks, nil
}

func activitiesForIndexes(tail string, sequence string, values []string, weeks []int, unitCount int) ([]parsedActivity, error) {
	matches := indexPattern.FindAllStringSubmatch(tail, -1)
	if len(matches) == 0 {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "course activity position not found")
	}
	sectionsByDay := make(map[int][]int)
	for _, match := range matches {
		// 页面公式为 index = 星期下标 * unitCount + 节次下标；两个下标均从0开始，对外统一转换为1开始。
		day, _ := strconv.Atoi(match[1])
		section, _ := strconv.Atoi(match[2])
		if day < 0 || day > 6 || section < 0 || section >= unitCount {
			return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid course activity position")
		}
		sectionsByDay[day] = append(sectionsByDay[day], section+1)
	}
	return buildActivities(sequence, values, weeks, sectionsByDay), nil
}

func buildActivities(sequence string, values []string, weeks []int, sectionsByDay map[int][]int) []parsedActivity {
	days := make([]int, 0, len(sectionsByDay))
	for day := range sectionsByDay {
		days = append(days, day)
	}
	sort.Ints(days)

	activities := make([]parsedActivity, 0, len(days))
	for _, day := range days {
		for _, sectionRange := range consecutiveRanges(sectionsByDay[day]) {
			activities = append(activities, parsedActivity{
				courseSequence: sequence,
				activity: CourseActivity{
					TeacherIDs:   splitNames(values[0]),
					Teachers:     splitNames(values[1]),
					RoomID:       values[4],
					RoomName:     values[5],
					Weekday:      day + 1,
					StartSection: sectionRange[0],
					EndSection:   sectionRange[1],
					Weeks:        append([]int(nil), weeks...),
				},
			})
		}
	}
	return activities
}

func consecutiveRanges(sections []int) [][2]int {
	// 同一个 TaskActivity 会被写入每个占用节次，这里把连续节次合并成前端可直接展示的起止区间。
	sort.Ints(sections)
	ranges := make([][2]int, 0)
	start, end := sections[0], sections[0]
	for _, section := range sections[1:] {
		if section == end+1 {
			end = section
			continue
		}
		ranges = append(ranges, [2]int{start, end})
		start, end = section, section
	}
	return append(ranges, [2]int{start, end})
}

func attachActivities(courses []Course, activities []parsedActivity) error {
	// TaskActivity 和课程列表共同提供课程序号，使用它关联课程信息与具体上课安排。
	courseIndexes := make(map[string]int, len(courses))
	for index := range courses {
		courseIndexes[courses[index].Sequence] = index
	}
	for _, parsed := range activities {
		courseIndex, ok := courseIndexes[parsed.courseSequence]
		if !ok {
			return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "activity course is missing from course list")
		}
		courses[courseIndex].Activities = append(courses[courseIndex].Activities, parsed.activity)
	}
	return nil
}

func splitNames(value string) []string {
	if strings.TrimSpace(value) == "" {
		return []string{}
	}
	parts := strings.FieldsFunc(value, func(char rune) bool {
		return char == ',' || char == '，' || char == ';' || char == '；'
	})
	for index := range parts {
		parts[index] = strings.TrimSpace(parts[index])
	}
	return parts
}

func normalizeText(text string) string {
	return strings.Join(strings.Fields(text), " ")
}
