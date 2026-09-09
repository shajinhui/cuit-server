package labms

import (
	"crypto/sha256"
	"encoding/hex"
	"sort"
	"strings"

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
				Name:          strings.TrimSpace(item.CourseName),
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
			RoomName:     strings.TrimSpace(item.Location),
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
	for _, value := range []string{string(item.CourseID), string(item.TaskID), item.CourseNo} {
		if value = strings.TrimSpace(value); value != "" {
			return value
		}
	}
	sum := sha256.Sum256([]byte(strings.TrimSpace(item.CourseName) + "\x00" + normalizeJoinedNames(item.ClassName)))
	return hex.EncodeToString(sum[:8])
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
