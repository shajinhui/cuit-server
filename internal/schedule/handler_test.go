package schedule

import (
	"context"
	"strings"
	"testing"

	"cuit-server/internal/academic"
	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

type fakeCourseTableService struct {
	table             jwxt.CourseTable
	options           jwxt.ClassroomOptions
	rooms             []jwxt.Classroom
	classroomSchedule jwxt.ClassroomSchedule
	err               error
	availableQuery    func(jwxt.AvailableClassroomQuery)
	scheduleQuery     func(string, string)
}

type fakeCurrentWeekService struct {
	week CurrentWeek
	err  error
}

func (f fakeCurrentWeekService) GetCurrentWeek(context.Context) (CurrentWeek, error) {
	return f.week, f.err
}

func (f fakeCourseTableService) GetCourseTable(context.Context, string, string) (jwxt.CourseTable, error) {
	return f.table, f.err
}

func (f fakeCourseTableService) GetClassroomOptions(context.Context, string, string, string) (jwxt.ClassroomOptions, error) {
	return f.options, f.err
}

func (f fakeCourseTableService) GetAvailableClassrooms(
	_ context.Context,
	_ string,
	query jwxt.AvailableClassroomQuery,
) ([]jwxt.Classroom, error) {
	if f.availableQuery != nil {
		f.availableQuery(query)
	}
	return f.rooms, f.err
}

func (f fakeCourseTableService) GetClassroomSchedule(
	_ context.Context,
	_ string,
	semesterID string,
	campusID string,
) (jwxt.ClassroomSchedule, error) {
	if f.scheduleQuery != nil {
		f.scheduleQuery(semesterID, campusID)
	}
	return f.classroomSchedule, f.err
}

func TestCourseTableEndpointReturnsSchedule(t *testing.T) {
	h := server.Default()
	service := fakeCourseTableService{table: jwxt.CourseTable{
		SemesterID: "1106",
		WeekCount:  19,
		Courses:    []jwxt.Course{{Code: "COURSE001", Name: "示例课程"}},
	}}
	NewHandler(service, fakeCurrentWeekService{}).Register(h)

	recorder := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/course-table?semester_id=1106",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
	)
	response := recorder.Result()
	if response.StatusCode() != 200 {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
	body := string(response.Body())
	if !strings.Contains(body, `"SemesterID":"1106"`) || !strings.Contains(body, `"Code":"COURSE001"`) {
		t.Fatalf("unexpected response: %s", body)
	}
}

func TestCourseTableEndpointRequiresSemester(t *testing.T) {
	h := server.Default()
	NewHandler(fakeCourseTableService{}, fakeCurrentWeekService{}).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/jwxt/course-table", nil).Result()
	if response.StatusCode() != 400 || !strings.Contains(string(response.Body()), `"code":40000`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}

func TestCourseTableEndpointRequiresAuthenticatedSession(t *testing.T) {
	h := server.Default()
	NewHandler(fakeCourseTableService{err: academic.ErrUnauthenticated}, fakeCurrentWeekService{}).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/jwxt/course-table?semester_id=1106", nil).Result()
	if response.StatusCode() != 401 || !strings.Contains(string(response.Body()), `"code":40101`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}

func TestCurrentWeekEndpointReturnsWeek(t *testing.T) {
	h := server.Default()
	NewHandler(fakeCourseTableService{}, fakeCurrentWeekService{week: CurrentWeek{CurrentWeek: 21}}).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/schedule/current-week", nil).Result()
	if response.StatusCode() != 200 || !strings.Contains(string(response.Body()), `"CurrentWeek":21`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}

func TestClassroomOptionsEndpointReturnsOptions(t *testing.T) {
	h := server.Default()
	service := fakeCourseTableService{options: jwxt.ClassroomOptions{
		Campuses:       []jwxt.ClassroomOption{{ID: "1", Name: "航空港"}},
		ClassroomTypes: []jwxt.ClassroomOption{{ID: "2", Name: "多媒体"}},
		Buildings:      []jwxt.ClassroomOption{{ID: "2", Name: "航空港第二教学楼"}},
	}}
	NewHandler(service, fakeCurrentWeekService{}).Register(h)

	response := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/classroom-options?semester_id=905&campus_id=1",
		nil,
	).Result()
	body := string(response.Body())
	if response.StatusCode() != 200 ||
		!strings.Contains(body, `"Name":"航空港"`) ||
		!strings.Contains(body, `"Name":"航空港第二教学楼"`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), body)
	}
}

func TestAvailableClassroomsEndpointParsesQuery(t *testing.T) {
	h := server.Default()
	service := fakeCourseTableService{
		rooms: []jwxt.Classroom{{ID: "67", Name: "H2101", Capacity: 166}},
		availableQuery: func(query jwxt.AvailableClassroomQuery) {
			if query.SemesterID != "905" ||
				query.Week != 8 ||
				query.Weekday != 3 ||
				len(query.Sections) != 2 ||
				query.Sections[0] != 3 ||
				query.Sections[1] != 4 ||
				query.CampusID != "1" ||
				query.BuildingID != "2" ||
				query.ClassroomTypeID != "2" ||
				query.MinCapacity != 50 {
				t.Fatalf("unexpected available classroom query: %+v", query)
			}
		},
	}
	NewHandler(service, fakeCurrentWeekService{}).Register(h)

	response := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/available-classrooms?semester_id=905&week=8&weekday=3&sections=3,4&campus_id=1&building_id=2&classroom_type_id=2&min_capacity=50",
		nil,
	).Result()
	body := string(response.Body())
	if response.StatusCode() != 200 || !strings.Contains(body, `"Name":"H2101"`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), body)
	}
}

func TestAvailableClassroomsEndpointRejectsInvalidSections(t *testing.T) {
	h := server.Default()
	NewHandler(fakeCourseTableService{}, fakeCurrentWeekService{}).Register(h)

	response := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/available-classrooms?semester_id=905&week=8&weekday=3&sections=3,13&campus_id=1",
		nil,
	).Result()
	if response.StatusCode() != 400 || !strings.Contains(string(response.Body()), `"code":40000`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}

func TestClassroomScheduleEndpointReturnsWholeSemesterSnapshot(t *testing.T) {
	h := server.Default()
	service := fakeCourseTableService{
		classroomSchedule: jwxt.ClassroomSchedule{
			SemesterID: "905",
			CampusID:   "1",
			Rooms: []jwxt.ClassroomScheduleRoom{{
				Classroom: jwxt.Classroom{ID: "67", Name: "H2101"},
				Occupancies: []jwxt.ClassroomOccupancy{{
					Weekday:      1,
					StartSection: 1,
					EndSection:   2,
					Weeks:        []int{1, 2},
				}},
			}},
		},
		scheduleQuery: func(semesterID string, campusID string) {
			if semesterID != "905" || campusID != "1" {
				t.Fatalf("unexpected classroom schedule query: semester=%s campus=%s", semesterID, campusID)
			}
		},
	}
	NewHandler(service, fakeCurrentWeekService{}).Register(h)

	response := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/classroom-schedule?semester_id=905&campus_id=1",
		nil,
	).Result()
	body := string(response.Body())
	if response.StatusCode() != 200 ||
		!strings.Contains(body, `"SemesterID":"905"`) ||
		!strings.Contains(body, `"Occupancies":[{"Weekday":1`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), body)
	}
}

func TestClassroomScheduleEndpointRejectsInvalidCampus(t *testing.T) {
	h := server.Default()
	NewHandler(fakeCourseTableService{}, fakeCurrentWeekService{}).Register(h)

	response := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/classroom-schedule?semester_id=905&campus_id=invalid",
		nil,
	).Result()
	if response.StatusCode() != 400 || !strings.Contains(string(response.Body()), `"code":40000`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}
