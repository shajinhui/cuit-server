package library

import (
	"context"
	"crypto/sha256"
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
	ResolveUserID(ctx context.Context, sessionID string) (int64, error)
	GetLibraryCapabilities(ctx context.Context, sessionID string) (jwxt.LibraryCapabilities, error)
	ListLibraryAreas(ctx context.Context, sessionID string, kind string) ([]jwxt.LibraryArea, error)
	ListLibrarySeats(ctx context.Context, sessionID string, query jwxt.LibrarySeatQuery) ([]jwxt.LibrarySeat, error)
	ListLibraryReservations(ctx context.Context, sessionID string, query jwxt.LibraryReservationQuery) ([]jwxt.LibraryReservation, error)
	CreateLibraryReservation(ctx context.Context, sessionID string, request jwxt.LibraryCreateReservationRequest) (jwxt.LibraryOperationResult, error)
	CancelLibraryReservation(ctx context.Context, sessionID string, uuid string) (jwxt.LibraryOperationResult, error)
	FinishLibraryReservation(ctx context.Context, sessionID string, uuid string) (jwxt.LibraryOperationResult, error)
	TemporaryLeaveLibraryReservation(ctx context.Context, sessionID string, reservationID string) (jwxt.LibraryOperationResult, error)
	GetLibraryRenewalOptions(ctx context.Context, sessionID string, reservationID string) (jwxt.LibraryRenewalOptions, error)
	RenewLibraryReservation(ctx context.Context, sessionID string, reservationID string, duration int) (jwxt.LibraryOperationResult, error)
	GetLibraryCaptcha(ctx context.Context, sessionID string) (jwxt.LibraryCaptcha, error)
	GetLibrarySeatMap(ctx context.Context, sessionID string, roomID string) (jwxt.LibrarySeatMap, error)
}

type Handler struct {
	service      Service
	autoRenewals *AutoRenewalRepository
	now          func() time.Time
}

type temporaryLeaveRequest struct {
	ReservationID string `json:"ReservationID"`
}

type renewalRequest struct {
	DurationMinutes int `json:"DurationMinutes"`
}

func NewHandler(service Service, autoRenewals ...*AutoRenewalRepository) *Handler {
	var repository *AutoRenewalRepository
	if len(autoRenewals) > 0 {
		repository = autoRenewals[0]
	}
	return &Handler{service: service, autoRenewals: repository, now: time.Now}
}

func (h *Handler) Register(server *server.Hertz) {
	group := server.Group("/api/v1/library")
	group.GET("/capabilities", h.getCapabilities)
	group.GET("/areas", h.listAreas)
	group.GET("/seats", h.listSeats)
	group.GET("/reservations", h.listReservations)
	group.GET("/captcha", h.getCaptcha)
	group.GET("/seat-map", h.getSeatMap)
	group.POST("/reservations", h.createReservation)
	group.DELETE("/reservations/:uuid", h.cancelReservation)
	group.POST("/reservations/:uuid/finish", h.finishReservation)
	group.POST("/reservations/:uuid/temporary-leave", h.temporaryLeave)
	group.GET("/reservations/:reservation_id/renewal-options", h.getRenewalOptions)
	group.POST("/reservations/:reservation_id/renew", h.renewReservation)
	if h.autoRenewals != nil {
		group.GET("/auto-renewals", h.listAutoRenewals)
		group.PUT("/reservations/:reservation_id/auto-renewal", h.scheduleAutoRenewal)
		group.DELETE("/reservations/:reservation_id/auto-renewal", h.cancelAutoRenewal)
	}
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

func (h *Handler) getSeatMap(ctx context.Context, c *app.RequestContext) {
	roomID := strings.TrimSpace(c.Query("room_id"))
	if roomID == "" {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "预约区域不能为空")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.GetLibrarySeatMap(requestCtx, sessionID(c), roomID)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	c.Header("Cache-Control", "private, max-age=300")
	c.Header("X-Content-Type-Options", "nosniff")
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

func (h *Handler) getRenewalOptions(ctx context.Context, c *app.RequestContext) {
	reservationID := strings.TrimSpace(c.Param("reservation_id"))
	if reservationID == "" {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "预约记录标识无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.GetLibraryRenewalOptions(requestCtx, sessionID(c), reservationID)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) renewReservation(ctx context.Context, c *app.RequestContext) {
	reservationID := strings.TrimSpace(c.Param("reservation_id"))
	var request renewalRequest
	if reservationID == "" || c.BindJSON(&request) != nil || request.DurationMinutes <= 0 {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "续座参数无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.RenewLibraryReservation(
		requestCtx,
		sessionID(c),
		reservationID,
		request.DurationMinutes,
	)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) listAutoRenewals(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	userID, err := h.service.ResolveUserID(requestCtx, sessionID(c))
	if err != nil {
		writeServiceError(c, err)
		return
	}
	if err := h.autoRenewals.CancelInactiveSessions(requestCtx, h.now()); err != nil {
		writeServiceError(c, err)
		return
	}
	result, err := h.autoRenewals.ListByUser(requestCtx, userID)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) scheduleAutoRenewal(ctx context.Context, c *app.RequestContext) {
	reservationID := strings.TrimSpace(c.Param("reservation_id"))
	var request renewalRequest
	if reservationID == "" || c.BindJSON(&request) != nil || request.DurationMinutes <= 0 {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "自动续座参数无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	session := sessionID(c)
	userID, err := h.service.ResolveUserID(requestCtx, session)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	reservations, err := h.service.ListLibraryReservations(requestCtx, session, jwxt.LibraryReservationQuery{})
	if err != nil {
		writeServiceError(c, err)
		return
	}
	reservation := findReservation(reservations, reservationID)
	if reservation == nil || reservation.Kind != jwxt.LibraryKindSeat || !reservation.CanRenew {
		apiresponse.Error(c, http.StatusConflict, 40901, "仅正在使用且尚未结束的普通座位可以开启自动续座")
		return
	}
	options, err := h.service.GetLibraryRenewalOptions(requestCtx, session, reservationID)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	if !containsDuration(options.Durations, request.DurationMinutes) {
		apiresponse.Error(c, http.StatusUnprocessableEntity, 42201, "请选择图书馆当前允许的续座时长")
		return
	}
	end, err := parseLibraryTime(reservation.End)
	if err != nil {
		log.Printf("自动续座预约结束时间解析失败: reservation_id=%s end=%q: %v", reservationID, reservation.End, err)
		apiresponse.Error(c, http.StatusBadGateway, 50210, "图书馆返回的预约结束时间无效")
		return
	}
	now := h.now()
	if !end.After(now) {
		apiresponse.Error(c, http.StatusConflict, 40901, "预约已经结束，无法开启自动续座")
		return
	}
	executeAt := end.Add(-5 * time.Minute)
	if executeAt.Before(now) {
		executeAt = now
	}
	result, err := h.autoRenewals.Schedule(requestCtx, ScheduleAutoRenewalInput{
		UserID:           userID,
		SessionTokenHash: sha256.Sum256([]byte(session)),
		ReservationID:    reservationID,
		ReservationUUID:  reservation.UUID,
		DurationMinutes:  request.DurationMinutes,
		ReservationEnd:   reservation.End,
		ExecuteAt:        executeAt,
	}, now)
	if err != nil {
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
}

func (h *Handler) cancelAutoRenewal(ctx context.Context, c *app.RequestContext) {
	reservationID := strings.TrimSpace(c.Param("reservation_id"))
	if reservationID == "" {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "预约记录标识无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	userID, err := h.service.ResolveUserID(requestCtx, sessionID(c))
	if err != nil {
		writeServiceError(c, err)
		return
	}
	result, err := h.autoRenewals.Cancel(requestCtx, userID, reservationID, h.now())
	if err != nil {
		writeServiceError(c, err)
		return
	}
	if result == nil {
		apiresponse.Error(c, http.StatusNotFound, 40401, "未找到自动续座任务")
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
	if h.autoRenewals != nil {
		userID, resolveErr := h.service.ResolveUserID(requestCtx, sessionID(c))
		if resolveErr != nil {
			log.Printf("预约结束后读取用户失败: uuid=%s: %v", uuid, resolveErr)
		} else if cancelErr := h.autoRenewals.CancelByReservationUUID(requestCtx, userID, uuid, h.now()); cancelErr != nil {
			log.Printf("预约结束后关闭自动续座失败: uuid=%s: %v", uuid, cancelErr)
		}
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
	case errors.Is(err, ErrAutoRenewalInProgress):
		apiresponse.Error(c, http.StatusConflict, 40901, "自动续座正在执行，暂时无法修改")
	case errors.Is(err, ErrAutoRenewalAlreadyFinal):
		apiresponse.Error(c, http.StatusConflict, 40901, "本次预约的自动续座已经执行过，为避免重复提交不能再次开启")
	case errors.Is(err, ErrAutoRenewalSessionEnded):
		apiresponse.Error(c, http.StatusUnauthorized, 40101, "登录已退出，请重新登录后设置自动续座")
	case errors.Is(err, jwxt.ErrUnsupportedLoginPage), errors.Is(err, jwxt.ErrLoginVerificationFailed):
		// 图书馆走一网通办单点登录，登录链路异常时不能把上游细节返回给客户端。
		log.Printf("图书馆单点登录失败: %v", err)
		apiresponse.Error(c, http.StatusBadGateway, 50210, fallback(publicMessage, "图书馆单点登录失败，请稍后重试"))
	case errors.Is(err, jwxt.ErrLibraryQueryFailed), errors.Is(err, jwxt.ErrRemoteUnavailable):
		log.Printf("图书馆上游请求失败: %v", err)
		apiresponse.Error(c, http.StatusBadGateway, 50210, fallback(publicMessage, "图书馆系统暂时无法访问"))
	default:
		log.Printf("图书馆服务未预期错误: %v", err)
		apiresponse.Error(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
	}
}

func findReservation(reservations []jwxt.LibraryReservation, reservationID string) *jwxt.LibraryReservation {
	for index := range reservations {
		if strings.TrimSpace(reservations[index].ReservationID) == reservationID {
			return &reservations[index]
		}
	}
	return nil
}

func containsDuration(options []int, duration int) bool {
	for _, option := range options {
		if option == duration {
			return true
		}
	}
	return false
}

func parseLibraryTime(value string) (time.Time, error) {
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		location = time.FixedZone("Asia/Shanghai", 8*60*60)
	}
	value = strings.TrimSpace(value)
	for _, layout := range []string{"2006-01-02 15:04:05", "2006-01-02T15:04:05", time.RFC3339} {
		if parsed, parseErr := time.ParseInLocation(layout, value, location); parseErr == nil {
			return parsed, nil
		}
	}
	return time.Time{}, errors.New("invalid library time")
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
