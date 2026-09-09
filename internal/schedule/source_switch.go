package schedule

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sort"
	"strings"

	"cuit-server/pkg/jwxt"
)

type SourceMode string

const (
	SourceModeOff     SourceMode = "off"
	SourceModeShadow  SourceMode = "shadow"
	SourceModePrimary SourceMode = "primary"
)

type SwitchingSourceConfig struct {
	Mode           SourceMode
	RolloutPercent int
}

type switchingSource interface {
	GetCourseTable(ctx context.Context, sessionID string, semesterID string) (jwxt.CourseTable, error)
	GetClassroomOptions(ctx context.Context, sessionID string, semesterID string, campusID string) (jwxt.ClassroomOptions, error)
	GetAvailableClassrooms(ctx context.Context, sessionID string, query jwxt.AvailableClassroomQuery) ([]jwxt.Classroom, error)
	GetClassroomSchedule(ctx context.Context, sessionID string, semesterID string, campusID string) (jwxt.ClassroomSchedule, error)
	GetLABMSCourseTable(ctx context.Context, sessionID string, semesterID string) (jwxt.CourseTable, error)
	ResolveUserID(ctx context.Context, sessionID string) (int64, error)
}

// SwitchingCourseTableService 只切换个人课表；公共教室能力始终委托给原 EAMS 数据源。
type SwitchingCourseTableService struct {
	source switchingSource
	config SwitchingSourceConfig
}

func NewSwitchingCourseTableService(source switchingSource, config SwitchingSourceConfig) (*SwitchingCourseTableService, error) {
	if config.Mode == "" {
		config.Mode = SourceModeOff
	}
	if config.Mode != SourceModeOff && config.Mode != SourceModeShadow && config.Mode != SourceModePrimary {
		return nil, errors.New("schedule: invalid LABMS source mode")
	}
	if config.RolloutPercent < 0 || config.RolloutPercent > 100 {
		return nil, errors.New("schedule: LABMS rollout percent must be between 0 and 100")
	}
	return &SwitchingCourseTableService{source: source, config: config}, nil
}

func (s *SwitchingCourseTableService) GetCourseTable(ctx context.Context, sessionID string, semesterID string) (jwxt.CourseTable, error) {
	if s.config.Mode == SourceModeOff || !s.inRollout(ctx, sessionID) {
		return s.source.GetCourseTable(ctx, sessionID, semesterID)
	}
	switch s.config.Mode {
	case SourceModeShadow:
		eams, err := s.source.GetCourseTable(ctx, sessionID, semesterID)
		if err != nil {
			return jwxt.CourseTable{}, err
		}
		labms, labmsErr := s.source.GetLABMSCourseTable(ctx, sessionID, semesterID)
		if labmsErr != nil {
			log.Printf("LABMS 影子课表查询失败: semester_id=%s: %v", semesterID, labmsErr)
			return eams, nil
		}
		comparison := CompareCourseTables(eams, labms)
		log.Printf(
			"LABMS 影子课表对比: semester_id=%s eams_courses=%d labms_courses=%d eams_activities=%d labms_activities=%d week_count_equal=%t week_mismatches=%d section_mismatches=%d location_mismatches=%d",
			semesterID,
			comparison.EAMSCourses,
			comparison.LABMSCourses,
			comparison.EAMSActivities,
			comparison.LABMSActivities,
			comparison.WeekCountEqual,
			comparison.WeekMismatches,
			comparison.SectionMismatches,
			comparison.LocationMismatches,
		)
		return eams, nil
	case SourceModePrimary:
		labms, err := s.source.GetLABMSCourseTable(ctx, sessionID, semesterID)
		if err == nil {
			return labms, nil
		}
		log.Printf("LABMS 主课表查询失败，回退 EAMS: semester_id=%s: %v", semesterID, err)
		return s.source.GetCourseTable(ctx, sessionID, semesterID)
	default:
		return s.source.GetCourseTable(ctx, sessionID, semesterID)
	}
}

func (s *SwitchingCourseTableService) inRollout(ctx context.Context, sessionID string) bool {
	if s.config.RolloutPercent == 0 {
		return false
	}
	userID, err := s.source.ResolveUserID(ctx, sessionID)
	if err != nil {
		return false
	}
	return int((userID%100+100)%100) < s.config.RolloutPercent
}

func (s *SwitchingCourseTableService) ResolveUserID(ctx context.Context, sessionID string) (int64, error) {
	return s.source.ResolveUserID(ctx, sessionID)
}

func (s *SwitchingCourseTableService) GetClassroomOptions(ctx context.Context, sessionID string, semesterID string, campusID string) (jwxt.ClassroomOptions, error) {
	return s.source.GetClassroomOptions(ctx, sessionID, semesterID, campusID)
}

func (s *SwitchingCourseTableService) GetAvailableClassrooms(ctx context.Context, sessionID string, query jwxt.AvailableClassroomQuery) ([]jwxt.Classroom, error) {
	return s.source.GetAvailableClassrooms(ctx, sessionID, query)
}

func (s *SwitchingCourseTableService) GetClassroomSchedule(ctx context.Context, sessionID string, semesterID string, campusID string) (jwxt.ClassroomSchedule, error) {
	return s.source.GetClassroomSchedule(ctx, sessionID, semesterID, campusID)
}

type CourseTableComparison struct {
	EAMSCourses        int
	LABMSCourses       int
	EAMSActivities     int
	LABMSActivities    int
	WeekCountEqual     bool
	WeekMismatches     int
	SectionMismatches  int
	LocationMismatches int
}

func CompareCourseTables(eams jwxt.CourseTable, labms jwxt.CourseTable) CourseTableComparison {
	comparison := CourseTableComparison{
		EAMSCourses:     len(eams.Courses),
		LABMSCourses:    len(labms.Courses),
		EAMSActivities:  activityCount(eams),
		LABMSActivities: activityCount(labms),
		WeekCountEqual:  eams.WeekCount == labms.WeekCount,
	}
	comparison.WeekMismatches = compareCourseDimensions(courseDimensions(eams, dimensionWeeks), courseDimensions(labms, dimensionWeeks))
	comparison.SectionMismatches = compareCourseDimensions(courseDimensions(eams, dimensionSections), courseDimensions(labms, dimensionSections))
	comparison.LocationMismatches = compareCourseDimensions(courseDimensions(eams, dimensionLocations), courseDimensions(labms, dimensionLocations))
	return comparison
}

func activityCount(table jwxt.CourseTable) int {
	count := 0
	for _, course := range table.Courses {
		count += len(course.Activities)
	}
	return count
}

type comparisonDimension int

const (
	dimensionWeeks comparisonDimension = iota
	dimensionSections
	dimensionLocations
)

// 影子比较以课程编号（缺失时用课程名）归组，再分别比较周次、节次和地点集合。
// 三个维度独立计算，避免“只改了周次”同时被误报为节次变化。
func courseDimensions(table jwxt.CourseTable, dimension comparisonDimension) map[string][]string {
	result := make(map[string][]string)
	for _, course := range table.Courses {
		identity := strings.TrimSpace(course.Code)
		if identity == "" {
			identity = strings.TrimSpace(course.Name)
		}
		values := make(map[string]struct{})
		for _, activity := range course.Activities {
			var value string
			switch dimension {
			case dimensionWeeks:
				weeks := append([]int(nil), activity.Weeks...)
				sort.Ints(weeks)
				value = fmt.Sprint(weeks)
			case dimensionSections:
				value = fmt.Sprintf("%d|%d|%d", activity.Weekday, activity.StartSection, activity.EndSection)
			case dimensionLocations:
				value = strings.TrimSpace(activity.RoomName)
			}
			values[value] = struct{}{}
		}
		for value := range values {
			result[identity] = append(result[identity], value)
		}
		sort.Strings(result[identity])
	}
	return result
}

func compareCourseDimensions(left map[string][]string, right map[string][]string) int {
	mismatches := 0
	identities := make(map[string]struct{}, len(left)+len(right))
	for identity := range left {
		identities[identity] = struct{}{}
	}
	for identity := range right {
		identities[identity] = struct{}{}
	}
	for identity := range identities {
		if strings.Join(left[identity], "\x00") != strings.Join(right[identity], "\x00") {
			mismatches++
		}
	}
	return mismatches
}
