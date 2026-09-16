package library

import (
	"bytes"
	"context"
	"errors"
	"strings"
	"testing"

	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

type fakeLibraryService struct {
	seats         []jwxt.LibrarySeat
	reservations  []jwxt.LibraryReservation
	createRequest *jwxt.LibraryCreateReservationRequest
	err           error
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

func (service *fakeLibraryService) GetLibraryCaptcha(context.Context, string) (jwxt.LibraryCaptcha, error) {
	return jwxt.LibraryCaptcha{ContentType: "image/png", Data: []byte("png")}, service.err
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
