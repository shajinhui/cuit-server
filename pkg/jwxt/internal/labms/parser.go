package labms

import (
	"crypto/sha256"
	"encoding/hex"
	"sort"
	"strings"
	"unicode"
	"unicode/utf8"

	"cuit-server/pkg/jwxt/internal/coursetable"
	"cuit-server/pkg/jwxt/internal/jwxterr"
)

func ToCourseTable(items []ScheduleItem, semesterID string) (coursetable.CourseTable, error) {
	courses := make(map[string]*coursetable.Course)
	order := make([]string, 0)
	weekCount := 0
	for _, item := range items {
		weekday := int(item.Weekday)
		sections := normalizedPositiveInts(item.Sections)
		weeks := normalizedPositiveInts(item.Weeks)
		if len(weeks) == 0 && item.Week > 0 {
			weeks = []int{int(item.Week)}
		}
		if strings.TrimSpace(item.CourseName) == "" || weekday < 1 || weekday > 7 || len(sections) == 0 {
			return coursetable.CourseTable{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid LABMS course activity")
		}
		if len(weeks) > 0 && weeks[len(weeks)-1] > weekCount {
			weekCount = weeks[len(weeks)-1]
		}

		identity := courseIdentity(item)
		course := courses[identity]
		if course == nil {
			course = &coursetable.Course{
				LessonID:      "labms:" + identity,
				Code:          strings.TrimSpace(item.CourseNo),
				Name:          displayCourseName(item.CourseName, item.ProjectType),
				TeachingClass: normalizeJoinedNames(item.ClassName),
				Teachers:      splitNames(item.TeacherName),
				Activities:    make([]coursetable.CourseActivity, 0),
			}
			courses[identity] = course
			order = append(order, identity)
		} else {
			course.TeachingClass = mergeJoinedNames(course.TeachingClass, item.ClassName)
			course.Teachers = uniqueStrings(append(course.Teachers, splitNames(item.TeacherName)...))
		}
		course.Activities = append(course.Activities, coursetable.CourseActivity{
			Teachers:     splitNames(item.TeacherName),
			RoomName:     displayLocation(item.Location),
			Weekday:      weekday,
			StartSection: sections[0],
			EndSection:   sections[len(sections)-1],
			Weeks:        weeks,
			StartTime:    clockTime(item.StartTime),
			EndTime:      clockTime(item.EndTime),
			ActivityType: strings.TrimSpace(item.ProjectType),
			ProjectName:  strings.TrimSpace(item.ProjectName),
		})
	}

	result := make([]coursetable.Course, 0, len(order))
	for _, identity := range order {
		result = append(result, *courses[identity])
	}
	return coursetable.CourseTable{
		SemesterID:     semesterID,
		WeekCount:      weekCount,
		SectionsPerDay: 12,
		Courses:        result,
	}, nil
}

func SemesterName(schoolYear string, term string) (string, error) {
	termName := map[string]string{"1": "第一学期", "2": "第二学期", "3": "第三学期"}[strings.TrimSpace(term)]
	if strings.TrimSpace(schoolYear) == "" || termName == "" {
		return "", jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid semester metadata")
	}
	return strings.TrimSpace(schoolYear) + "学年" + termName, nil
}

func courseIdentity(item ScheduleItem) string {
	category := "regular"
	if isExperiment(item.ProjectType) {
		category = "experiment"
	}
	for _, value := range []string{string(item.CourseID), string(item.TaskID), item.CourseNo} {
		if value = strings.TrimSpace(value); value != "" {
			return value + ":" + category
		}
	}
	sum := sha256.Sum256([]byte(strings.TrimSpace(item.CourseName) + "\x00" + normalizeJoinedNames(item.ClassName) + "\x00" + category))
	return hex.EncodeToString(sum[:8])
}

// displayCourseName keeps the compact EAMS-style label used by the timetable.
// LABMS may attach a leading activity kind to the course name; regular classes
// do not need that noise, while experimental activities get one stable marker.
func displayCourseName(courseName string, projectType string) string {
	name := strings.Join(strings.Fields(courseName), " ")
	if isExperiment(projectType) {
		name = trimLeadingActivityMarker(name, "实验")
		if strings.HasPrefix(name, "实验") {
			return name
		}
		if strings.HasSuffix(name, "实验") && len([]rune(name)) > len([]rune("实验")) {
			name = strings.TrimSpace(strings.TrimSuffix(name, "实验"))
		}
		if name == "" {
			return "实验"
		}
		return "实验 " + name
	}
	return trimLeadingActivityMarker(name, "理论")
}

func isExperiment(projectType string) bool {
	return strings.Contains(strings.TrimSpace(projectType), "实验")
}

func trimLeadingActivityMarker(value string, marker string) string {
	value = strings.TrimSpace(value)
	for _, prefix := range []string{
		"【" + marker + "】",
		"[" + marker + "]",
		"（" + marker + "）",
		"(" + marker + ")",
	} {
		if strings.HasPrefix(value, prefix) {
			return strings.TrimSpace(value[len(prefix):])
		}
	}
	for _, prefix := range []string{marker + "课", marker} {
		if !strings.HasPrefix(value, prefix) {
			continue
		}
		remainder := value[len(prefix):]
		if remainder == "" {
			return ""
		}
		first, _ := utf8.DecodeRuneInString(remainder)
		if unicode.IsSpace(first) || strings.ContainsRune(":：-－—·|｜", first) {
			return strings.TrimSpace(strings.TrimLeftFunc(remainder, func(r rune) bool {
				return unicode.IsSpace(r) || strings.ContainsRune(":：-－—·|｜", r)
			}))
		}
	}
	return value
}

// displayLocation removes the LABMS campus/building/lab hierarchy. The final
// room or venue is the useful part on a narrow timetable card.
func displayLocation(location string) string {
	value := strings.Join(strings.Fields(location), " ")
	parts := strings.FieldsFunc(value, func(r rune) bool {
		return r == '>' || r == '＞'
	})
	if len(parts) > 0 {
		value = strings.TrimSpace(parts[len(parts)-1])
	}

	for _, separator := range []string{"-", "－", "—"} {
		index := strings.LastIndex(value, separator)
		if index < 0 {
			continue
		}
		candidate := strings.TrimSpace(value[index+len(separator):])
		if containsDigit(candidate) {
			value = candidate
			break
		}
	}
	value = strings.TrimSpace(value)
	for _, prefix := range []string{"教室：", "教室:", "教室"} {
		if strings.HasPrefix(value, prefix) && len(value) > len(prefix) {
			value = strings.TrimSpace(value[len(prefix):])
			break
		}
	}
	return value
}

func containsDigit(value string) bool {
	for _, r := range value {
		if unicode.IsDigit(r) {
			return true
		}
	}
	return false
}

func normalizedPositiveInts(values []int) []int {
	seen := make(map[int]struct{}, len(values))
	result := make([]int, 0, len(values))
	for _, value := range values {
		if value <= 0 {
			continue
		}
		if _, found := seen[value]; found {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	sort.Ints(result)
	return result
}

func splitNames(value string) []string {
	parts := strings.FieldsFunc(value, func(r rune) bool {
		return r == ',' || r == '，' || r == '、' || r == ';' || r == '；'
	})
	for index := range parts {
		parts[index] = strings.TrimSpace(parts[index])
	}
	return uniqueStrings(parts)
}

func normalizeJoinedNames(value string) string {
	return strings.Join(splitNames(value), ", ")
}

func mergeJoinedNames(existing string, added string) string {
	return strings.Join(uniqueStrings(append(splitNames(existing), splitNames(added)...)), ", ")
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if _, found := seen[value]; found {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}

func clockTime(value string) string {
	value = strings.TrimSpace(value)
	if len(value) >= 5 {
		return value[:5]
	}
	return value
}
