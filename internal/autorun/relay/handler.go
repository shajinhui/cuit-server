package relay

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"cuit-server/internal/autorun/store"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
)

const internalRequestTimeout = 10 * time.Second

type repository interface {
	SaveSession(context.Context, string, store.Session, ...string) (store.Session, error)
	GetSessionByKey(context.Context, string) (*store.Session, error)
	GetSchedule(context.Context, int64) (*store.Schedule, error)
	SaveSchedule(context.Context, int64, int64, string, bool, ...time.Time) (*store.Schedule, error)
}

// Handler exposes only scheduler state operations. Every request must carry a
// fresh HMAC signature; no browser session or CORS credential grants access.
type Handler struct {
	repository repository
	secret     string
	now        func() time.Time
}

func NewHandler(repository repository, secret string) *Handler {
	return &Handler{repository: repository, secret: secret, now: time.Now}
}

func (h *Handler) Register(router *server.Hertz) {
	router.POST("/internal/autorun/session/resolve", h.handle("session_resolve"))
	router.POST("/internal/autorun/schedule/get", h.handle("schedule_get"))
	router.POST("/internal/autorun/schedule/set", h.handle("schedule_set"))
}

type internalRequest struct {
	SessionKey string `json:"sessionKey"`
	Token      string `json:"token"`
	UserID     int64  `json:"userId"`
	StudentID  int64  `json:"studentId"`
	SchoolID   int64  `json:"schoolId"`
	Enabled    *bool  `json:"enabled"`
}

type internalEnvelope struct {
	Code     int    `json:"code"`
	Msg      string `json:"msg"`
	Response any    `json:"response"`
}

func (h *Handler) handle(action string) app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		body := c.Request.Body()
		if err := verifyRequest(
			h.secret, http.MethodPost, string(c.Path()), body,
			string(c.Request.Header.Peek(timestampHeader)),
			string(c.Request.Header.Peek(signatureHeader)), h.now(),
		); err != nil {
			h.write(c, http.StatusUnauthorized, 40100, "unauthorized", map[string]any{})
			return
		}
		var request internalRequest
		if len(body) == 0 || json.Unmarshal(body, &request) != nil {
			h.write(c, http.StatusBadRequest, 40000, "请求格式无效", map[string]any{})
			return
		}
		requestCtx, cancel := context.WithTimeout(ctx, internalRequestTimeout)
		defer cancel()
		response, err := h.execute(requestCtx, action, request)
		if err != nil {
			status := http.StatusInternalServerError
			code := 50000
			message := "定时服务内部错误"
			if errors.Is(err, errInvalidRequest) {
				status, code, message = http.StatusBadRequest, 40000, "请求参数无效"
			} else if errors.Is(err, context.DeadlineExceeded) {
				status, code, message = http.StatusGatewayTimeout, 50400, "定时服务请求超时"
			}
			h.write(c, status, code, message, map[string]any{})
			return
		}
		h.write(c, http.StatusOK, 10000, "ok", response)
	}
}

var errInvalidRequest = errors.New("autorun relay: invalid request")

func (h *Handler) execute(ctx context.Context, action string, request internalRequest) (any, error) {
	switch action {
	case "session_resolve":
		if !validSessionKey(request.SessionKey) {
			return nil, errInvalidRequest
		}
		session, err := h.repository.GetSessionByKey(ctx, request.SessionKey)
		if err != nil || session == nil {
			return map[string]any{"session": session}, err
		}
		return map[string]any{"session": map[string]any{
			"token": session.Token, "userId": session.UserID,
			"studentId": session.StudentID, "schoolId": session.SchoolID,
		}}, nil
	case "schedule_get":
		if request.StudentID <= 0 {
			return nil, errInvalidRequest
		}
		schedule, err := h.repository.GetSchedule(ctx, request.StudentID)
		if err != nil {
			return nil, err
		}
		return map[string]any{"schedule": publicSchedule(schedule, request.StudentID)}, nil
	case "schedule_set":
		if !validSessionKey(request.SessionKey) || strings.TrimSpace(request.Token) == "" ||
			request.UserID <= 0 || request.StudentID <= 0 || request.SchoolID <= 0 || request.Enabled == nil {
			return nil, errInvalidRequest
		}
		// SQLite receives the same opaque session key used by D1. The upstream
		// token stays encrypted at rest and passwords never cross this endpoint.
		_, err := h.repository.SaveSession(ctx, "", store.Session{
			Token: request.Token, UserID: request.UserID,
			StudentID: request.StudentID, SchoolID: request.SchoolID,
		}, request.SessionKey)
		if err != nil {
			return nil, err
		}
		schedule, err := h.repository.SaveSchedule(
			ctx, request.StudentID, request.SchoolID, request.SessionKey, *request.Enabled, h.now(),
		)
		if err != nil {
			return nil, err
		}
		return map[string]any{"schedule": publicSchedule(schedule, request.StudentID)}, nil
	default:
		return nil, errInvalidRequest
	}
}

func (h *Handler) write(c *app.RequestContext, status, code int, message string, response any) {
	c.Header("Cache-Control", "no-store")
	c.JSON(status, internalEnvelope{Code: code, Msg: message, Response: response})
}

type publicScheduleState struct {
	StudentID    int64  `json:"studentId,omitempty"`
	Enabled      bool   `json:"enabled"`
	LastProbeAt  string `json:"lastProbeAt,omitempty"`
	LastActionAt string `json:"lastActionAt,omitempty"`
	LastMessage  string `json:"lastMessage,omitempty"`
	UpdatedAt    string `json:"updatedAt,omitempty"`
}

func publicSchedule(schedule *store.Schedule, studentID int64) publicScheduleState {
	result := publicScheduleState{StudentID: studentID}
	if schedule == nil {
		return result
	}
	result.Enabled = schedule.Enabled
	result.LastMessage = schedule.LastMessage
	if schedule.LastProbeAt != nil {
		result.LastProbeAt = schedule.LastProbeAt.UTC().Format(time.RFC3339Nano)
	}
	if schedule.LastActionAt != nil {
		result.LastActionAt = schedule.LastActionAt.UTC().Format(time.RFC3339Nano)
	}
	if !schedule.UpdatedAt.IsZero() {
		result.UpdatedAt = schedule.UpdatedAt.UTC().Format(time.RFC3339Nano)
	}
	return result
}

func validSessionKey(value string) bool {
	length := len(strings.TrimSpace(value))
	return length >= 20 && length <= 256
}
