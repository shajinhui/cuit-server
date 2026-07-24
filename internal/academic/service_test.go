package academic

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"sync"
	"testing"
	"time"

	"cuit-server/pkg/jwxt"
)

type fakeJWXTClient struct {
	loginUsername        string
	loginPassword        string
	loginErr             error
	profile              jwxt.StudentProfile
	profileErr           error
	planCompletion       jwxt.PlanCompletion
	planErr              error
	grades               []jwxt.Grade
	gradeErr             error
	exams                []jwxt.Exam
	examErr              error
	courseTable          jwxt.CourseTable
	courseTableErr       error
	classroomOptions     jwxt.ClassroomOptions
	classroomOptionsErr  error
	availableRooms       []jwxt.Classroom
	availableRoomsErr    error
	availableQuery       jwxt.AvailableClassroomQuery
	classroomSchedule    jwxt.ClassroomSchedule
	classroomScheduleErr error
	scheduleSemesterID   string
	scheduleCampusID     string
	semesterStarted      chan struct{}
	semesterRelease      chan struct{}
}

func (f *fakeJWXTClient) Login(_ context.Context, username string, password string) error {
	f.loginUsername = username
	f.loginPassword = password
	return f.loginErr
}

func (f *fakeJWXTClient) GetStudentProfile(context.Context) (jwxt.StudentProfile, error) {
	if f.profile.Name == "" {
		f.profile = jwxt.StudentProfile{
			StudentNo: "test-student",
			Name:      "测试同学",
			Grade:     "2024",
			College:   "测试学院",
			Major:     "测试专业",
		}
	}
	return f.profile, f.profileErr
}

func (f *fakeJWXTClient) GetPlanCompletion(context.Context) (jwxt.PlanCompletion, error) {
	return f.planCompletion, f.planErr
}

func (f *fakeJWXTClient) ListSemesters(context.Context) ([]jwxt.Semester, error) {
	if f.semesterStarted != nil {
		f.semesterStarted <- struct{}{}
	}
	if f.semesterRelease != nil {
		<-f.semesterRelease
	}
	return []jwxt.Semester{{ID: "906", SchoolYear: "2025-2026", Term: "2"}}, nil
}

func (f *fakeJWXTClient) GetGrades(context.Context, string) ([]jwxt.Grade, error) {
	return f.grades, f.gradeErr
}

func (f *fakeJWXTClient) GetExamsByType(context.Context, string, string) ([]jwxt.Exam, error) {
	return f.exams, f.examErr
}

func (f *fakeJWXTClient) GetCourseTable(context.Context, string) (jwxt.CourseTable, error) {
	return f.courseTable, f.courseTableErr
}

func (f *fakeJWXTClient) GetClassroomOptions(context.Context, string, string) (jwxt.ClassroomOptions, error) {
	return f.classroomOptions, f.classroomOptionsErr
}

func (f *fakeJWXTClient) GetAvailableClassrooms(_ context.Context, query jwxt.AvailableClassroomQuery) ([]jwxt.Classroom, error) {
	f.availableQuery = query
	return f.availableRooms, f.availableRoomsErr
}

func (f *fakeJWXTClient) GetClassroomSchedule(
	_ context.Context,
	semesterID string,
	campusID string,
) (jwxt.ClassroomSchedule, error) {
	f.scheduleSemesterID = semesterID
	f.scheduleCampusID = campusID
	return f.classroomSchedule, f.classroomScheduleErr
}

func TestLoginPersistsEncryptedCredentialAndSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	client := &fakeJWXTClient{grades: []jwxt.Grade{{CourseName: "示例课程"}}}
	service := NewService(func() (JWXTClient, error) { return client, nil }, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), " test-student ", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	authenticated, err := service.Authenticated(context.Background(), sessionID)
	if err != nil || !authenticated {
		t.Fatalf("new session should be authenticated: authenticated=%v err=%v", authenticated, err)
	}
	stored := repository.users[1]
	if stored.StudentNo != "test-student" || string(stored.EncryptedPassword) == "test-password" {
		t.Fatalf("credential was not stored correctly")
	}
	if stored.Name != "测试同学" || stored.College != "测试学院" || stored.Major != "测试专业" || stored.EnrollmentYear != 2024 {
		t.Fatalf("profile was not stored correctly: %+v", stored)
	}
	grades, err := service.GetGrades(context.Background(), sessionID, "906")
	if err != nil || len(grades) != 1 {
		t.Fatalf("unexpected grades: grades=%+v err=%v", grades, err)
	}
	if repository.findCount() != 0 {
		t.Fatal("hot session requests should not query the repository")
	}
}

func TestQueryRestoresJWXTClientFromStoredSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{}
	service := NewService(func() (JWXTClient, error) { return initial, nil }, repository, credentials, time.Hour)
	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}

	restored := &fakeJWXTClient{}
	restartedService := NewService(func() (JWXTClient, error) { return restored, nil }, repository, credentials, time.Hour)
	if _, err := restartedService.ListSemesters(context.Background(), sessionID); err != nil {
		t.Fatal(err)
	}
	if restored.loginUsername != "test-student" || restored.loginPassword != "test-password" {
		t.Fatal("stored credential was not used to restore the JWXT client")
	}
}

func TestGradeQueryReloginsAfterEAMSSessionExpires(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{gradeErr: jwxt.ErrSessionExpired}
	restored := &fakeJWXTClient{grades: []jwxt.Grade{{CourseName: "恢复后的课程"}}}
	clients := []JWXTClient{initial, restored}
	service := NewService(func() (JWXTClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	grades, err := service.GetGrades(context.Background(), sessionID, "906")
	if err != nil {
		t.Fatal(err)
	}
	if len(grades) != 1 || grades[0].CourseName != "恢复后的课程" {
		t.Fatalf("unexpected grades after relogin: %+v", grades)
	}
	if restored.loginUsername != "test-student" {
		t.Fatal("replacement client was not logged in")
	}
}

func TestExamQueryReloginsAfterEAMSSessionExpires(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{examErr: jwxt.ErrSessionExpired}
	restored := &fakeJWXTClient{exams: []jwxt.Exam{{
		CourseName: "恢复后的考试",
		Location:   "A101",
	}}}
	clients := []JWXTClient{initial, restored}
	service := NewService(func() (JWXTClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	exams, err := service.GetExams(context.Background(), sessionID, "906", jwxt.ExamTypeFinal)
	if err != nil {
		t.Fatal(err)
	}
	if len(exams) != 1 || exams[0].Location != "A101" {
		t.Fatalf("unexpected exams after relogin: %+v", exams)
	}
	if restored.loginUsername != "test-student" {
		t.Fatal("replacement client was not logged in")
	}
}

func TestCourseTableQueryReloginsAfterEAMSSessionExpires(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{courseTableErr: jwxt.ErrSessionExpired}
	restored := &fakeJWXTClient{courseTable: jwxt.CourseTable{SemesterID: "1106", WeekCount: 19}}
	clients := []JWXTClient{initial, restored}
	service := NewService(func() (JWXTClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	table, err := service.GetCourseTable(context.Background(), sessionID, "1106")
	if err != nil {
		t.Fatal(err)
	}
	if table.SemesterID != "1106" || table.WeekCount != 19 {
		t.Fatalf("unexpected course table after relogin: %+v", table)
	}
	if restored.loginUsername != "test-student" {
		t.Fatal("replacement client was not logged in")
	}
}

func TestAvailableClassroomQueryReloginsAfterEAMSSessionExpires(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{availableRoomsErr: jwxt.ErrSessionExpired}
	restored := &fakeJWXTClient{availableRooms: []jwxt.Classroom{{ID: "67", Name: "H2101"}}}
	clients := []JWXTClient{initial, restored}
	service := NewService(func() (JWXTClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	rooms, err := service.GetAvailableClassrooms(context.Background(), sessionID, jwxt.AvailableClassroomQuery{
		SemesterID: "905",
		Week:       8,
		Weekday:    3,
		Sections:   []int{3, 4},
		CampusID:   "1",
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(rooms) != 1 || rooms[0].ID != "67" {
		t.Fatalf("unexpected classrooms after relogin: %+v", rooms)
	}
	if restored.loginUsername != "test-student" || restored.availableQuery.Week != 8 {
		t.Fatal("replacement client did not receive the classroom query")
	}
}

func TestClassroomScheduleQueryReloginsAfterEAMSSessionExpires(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{classroomScheduleErr: jwxt.ErrSessionExpired}
	restored := &fakeJWXTClient{classroomSchedule: jwxt.ClassroomSchedule{
		SemesterID: "905",
		CampusID:   "1",
		Rooms: []jwxt.ClassroomScheduleRoom{{
			Classroom: jwxt.Classroom{ID: "67", Name: "H2101"},
		}},
	}}
	clients := []JWXTClient{initial, restored}
	service := NewService(func() (JWXTClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	schedule, err := service.GetClassroomSchedule(context.Background(), sessionID, "905", "1")
	if err != nil {
		t.Fatal(err)
	}
	if len(schedule.Rooms) != 1 || schedule.Rooms[0].Classroom.ID != "67" {
		t.Fatalf("unexpected classroom schedule after relogin: %+v", schedule)
	}
	if restored.loginUsername != "test-student" ||
		restored.scheduleSemesterID != "905" ||
		restored.scheduleCampusID != "1" {
		t.Fatal("replacement client did not receive the classroom schedule query")
	}
}

func TestPlanCompletionQueryReloginsAfterEAMSSessionExpires(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{planErr: jwxt.ErrSessionExpired}
	restored := &fakeJWXTClient{planCompletion: jwxt.PlanCompletion{
		Summary: jwxt.PlanCompletionSummary{RequiredCredits: "160"},
		Items:   []jwxt.PlanCompletionItem{{Kind: jwxt.PlanCompletionRequirement}},
	}}
	clients := []JWXTClient{initial, restored}
	service := NewService(func() (JWXTClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Hour)

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	result, err := service.GetPlanCompletion(context.Background(), sessionID)
	if err != nil {
		t.Fatal(err)
	}
	if result.Summary.RequiredCredits != "160" || len(result.Items) != 1 {
		t.Fatalf("unexpected plan completion after relogin: %+v", result)
	}
	if restored.loginUsername != "test-student" {
		t.Fatal("replacement client was not logged in")
	}
}

func TestLoginReplacesPreviousSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	service := NewService(func() (JWXTClient, error) {
		return &fakeJWXTClient{}, nil
	}, repository, credentials, time.Hour)
	firstSession, err := service.Login(context.Background(), "test-student", "first-password")
	if err != nil {
		t.Fatal(err)
	}
	secondSession, err := service.Login(context.Background(), "test-student", "second-password")
	if err != nil {
		t.Fatal(err)
	}
	firstAuthenticated, err := service.Authenticated(context.Background(), firstSession)
	if err != nil {
		t.Fatal(err)
	}
	secondAuthenticated, err := service.Authenticated(context.Background(), secondSession)
	if err != nil {
		t.Fatal(err)
	}
	if firstAuthenticated || !secondAuthenticated {
		t.Fatalf("only the latest session should remain: first=%v second=%v", firstAuthenticated, secondAuthenticated)
	}
}

func TestIdleClientIsRecreatedWithoutExpiringApplicationSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	initial := &fakeJWXTClient{}
	restored := &fakeJWXTClient{grades: []jwxt.Grade{{CourseName: "重新登录后的课程"}}}
	clients := []JWXTClient{initial, restored}
	service := NewService(func() (JWXTClient, error) {
		client := clients[0]
		clients = clients[1:]
		return client, nil
	}, repository, credentials, time.Minute)
	now := time.Date(2026, 7, 21, 12, 0, 0, 0, time.Local)
	service.now = func() time.Time { return now }

	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	now = now.Add(2 * time.Minute)
	grades, err := service.GetGrades(context.Background(), sessionID, "906")
	if err != nil {
		t.Fatal(err)
	}
	if len(grades) != 1 || restored.loginUsername != "test-student" {
		t.Fatalf("idle client was not recreated: grades=%+v username=%q", grades, restored.loginUsername)
	}
	authenticated, err := service.Authenticated(context.Background(), sessionID)
	if err != nil || !authenticated {
		t.Fatalf("application session should remain valid: authenticated=%v err=%v", authenticated, err)
	}
}

func TestSameUserQueriesAreSerialized(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	client := &fakeJWXTClient{
		semesterStarted: make(chan struct{}, 2),
		semesterRelease: make(chan struct{}, 2),
	}
	service := NewService(func() (JWXTClient, error) { return client, nil }, repository, credentials, time.Hour)
	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}

	results := make(chan error, 2)
	go func() {
		_, queryErr := service.ListSemesters(context.Background(), sessionID)
		results <- queryErr
	}()
	<-client.semesterStarted
	go func() {
		_, queryErr := service.ListSemesters(context.Background(), sessionID)
		results <- queryErr
	}()

	select {
	case <-client.semesterStarted:
		t.Fatal("the second query entered the same client concurrently")
	case <-time.After(30 * time.Millisecond):
	}
	client.semesterRelease <- struct{}{}
	<-client.semesterStarted
	client.semesterRelease <- struct{}{}
	for range 2 {
		if err := <-results; err != nil {
			t.Fatal(err)
		}
	}
}

func TestInvalidStoredCredentialRemovesSession(t *testing.T) {
	repository := newMemoryRepository()
	credentials := testCredentialCipher(t)
	service := NewService(func() (JWXTClient, error) { return &fakeJWXTClient{}, nil }, repository, credentials, time.Hour)
	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}

	restartedService := NewService(func() (JWXTClient, error) {
		return &fakeJWXTClient{loginErr: jwxt.ErrInvalidCredentials}, nil
	}, repository, credentials, time.Hour)
	if _, err := restartedService.ListSemesters(context.Background(), sessionID); !errors.Is(err, jwxt.ErrInvalidCredentials) {
		t.Fatalf("expected invalid credentials, got %v", err)
	}
	authenticated, err := restartedService.Authenticated(context.Background(), sessionID)
	if err != nil || authenticated {
		t.Fatalf("invalid stored credential should remove session: authenticated=%v err=%v", authenticated, err)
	}
}

func testCredentialCipher(t *testing.T) *CredentialCipher {
	t.Helper()
	key := base64.StdEncoding.EncodeToString(make([]byte, 32))
	credentials, err := NewCredentialCipher(key)
	if err != nil {
		t.Fatal(err)
	}
	return credentials
}

type memoryRepository struct {
	mu         sync.Mutex
	users      map[int64]StoredUser
	studentIDs map[string]int64
	sessions   map[[sha256.Size]byte]int64
	userTokens map[int64][sha256.Size]byte
	nextUserID int64
	findCalls  int
}

func newMemoryRepository() *memoryRepository {
	return &memoryRepository{
		users:      make(map[int64]StoredUser),
		studentIDs: make(map[string]int64),
		sessions:   make(map[[sha256.Size]byte]int64),
		userTokens: make(map[int64][sha256.Size]byte),
	}
}

func (r *memoryRepository) UpsertLogin(
	_ context.Context,
	loginUser LoginUser,
	encryptedPassword []byte,
	tokenHash [sha256.Size]byte,
	_ time.Time,
) (int64, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	userID := r.studentIDs[loginUser.StudentNo]
	if userID == 0 {
		r.nextUserID++
		userID = r.nextUserID
		r.studentIDs[loginUser.StudentNo] = userID
	}
	r.users[userID] = StoredUser{
		ID:                userID,
		StudentNo:         loginUser.StudentNo,
		Name:              loginUser.Name,
		College:           loginUser.College,
		Major:             loginUser.Major,
		EnrollmentYear:    loginUser.EnrollmentYear,
		EncryptedPassword: append([]byte(nil), encryptedPassword...),
	}
	if oldToken, ok := r.userTokens[userID]; ok {
		delete(r.sessions, oldToken)
	}
	r.sessions[tokenHash] = userID
	r.userTokens[userID] = tokenHash
	return userID, nil
}

func (r *memoryRepository) FindUserBySession(_ context.Context, tokenHash [sha256.Size]byte) (StoredUser, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.findCalls++
	userID, ok := r.sessions[tokenHash]
	if !ok {
		return StoredUser{}, ErrStoredSessionNotFound
	}
	user := r.users[userID]
	user.EncryptedPassword = append([]byte(nil), user.EncryptedPassword...)
	return user, nil
}

func (r *memoryRepository) ClearSession(_ context.Context, tokenHash [sha256.Size]byte) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	userID := r.sessions[tokenHash]
	delete(r.sessions, tokenHash)
	if r.userTokens[userID] == tokenHash {
		delete(r.userTokens, userID)
	}
	return nil
}

func (r *memoryRepository) findCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.findCalls
}
