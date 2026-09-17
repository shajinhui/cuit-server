package library

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"net/http"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"cuit-server/internal/platform/database"
	"cuit-server/migrations"
	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

type fakeLibraryService struct {
	seats         []jwxt.LibrarySeat
	reservations  []jwxt.LibraryReservation
	createRequest *jwxt.LibraryCreateReservationRequest
	err           error
	userID        int64
	renewal       jwxt.LibraryRenewalOptions
	renewRequest  *renewalRequest
}

func (service *fakeLibraryService) ResolveUserID(context.Context, string) (int64, error) {
	if service.userID == 0 {
		return 1, service.err
	}
	return service.userID, service.err
}

func (service *fakeLibraryService) GetLibraryCapabilities(context.Context, string) (jwxt.LibraryCapabilities, error) {
	return jwxt.LibraryCapabilities{CaptchaMode: "none", OfficialURL: "https://example.test/library"}, service.err
}

func (service *fakeLibraryService) ListLibraryAreas(context.Context, string, string) ([]jwxt.LibraryArea, error) {
	return []jwxt.LibraryArea{{ID: "7", Name: "二楼", Leaf: true}}, service.err
}

func (service *fakeLibraryService) ListLibrarySeats(
	context.Context,
	string,
	jwxt.LibrarySeatQuery,
) ([]jwxt.LibrarySeat, error) {
	return service.seats, service.err
}

func (service *fakeLibraryService) ListLibraryReservations(
	context.Context,
	string,
	jwxt.LibraryReservationQuery,
) ([]jwxt.LibraryReservation, error) {
	return service.reservations, service.err
}

func (service *fakeLibraryService) CreateLibraryReservation(
	_ context.Context,
	_ string,
	request jwxt.LibraryCreateReservationRequest,
) (jwxt.LibraryOperationResult, error) {
	service.createRequest = &request
	return jwxt.LibraryOperationResult{Message: "预约成功"}, service.err
}

func (service *fakeLibraryService) CancelLibraryReservation(context.Context, string, string) (jwxt.LibraryOperationResult, error) {
	return jwxt.LibraryOperationResult{Message: "预约已取消"}, service.err
}

func (service *fakeLibraryService) FinishLibraryReservation(context.Context, string, string) (jwxt.LibraryOperationResult, error) {
	return jwxt.LibraryOperationResult{Message: "预约已结束"}, service.err
}

func (service *fakeLibraryService) TemporaryLeaveLibraryReservation(context.Context, string, string) (jwxt.LibraryOperationResult, error) {
	return jwxt.LibraryOperationResult{Message: "已登记暂离"}, service.err
}

func (service *fakeLibraryService) GetLibraryRenewalOptions(context.Context, string, string) (jwxt.LibraryRenewalOptions, error) {
	if len(service.renewal.Durations) == 0 {
		return jwxt.LibraryRenewalOptions{MinimumMinutes: 30, MaximumMinutes: 90, IntervalMinutes: 30, Durations: []int{30, 60, 90}}, service.err
	}
	return service.renewal, service.err
}

func (service *fakeLibraryService) RenewLibraryReservation(_ context.Context, _ string, _ string, duration int) (jwxt.LibraryOperationResult, error) {
	service.renewRequest = &renewalRequest{DurationMinutes: duration}
	return jwxt.LibraryOperationResult{Message: "续座成功"}, service.err
}

func (service *fakeLibraryService) GetLibraryCaptcha(context.Context, string) (jwxt.LibraryCaptcha, error) {
	return jwxt.LibraryCaptcha{ContentType: "image/png", Data: []byte("png")}, service.err
}

func (service *fakeLibraryService) GetLibrarySeatMap(context.Context, string, string) (jwxt.LibrarySeatMap, error) {
	return jwxt.LibrarySeatMap{ContentType: "image/jpeg", Data: []byte("floor-plan")}, service.err
}

func TestSeatEndpointReturnsNormalizedSeats(t *testing.T) {
	service := &fakeLibraryService{seats: []jwxt.LibrarySeat{{ID: "18", Number: "A-18", Status: "available"}}}
	h := server.Default()
	NewHandler(service).Register(h)

	response := ut.PerformRequest(
		h.Engine,
		"GET",
		"/api/v1/library/seats?kind=seat&room_id=7&start_date=2026-09-16&end_date=2026-09-16&start_time=09%3A00&end_time=11%3A00",
		nil,
		ut.Header{Key: "Cookie", Value: "campus_session=test-session"},
	).Result()
	if response.StatusCode() != 200 || !strings.Contains(string(response.Body()), `"Number":"A-18"`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}

func TestCreateReservationBindsExplicitPayload(t *testing.T) {
	service := &fakeLibraryService{}
	h := server.Default()
	NewHandler(service).Register(h)
	body := []byte(`{"Kind":"seat","RoomID":"7","SeatID":"18","StartDate":"2026-09-16","EndDate":"2026-09-16","StartTime":"09:00","EndTime":"11:00","Memo":"学习","Captcha":"ABCD"}`)

	response := ut.PerformRequest(
		h.Engine,
		"POST",
		"/api/v1/library/reservations",
		&ut.Body{Body: bytes.NewReader(body), Len: len(body)},
		ut.Header{Key: "Content-Type", Value: "application/json"},
	).Result()
	if response.StatusCode() != 200 || service.createRequest == nil {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
	if service.createRequest.SeatID != "18" || service.createRequest.Memo != "学习" {
		t.Fatalf("unexpected request: %+v", service.createRequest)
	}
}

func TestOperationRejectionPreservesSafeUpstreamMessage(t *testing.T) {
	service := &fakeLibraryService{err: errors.Join(jwxt.ErrLibraryOperationRejected, errors.New("座位已被预约"))}
	h := server.Default()
	NewHandler(service).Register(h)

	response := ut.PerformRequest(h.Engine, "DELETE", "/api/v1/library/reservations/test-id", nil).Result()
	if response.StatusCode() != 409 || !strings.Contains(string(response.Body()), `"code":40901`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}

func TestSingleSignOnFailureIsReportedAsUpstreamError(t *testing.T) {
	service := &fakeLibraryService{err: jwxt.ErrUnsupportedLoginPage}
	h := server.Default()
	NewHandler(service).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/library/capabilities", nil).Result()
	if response.StatusCode() != 502 || !strings.Contains(string(response.Body()), `"code":50210`) {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
	if strings.Contains(string(response.Body()), "unsupported login page") {
		t.Fatalf("upstream detail leaked to client: %s", response.Body())
	}
}

func TestCaptchaEndpointReturnsImageWithoutCaching(t *testing.T) {
	h := server.Default()
	NewHandler(&fakeLibraryService{}).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/library/captcha", nil).Result()
	if response.StatusCode() != 200 || string(response.Body()) != "png" {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
	if !strings.HasPrefix(string(response.Header.ContentType()), "image/png") || string(response.Header.Peek("Cache-Control")) != "no-store" {
		t.Fatalf("unexpected headers: content-type=%s cache-control=%s", response.Header.ContentType(), response.Header.Peek("Cache-Control"))
	}
}

func TestSeatMapEndpointReturnsPrivateImage(t *testing.T) {
	h := server.Default()
	NewHandler(&fakeLibraryService{}).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/library/seat-map?room_id=7", nil).Result()
	if response.StatusCode() != 200 || string(response.Body()) != "floor-plan" {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
	if !strings.HasPrefix(string(response.Header.ContentType()), "image/jpeg") ||
		string(response.Header.Peek("Cache-Control")) != "private, max-age=300" ||
		string(response.Header.Peek("X-Content-Type-Options")) != "nosniff" {
		t.Fatalf("unexpected headers: content-type=%s cache-control=%s", response.Header.ContentType(), response.Header.Peek("Cache-Control"))
	}
}

func TestSeatMapEndpointRequiresRoom(t *testing.T) {
	h := server.Default()
	NewHandler(&fakeLibraryService{}).Register(h)

	response := ut.PerformRequest(h.Engine, "GET", "/api/v1/library/seat-map", nil).Result()
	if response.StatusCode() != http.StatusBadRequest {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
}

func TestAutoRenewalEndpointSchedulesFiveMinutesBeforeEnd(t *testing.T) {
	ctx := context.Background()
	db, err := database.OpenSQLite(ctx, filepath.Join(t.TempDir(), "library.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := migrations.Apply(ctx, db); err != nil {
		t.Fatal(err)
	}
	session := "test-session"
	sessionHash := sha256.Sum256([]byte(session))
	if _, err := db.ExecContext(ctx, `
INSERT INTO users (id, student_no, jwxt_password_enc) VALUES (1, 'test-student', X'01')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, `
INSERT INTO academic_sessions (token_hash, user_id) VALUES (?, 1)`, sessionHash[:]); err != nil {
		t.Fatal(err)
	}
	service := &fakeLibraryService{
		userID: 1,
		reservations: []jwxt.LibraryReservation{{
			UUID: "uuid-88", ReservationID: "88", Kind: jwxt.LibraryKindSeat,
			End: "2026-09-17 15:00:00", Status: 64, CanRenew: true,
		}},
	}
	repository := NewAutoRenewalRepository(db)
	handler := NewHandler(service, repository)
	location, _ := time.LoadLocation("Asia/Shanghai")
	handler.now = func() time.Time { return time.Date(2026, 9, 17, 14, 0, 0, 0, location) }
	h := server.Default()
	handler.Register(h)
	body := []byte(`{"DurationMinutes":60}`)

	response := ut.PerformRequest(
		h.Engine,
		"PUT",
		"/api/v1/library/reservations/88/auto-renewal",
		&ut.Body{Body: bytes.NewReader(body), Len: len(body)},
		ut.Header{Key: "Content-Type", Value: "application/json"},
		ut.Header{Key: "Cookie", Value: "campus_session=" + session},
	).Result()
	if response.StatusCode() != http.StatusOK {
		t.Fatalf("unexpected response: status=%d body=%s", response.StatusCode(), response.Body())
	}
	stored, err := repository.GetByReservation(ctx, 1, "88")
	if err != nil {
		t.Fatal(err)
	}
	wantExecuteAt := time.Date(2026, 9, 17, 14, 55, 0, 0, location)
	if stored == nil || stored.DurationMinutes != 60 || !stored.ExecuteAt.Equal(wantExecuteAt) {
		t.Fatalf("unexpected stored auto renewal: %+v", stored)
	}
}
