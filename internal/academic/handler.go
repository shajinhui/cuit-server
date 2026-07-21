package academic

import (
	"context"
	"errors"
	"log"
	"net/http"
	"time"

	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/protocol"
)

const (
	sessionCookieName = "campus_session"
	sessionMaxAge     = 30 * 24 * time.Hour
)

type GradeService interface {
	Login(ctx context.Context, username string, password string) (string, error)
	ListSemesters(ctx context.Context, sessionID string) ([]jwxt.Semester, error)
	GetGrades(ctx context.Context, sessionID string, semesterID string) ([]jwxt.Grade, error)
	Authenticated(ctx context.Context, sessionID string) (bool, error)
	Logout(ctx context.Context, sessionID string) error
}

type Handler struct {
	service      GradeService
	secureCookie bool
}

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Remember bool   `json:"remember"`
}

type apiResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data"`
}

func NewHandler(service GradeService, secureCookie bool) *Handler {
	return &Handler{service: service, secureCookie: secureCookie}
}

func (h *Handler) Register(server *server.Hertz) {
	group := server.Group("/api/v1/jwxt")
	group.POST("/session", h.login)
	group.GET("/session", h.sessionStatus)
	group.DELETE("/session", h.logout)
	group.GET("/semesters", h.listSemesters)
	group.GET("/grades", h.getGrades)
}

func (h *Handler) login(ctx context.Context, c *app.RequestContext) {
	var request loginRequest
	if err := c.BindJSON(&request); err != nil || request.Username == "" || request.Password == "" {
		writeError(c, http.StatusBadRequest, 40000, "请输入学号和密码")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	sessionID, err := h.service.Login(requestCtx, request.Username, request.Password)
	if err != nil {
		log.Printf("教务系统登录失败: %v", err)
		writeServiceError(c, err)
		return
	}
	maxAge := 0
	if request.Remember {
		maxAge = int(sessionMaxAge.Seconds())
	}
	// 前端脚本不可读取会话标识；数据库只保存随机会话摘要。
	c.SetCookie(sessionCookieName, sessionID, maxAge, "/", "", protocol.CookieSameSiteLaxMode, h.secureCookie, true)
	writeSuccess(c, map[string]bool{"authenticated": true})
}

func (h *Handler) sessionStatus(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	authenticated, err := h.service.Authenticated(requestCtx, string(c.Cookie(sessionCookieName)))
	if err != nil {
		log.Printf("查询登录状态失败: %v", err)
		writeServiceError(c, err)
		return
	}
	writeSuccess(c, map[string]bool{"authenticated": authenticated})
}

func (h *Handler) logout(ctx context.Context, c *app.RequestContext) {
	if err := h.service.Logout(ctx, string(c.Cookie(sessionCookieName))); err != nil {
		log.Printf("退出登录失败: %v", err)
		writeServiceError(c, err)
		return
	}
	c.SetCookie(sessionCookieName, "", -1, "/", "", protocol.CookieSameSiteLaxMode, h.secureCookie, true)
	writeSuccess(c, map[string]bool{"authenticated": false})
}

func (h *Handler) listSemesters(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	semesters, err := h.service.ListSemesters(requestCtx, string(c.Cookie(sessionCookieName)))
	if err != nil {
		log.Printf("查询学期失败: %v", err)
		writeServiceError(c, err)
		return
	}
	writeSuccess(c, semesters)
}

func (h *Handler) getGrades(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	semesterID := c.Query("semester_id")
	grades, err := h.service.GetGrades(requestCtx, string(c.Cookie(sessionCookieName)), semesterID)
	if err != nil {
		log.Printf("查询成绩失败: semester_id=%s: %v", semesterID, err)
		writeServiceError(c, err)
		return
	}
	writeSuccess(c, grades)
}

func writeSuccess(c *app.RequestContext, data any) {
	c.Header("Cache-Control", "no-store")
	c.JSON(http.StatusOK, apiResponse{Code: 0, Message: "success", Data: data})
}

func writeError(c *app.RequestContext, status int, code int, message string) {
	c.Header("Cache-Control", "no-store")
	c.JSON(status, apiResponse{Code: code, Message: message, Data: nil})
}

func writeServiceError(c *app.RequestContext, err error) {
	switch {
	case errors.Is(err, ErrInvalidInput):
		writeError(c, http.StatusBadRequest, 40000, "请求参数不完整")
	case errors.Is(err, jwxt.ErrInvalidCredentials):
		writeError(c, http.StatusUnauthorized, 40001, "学号或密码错误")
	case errors.Is(err, ErrUnauthenticated), errors.Is(err, jwxt.ErrSessionExpired):
		writeError(c, http.StatusUnauthorized, 40101, "教务登录已失效，请重新登录")
	case errors.Is(err, jwxt.ErrRemoteUnavailable):
		writeError(c, http.StatusBadGateway, 50201, "教务系统暂时无法访问")
	case errors.Is(err, jwxt.ErrGradeQueryFailed):
		writeError(c, http.StatusBadGateway, 50202, "成绩查询失败，请稍后重试")
	default:
		writeError(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
	}
}
