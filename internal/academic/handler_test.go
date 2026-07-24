package academic

import (
	"bytes"
	"context"
	"strings"
	"testing"

	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

type fakeGradeService struct{}

func (fakeGradeService) Login(context.Context, string, string) (string, error) {
	return "test-session", nil
}

func (fakeGradeService) GetStudentProfile(context.Context, string) (jwxt.StudentProfile, error) {
	return jwxt.StudentProfile{
		StudentNo:     "test-student",
		Name:          "测试同学",
		Gender:        "男",
		College:       "测试学院",
		Major:         "测试专业",
		ClassName:     "测试班",
		StudentStatus: "注册学籍",
	}, nil
}

func (fakeGradeService) GetPlanCompletion(context.Context, string) (jwxt.PlanCompletion, error) {
	return jwxt.PlanCompletion{
		Summary: jwxt.PlanCompletionSummary{
			StudentNo:       "test-student",
			RequiredCredits: "160",
			EarnedCredits:   "100",
		},
		Items: []jwxt.PlanCompletionItem{
			{
				Kind:            jwxt.PlanCompletionRequirement,
				Name:            "一 测试必修",
				RequiredCredits: "10",
				EarnedCredits:   "8",
				Status:          "缺 2 学分",
			},
			{
				Kind:       jwxt.PlanCompletionCourse,
				Sequence:   "1",
				CourseCode: "TEST001",
				Name:       "测试课程",
				Status:     "是",
			},
		},
	}, nil
}

func (fakeGradeService) ListSemesters(context.Context, string) ([]jwxt.Semester, error) {
	return nil, ErrUnauthenticated
}

func (fakeGradeService) GetGrades(context.Context, string, string) ([]jwxt.Grade, error) {
	return nil, ErrUnauthenticated
}

func (fakeGradeService) GetExams(context.Context, string, string, string) ([]jwxt.Exam, error) {
	return []jwxt.Exam{{
		CourseSequence: "COURSE001.001",
		CourseName:     "示例课程",
		ExamType:       "期末考试",
		ExamDate:       "2026-01-10",
		ExamTime:       "09:30~11:30",
		Location:       "A101",
		ExamRoomID:     "8001",
		Credits:        "2",
		Status:         "正常",
	}}, nil
}

func (fakeGradeService) Authenticated(_ context.Context, sessionID string) (bool, error) {
	return sessionID == "test-session", nil
}

func (fakeGradeService) Logout(context.Context, string) error { return nil }

func TestLoginSetsHttpOnlySessionCookie(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)
	body := []byte(`{"username":"20240001","password":"secret"}`)

	recorder := ut.PerformRequest(
		h.Engine,
		"POST",
		"/api/v1/jwxt/session",
		&ut.Body{Body: bytes.NewReader(body), Len: len(body)},
		ut.Header{Key: "Content-Type", Value: "application/json"},
	)
	response := recorder.Result()
	if response.StatusCode() != 200 {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
	cookie := string(response.Header.Peek("Set-Cookie"))
	if !strings.Contains(cookie, "campus_session=test-session") ||
		!strings.Contains(cookie, "HttpOnly") ||
		!strings.Contains(strings.ToLower(cookie), "max-age=") {
		t.Fatalf("session cookie is missing required attributes: %s", cookie)
	}
}

func TestSemestersRequiresAuthenticatedSession(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	recorder := ut.PerformRequest(h.Engine, "GET", "/api/v1/jwxt/semesters", nil)
	response := recorder.Result()
	if response.StatusCode() != 401 {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
	if !strings.Contains(string(response.Body()), `"code":40101`) {
		t.Fatalf("unexpected response: %s", response.Body())
	}
}

func TestSessionStatusDoesNotCallRemoteSystem(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	recorder := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/session",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
	)
	response := recorder.Result()
	if response.StatusCode() != 200 || !strings.Contains(string(response.Body()), `"authenticated":true`) {
		t.Fatalf("unexpected response: %s", response.Body())
	}
	if !strings.Contains(string(response.Header.Peek("Set-Cookie")), "campus_session=test-session") {
		t.Fatal("authenticated session should refresh its persistent cookie")
	}
}

func TestProfileReturnsAuthenticatedStudent(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	recorder := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/profile",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
	)
	response := recorder.Result()
	body := string(response.Body())
	if response.StatusCode() != 200 ||
		!strings.Contains(body, `"StudentNo":"test-student"`) ||
		!strings.Contains(body, `"Gender":"男"`) ||
		!strings.Contains(body, `"College":"测试学院"`) ||
		!strings.Contains(body, `"ClassName":"测试班"`) ||
		!strings.Contains(body, `"StudentStatus":"注册学籍"`) {
		t.Fatalf("unexpected response: %s", response.Body())
	}
}

func TestPlanCompletionReturnsSummaryAndItems(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	recorder := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/plan-completion",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
	)
	response := recorder.Result()
	body := string(response.Body())
	if response.StatusCode() != 200 ||
		!strings.Contains(body, `"RequiredCredits":"160"`) ||
		!strings.Contains(body, `"Kind":"requirement"`) ||
		!strings.Contains(body, `"CourseCode":"TEST001"`) {
		t.Fatalf("unexpected response: %s", response.Body())
	}
}

func TestExamsReturnsExamRoomData(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	response := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/jwxt/exams?semester_id=906&exam_type=final",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
	).Result()
	body := string(response.Body())
	if response.StatusCode() != 200 ||
		!strings.Contains(body, `"CourseName":"示例课程"`) ||
		!strings.Contains(body, `"Location":"A101"`) ||
		!strings.Contains(body, `"ExamRoomID":"8001"`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), body)
	}
}

func TestExamEndpointRequiresQueryParameter(t *testing.T) {
	h := server.Default()
	NewHandler(fakeGradeService{}, false).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/jwxt/exams", nil).Result()
	if response.StatusCode() != 400 || !strings.Contains(string(response.Body()), `"code":40000`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}
