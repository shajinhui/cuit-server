package schedule

import (
	"context"
	"errors"
	"testing"

	"cuit-server/pkg/jwxt"
)

type switchingTestSource struct {
	userID     int64
	eams       jwxt.CourseTable
	labms      jwxt.CourseTable
	eamsErr    error
	labmsErr   error
	eamsCalls  int
	labmsCalls int
}

func (s *switchingTestSource) ResolveUserID(context.Context, string) (int64, error) {
	return s.userID, nil
}

func (s *switchingTestSource) GetCourseTable(context.Context, string, string) (jwxt.CourseTable, error) {
	s.eamsCalls++
	return s.eams, s.eamsErr
}

func (s *switchingTestSource) GetLABMSCourseTable(context.Context, string, string) (jwxt.CourseTable, error) {
	s.labmsCalls++
	return s.labms, s.labmsErr
}

func (s *switchingTestSource) GetClassroomOptions(context.Context, string, string, string) (jwxt.ClassroomOptions, error) {
	return jwxt.ClassroomOptions{}, nil
}

func (s *switchingTestSource) GetAvailableClassrooms(context.Context, string, jwxt.AvailableClassroomQuery) ([]jwxt.Classroom, error) {
	return nil, nil
}

func (s *switchingTestSource) GetClassroomSchedule(context.Context, string, string, string) (jwxt.ClassroomSchedule, error) {
	return jwxt.ClassroomSchedule{}, nil
}

func TestShadowSourceReturnsEAMSAndQueriesLABMS(t *testing.T) {
	source := &switchingTestSource{
		userID: 1,
		eams:   jwxt.CourseTable{SemesterID: "1106", Courses: []jwxt.Course{{Name: "EAMS"}}},
		labms:  jwxt.CourseTable{SemesterID: "1106", Courses: []jwxt.Course{{Name: "LABMS"}}},
	}
	service, err := NewSwitchingCourseTableService(source, SwitchingSourceConfig{Mode: SourceModeShadow, RolloutPercent: 10})
	if err != nil {
		t.Fatal(err)
	}
	table, err := service.GetCourseTable(context.Background(), "session", "1106")
	if err != nil || table.Courses[0].Name != "EAMS" {
		t.Fatalf("shadow mode did not return EAMS: table=%+v err=%v", table, err)
	}
	if source.eamsCalls != 1 || source.labmsCalls != 1 {
		t.Fatalf("unexpected source calls: eams=%d labms=%d", source.eamsCalls, source.labmsCalls)
	}
}

func TestPrimarySourceFallsBackToEAMS(t *testing.T) {
	source := &switchingTestSource{
		userID:   1,
		eams:     jwxt.CourseTable{SemesterID: "1106", Courses: []jwxt.Course{{Name: "EAMS"}}},
		labmsErr: errors.New("LABMS unavailable"),
	}
	service, err := NewSwitchingCourseTableService(source, SwitchingSourceConfig{Mode: SourceModePrimary, RolloutPercent: 100})
	if err != nil {
		t.Fatal(err)
	}
	table, err := service.GetCourseTable(context.Background(), "session", "1106")
	if err != nil || table.Courses[0].Name != "EAMS" {
		t.Fatalf("primary fallback failed: table=%+v err=%v", table, err)
	}
	if source.labmsCalls != 1 || source.eamsCalls != 1 {
		t.Fatalf("unexpected source calls: eams=%d labms=%d", source.eamsCalls, source.labmsCalls)
	}
}

func TestPrimarySourceReturnsLABMSForSelectedCohort(t *testing.T) {
	source := &switchingTestSource{
		userID: 42,
		eams:   jwxt.CourseTable{Courses: []jwxt.Course{{Name: "EAMS"}}},
		labms:  jwxt.CourseTable{Courses: []jwxt.Course{{Name: "LABMS"}}},
	}
	service, err := NewSwitchingCourseTableService(source, SwitchingSourceConfig{Mode: SourceModePrimary, RolloutPercent: 50})
	if err != nil {
		t.Fatal(err)
	}
	table, err := service.GetCourseTable(context.Background(), "session", "1106")
	if err != nil || table.Courses[0].Name != "LABMS" {
		t.Fatalf("selected cohort did not receive LABMS: table=%+v err=%v", table, err)
	}
	if source.labmsCalls != 1 || source.eamsCalls != 0 {
		t.Fatalf("unexpected source calls: eams=%d labms=%d", source.eamsCalls, source.labmsCalls)
	}
}

func TestRolloutExcludesUsersOutsidePercentage(t *testing.T) {
	source := &switchingTestSource{
		userID: 51,
		eams:   jwxt.CourseTable{Courses: []jwxt.Course{{Name: "EAMS"}}},
		labms:  jwxt.CourseTable{Courses: []jwxt.Course{{Name: "LABMS"}}},
	}
	service, err := NewSwitchingCourseTableService(source, SwitchingSourceConfig{Mode: SourceModePrimary, RolloutPercent: 50})
	if err != nil {
		t.Fatal(err)
	}
	table, err := service.GetCourseTable(context.Background(), "session", "1106")
	if err != nil || table.Courses[0].Name != "EAMS" {
		t.Fatalf("excluded cohort did not receive EAMS: table=%+v err=%v", table, err)
	}
	if source.eamsCalls != 1 || source.labmsCalls != 0 {
		t.Fatalf("unexpected source calls: eams=%d labms=%d", source.eamsCalls, source.labmsCalls)
	}
}

func TestComparisonCountsSectionsAndLocations(t *testing.T) {
	eams := jwxt.CourseTable{WeekCount: 18, Courses: []jwxt.Course{
		{Code: "C1", Activities: []jwxt.CourseActivity{
			{Weekday: 1, StartSection: 1, EndSection: 2, Weeks: []int{1, 2}, RoomName: "A"},
		}},
	}}
	labms := jwxt.CourseTable{WeekCount: 18, Courses: []jwxt.Course{
		{Code: "C1", Activities: []jwxt.CourseActivity{
			{Weekday: 1, StartSection: 1, EndSection: 2, Weeks: []int{1, 3}, RoomName: "B"},
			{Weekday: 3, StartSection: 10, EndSection: 12, Weeks: []int{6, 7}, RoomName: "C"},
		}},
	}}
	comparison := CompareCourseTables(eams, labms)
	if comparison.EAMSCourses != 1 || comparison.LABMSCourses != 1 || comparison.WeekMismatches != 1 || comparison.SectionMismatches != 1 || comparison.LocationMismatches != 1 || !comparison.WeekCountEqual {
		t.Fatalf("unexpected comparison: %+v", comparison)
	}
}
