package library

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"cuit-server/internal/academic"
	apiresponse "cuit-server/internal/platform/response"
	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
)

const sessionCookieName = "campus_session"

type Service interface {
	GetLibraryCapabilities(ctx context.Context, sessionID string) (jwxt.LibraryCapabilities, error)
	ListLibraryAreas(ctx context.Context, sessionID string, kind string) ([]jwxt.LibraryArea, error)
	ListLibrarySeats(ctx context.Context, sessionID string, query jwxt.LibrarySeatQuery) ([]jwxt.LibrarySeat, error)
	ListLibraryReservations(ctx context.Context, sessionID string, query jwxt.LibraryReservationQuery) ([]jwxt.LibraryReservation, error)
	CreateLibraryReservation(ctx context.Context, sessionID string, request jwxt.LibraryCreateReservationRequest) (jwxt.LibraryOperationResult, error)
	CancelLibraryReservation(ctx context.Context, sessionID string, uuid string) (jwxt.LibraryOperationResult, error)
	FinishLibraryReservation(ctx context.Context, sessionID string, uuid string) (jwxt.LibraryOperationResult, error)
	TemporaryLeaveLibraryReservation(ctx context.Context, sessionID string, reservationID string) (jwxt.LibraryOperationResult, error)
	GetLibraryCaptcha(ctx context.Context, sessionID string) (jwxt.LibraryCaptcha, error)
}

type Handler struct {
	service Service
}

type temporaryLeaveRequest struct {
	ReservationID string `json:"ReservationID"`
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Register(server *server.Hertz) {
	group := server.Group("/api/v1/library")
	group.GET("/capabilities", h.getCapabilities)
	group.GET("/areas", h.listAreas)
	group.GET("/seats", h.listSeats)
	group.GET("/reservations", h.listReservations)
	group.GET("/captcha", h.getCaptcha)
	group.POST("/reservations", h.createReservation)
	group.DELETE("/reservations/:uuid", h.cancelReservation)
	group.POST("/reservations/:uuid/finish", h.finishReservation)
	group.POST("/reservations/:uuid/temporary-leave", h.temporaryLeave)
}

func (h *Handler) getCapabilities(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.GetLibraryCapabilities(requestCtx, sessionID(c))
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) listAreas(ctx context.Context, c *app.RequestContext) {
	kind := strings.TrimSpace(c.Query("kind"))
	if kind != jwxt.LibraryKindSeat && kind != jwxt.LibraryKindStudy {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "预约类型无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.ListLibraryAreas(requestCtx, sessionID(c), kind)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) listSeats(ctx context.Context, c *app.RequestContext) {
	query := jwxt.LibrarySeatQuery{
		Kind:      strings.TrimSpace(c.Query("kind")),
		RoomID:    strings.TrimSpace(c.Query("room_id")),
		StartDate: strings.TrimSpace(c.Query("start_date")),
		EndDate:   strings.TrimSpace(c.Query("end_date")),
		StartTime: strings.TrimSpace(c.Query("start_time")),
		EndTime:   strings.TrimSpace(c.Query("end_time")),
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.ListLibrarySeats(requestCtx, sessionID(c), query)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) listReservations(ctx context.Context, c *app.RequestContext) {
	query := jwxt.LibraryReservationQuery{
		StartDate: strings.TrimSpace(c.Query("start_date")),
		EndDate:   strings.TrimSpace(c.Query("end_date")),
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.ListLibraryReservations(requestCtx, sessionID(c), query)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) getCaptcha(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.GetLibraryCaptcha(requestCtx, sessionID(c))
	if err != nil {
		writeServiceError(c, err)
		return
	}
	c.Header("Cache-Control", "no-store")
	c.Data(http.StatusOK, result.ContentType, result.Data)
}

func (h *Handler) createReservation(ctx context.Context, c *app.RequestContext) {
	var request jwxt.LibraryCreateReservationRequest
	if err := c.BindJSON(&request); err != nil {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "预约参数无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.CreateLibraryReservation(requestCtx, sessionID(c), request)
	if err != nil {
		log.Printf("创建图书馆预约失败: kind=%s: %v", request.Kind, err)
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) cancelReservation(ctx context.Context, c *app.RequestContext) {
	h.runReservationAction(ctx, c, func(requestCtx context.Context, session, uuid string) (jwxt.LibraryOperationResult, error) {
		return h.service.CancelLibraryReservation(requestCtx, session, uuid)
	})
}

func (h *Handler) finishReservation(ctx context.Context, c *app.RequestContext) {
	h.runReservationAction(ctx, c, func(requestCtx context.Context, session, uuid string) (jwxt.LibraryOperationResult, error) {
		return h.service.FinishLibraryReservation(requestCtx, session, uuid)
	})
}

func (h *Handler) temporaryLeave(ctx context.Context, c *app.RequestContext) {
	var request temporaryLeaveRequest
	if err := c.BindJSON(&request); err != nil || strings.TrimSpace(request.ReservationID) == "" {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "预约记录标识无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.TemporaryLeaveLibraryReservation(
		requestCtx,
		sessionID(c),
		request.ReservationID,
	)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) runReservationAction(
	ctx context.Context,
	c *app.RequestContext,
	action func(context.Context, string, string) (jwxt.LibraryOperationResult, error),
) {
	uuid := strings.TrimSpace(c.Param("uuid"))
	if uuid == "" {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "预约记录标识无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := action(requestCtx, sessionID(c), uuid)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func sessionID(c *app.RequestContext) string {
	return string(c.Cookie(sessionCookieName))
}

func writeServiceError(c *app.RequestContext, err error) {
	publicMessage := jwxt.LibraryErrorMessage(err)
	switch {
	case errors.Is(err, academic.ErrInvalidInput), errors.Is(err, jwxt.ErrLibraryVerification):
		apiresponse.Error(c, http.StatusUnprocessableEntity, 42201, fallback(publicMessage, "预约参数无效"))
	case errors.Is(err, academic.ErrUnauthenticated), errors.Is(err, jwxt.ErrSessionExpired):
		apiresponse.Error(c, http.StatusUnauthorized, 40101, "教务登录已失效，请重新登录")
	case errors.Is(err, jwxt.ErrLibraryOperationRejected):
		apiresponse.Error(c, http.StatusConflict, 40901, fallback(publicMessage, "图书馆系统未接受本次操作"))
	case errors.Is(err, jwxt.ErrLibraryQueryFailed), errors.Is(err, jwxt.ErrRemoteUnavailable):
		apiresponse.Error(c, http.StatusBadGateway, 50210, fallback(publicMessage, "图书馆系统暂时无法访问"))
	default:
		apiresponse.Error(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
	}
}

func fallback(value, fallbackValue string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallbackValue
	}
	const maximumRunes = 120
	runes := []rune(value)
	if len(runes) > maximumRunes {
		return string(runes[:maximumRunes])
	}
	return value
}
