package autorun

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"cuit-server/internal/autorun/upstream"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
)

const requestTimeout = 30 * time.Second

type actionService interface {
	Login(context.Context, string, string) (SessionResponse, error)
	Bootstrap(context.Context, string) (SessionResponse, error)
	RunInfo(context.Context, string) (RunData, error)
	PrepareRun(context.Context, string) (RunPreparation, error)
	SubmitRun(context.Context, string, upstream.NewRecordBody) (map[string]any, error)
	ClubData(context.Context, string, string) (ClubData, error)
	GetClubSchedule(context.Context, string) (map[string]any, error)
	SetClubSchedule(context.Context, string, bool) (map[string]any, error)
	SignClub(context.Context, string, SignClubRequest) (map[string]any, error)
	JoinClub(context.Context, string, int64) (map[string]any, error)
	CancelClub(context.Context, string, int64) (map[string]any, error)
}

type Handler struct {
	service actionService
}

func NewHandler(service actionService) *Handler {
	return &Handler{service: service}
}

type actionRequest struct {
	Phone      string                  `json:"phone"`
	Password   string                  `json:"password"`
	SessionKey string                  `json:"sessionKey"`
	QueryDate  string                  `json:"queryDate"`
	Enabled    *bool                   `json:"enabled"`
	ActivityID int64                   `json:"activityId"`
	Latitude   string                  `json:"latitude"`
	Longitude  string                  `json:"longitude"`
	SignType   string                  `json:"signType"`
	Record     *upstream.NewRecordBody `json:"record"`
}

type actionEnvelope struct {
	Code     int    `json:"code"`
	Msg      string `json:"msg"`
	Response any    `json:"response"`
}

func (h *Handler) Register(router *server.Hertz, loginMiddleware ...app.HandlerFunc) {
	loginHandlers := append([]app.HandlerFunc{}, loginMiddleware...)
	loginHandlers = append(loginHandlers, h.handle("login"))
	router.POST("/api/login", loginHandlers...)
	for _, action := range []string{
		"session_bootstrap", "run_info", "run_prepare", "run",
		"club_data", "club_schedule_get", "club_schedule_set", "club_sign",
		"club_join", "club_cancel",
	} {
		action := action
		router.POST("/api/"+action, h.handle(action))
	}
}

func (h *Handler) handle(action string) app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var request actionRequest
		if len(c.Request.Body()) > 0 {
			if err := c.BindJSON(&request); err != nil {
				writeActionError(c, http.StatusBadRequest, 40000, "请求格式无效")
				return
			}
		}
		sessionKey := bearerSessionKey(c)
		if sessionKey == "" {
			sessionKey = strings.TrimSpace(request.SessionKey)
		}
		requestCtx, cancel := context.WithTimeout(ctx, requestTimeout)
		defer cancel()

		var response any
		var message = "ok"
		var err error
		switch action {
		case "login":
			response, err = h.service.Login(requestCtx, request.Phone, request.Password)
		case "session_bootstrap":
			response, err = h.service.Bootstrap(requestCtx, sessionKey)
		case "run_info":
			response, err = h.service.RunInfo(requestCtx, sessionKey)
		case "run_prepare":
			response, err = h.service.PrepareRun(requestCtx, sessionKey)
		case "run":
			if request.Record == nil {
				err = ErrInvalidInput
			} else {
				response, err = h.service.SubmitRun(requestCtx, sessionKey, *request.Record)
			}
		case "club_data":
			response, err = h.service.ClubData(requestCtx, sessionKey, request.QueryDate)
		case "club_schedule_get":
			response, err = h.service.GetClubSchedule(requestCtx, sessionKey)
		case "club_schedule_set":
			if request.Enabled == nil {
				err = ErrInvalidInput
			} else {
				response, err = h.service.SetClubSchedule(requestCtx, sessionKey, *request.Enabled)
				if err == nil {
					if *request.Enabled {
						message = "已开启俱乐部定时"
					} else {
						message = "已关闭俱乐部定时"
					}
				}
			}
		case "club_sign":
			response, err = h.service.SignClub(requestCtx, sessionKey, SignClubRequest{
				ActivityID: request.ActivityID, Latitude: request.Latitude,
				Longitude: request.Longitude, SignType: strings.TrimSpace(request.SignType),
			})
		case "club_join":
			response, err = h.service.JoinClub(requestCtx, sessionKey, request.ActivityID)
		case "club_cancel":
			response, err = h.service.CancelClub(requestCtx, sessionKey, request.ActivityID)
		}
		if err != nil {
			log.Printf("AutoRun 请求失败: action=%s: %v", action, err)
			writeServiceError(c, err)
			return
		}
		c.Header("Cache-Control", "no-store")
		c.JSON(http.StatusOK, actionEnvelope{Code: 10000, Msg: message, Response: response})
	}
}

func bearerSessionKey(c *app.RequestContext) string {
	value := strings.TrimSpace(string(c.Request.Header.Peek("Authorization")))
	if len(value) < 7 || !strings.EqualFold(value[:7], "Bearer ") {
		return ""
	}
	return strings.TrimSpace(value[7:])
}

func writeServiceError(c *app.RequestContext, err error) {
	switch {
	case errors.Is(err, ErrInvalidInput):
		writeActionError(c, http.StatusBadRequest, 40000, "请求参数无效")
	case errors.Is(err, ErrUnauthenticated), upstream.IsTokenExpired(err):
		writeActionError(c, http.StatusUnauthorized, 40100, "登录态已过期，请重新登录")
	case errors.Is(err, context.DeadlineExceeded):
		writeActionError(c, http.StatusGatewayTimeout, 50400, "上游请求超时，请稍后重试")
	default:
		var upstreamErr *upstream.UpstreamError
		if errors.As(err, &upstreamErr) {
			writeActionError(c, http.StatusBadGateway, 50200, "校园跑上游暂时不可用")
			return
		}
		writeActionError(c, http.StatusInternalServerError, 50000, "校园跑服务暂时不可用")
	}
}

func writeActionError(c *app.RequestContext, status, code int, message string) {
	c.Header("Cache-Control", "no-store")
	c.JSON(status, actionEnvelope{Code: code, Msg: message, Response: nil})
}
