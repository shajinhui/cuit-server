package academic

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	apiresponse "cuit-server/internal/platform/response"
	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/protocol"
)

const (
	sessionCookieName   = "campus_session"
	sessionCookieMaxAge = 400 * 24 * time.Hour
)

type GradeService interface {
	Login(ctx context.Context, username string, password string) (string, error)
	GetStudentProfile(ctx context.Context, sessionID string) (jwxt.StudentProfile, error)
	GetPlanCompletion(ctx context.Context, sessionID string) (jwxt.PlanCompletion, error)
	ListSemesters(ctx context.Context, sessionID string) ([]jwxt.Semester, error)
	GetGrades(ctx context.Context, sessionID string, semesterID string) ([]jwxt.Grade, error)
	GetExams(ctx context.Context, sessionID string, semesterID string, examType string) ([]jwxt.Exam, error)
	Authenticated(ctx context.Context, sessionID string) (bool, error)
	Logout(ctx context.Context, sessionID string) error
}

// LoginLimiter 登录失败限流，由 admission 包提供 Redis 实现。
type LoginLimiter interface {
	Check(ctx context.Context, studentNo, ip string) (time.Duration, bool)
	Fail(ctx context.Context, studentNo, ip string)
	Reset(ctx context.Context, studentNo string)
}

type Handler struct {
	service      GradeService
	secureCookie bool
	limiter      LoginLimiter
}

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func NewHandler(service GradeService, secureCookie bool, limiter LoginLimiter) *Handler {
	return &Handler{service: service, secureCookie: secureCookie, limiter: limiter}
}

func (h *Handler) Register(server *server.Hertz, loginMiddleware ...app.HandlerFunc) {
	group := server.Group("/api/v1/jwxt")
	loginHandlers := append([]app.HandlerFunc{}, loginMiddleware...)
	loginHandlers = append(loginHandlers, h.login)
	group.POST("/session", loginHandlers...)
	group.GET("/session", h.sessionStatus)
	group.DELETE("/session", h.logout)
	group.GET("/profile", h.getStudentProfile)
	group.GET("/plan-completion", h.getPlanCompletion)
	group.GET("/semesters", h.listSemesters)
	group.GET("/grades", h.getGrades)
	group.GET("/exams", h.getExams)
}

func (h *Handler) login(ctx context.Context, c *app.RequestContext) {
	var request loginRequest
	if err := c.BindJSON(&request); err != nil || request.Username == "" || request.Password == "" {
		writeError(c, http.StatusBadRequest, 40000, "请输入学号和密码")
		return
	}
	studentNo := strings.TrimSpace(request.Username)
	ip := clientIP(c)
	if retryAfter, locked := h.limiter.Check(ctx, studentNo, ip); locked {
		c.Header("Retry-After", strconv.Itoa(int(retryAfter.Seconds())))
		writeError(c, http.StatusTooManyRequests, 42901, "尝试次数过多，请稍后再试")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	sessionID, err := h.service.Login(requestCtx, studentNo, request.Password)
	if err != nil {
		if errors.Is(err, jwxt.ErrInvalidCredentials) {
			// 只有密码错误才计数，教务系统网络故障不误锁用户。
			h.limiter.Fail(ctx, studentNo, ip)
		}
		log.Printf("教务系统登录失败: %v", err)
		writeServiceError(c, err)
		return
	}
	h.limiter.Reset(ctx, studentNo)
	h.setSessionCookie(c, sessionID)
	apiresponse.Success(c, map[string]bool{"authenticated": true})
}

// clientIP 优先取 Cloudflare Tunnel 透传的真实客户端 IP。
// 若服务器 8888 端口可被公网直连，该请求头可被伪造，需保证只允许本机访问。
func clientIP(c *app.RequestContext) string {
	if ip := strings.TrimSpace(string(c.Request.Header.Peek("CF-Connecting-IP"))); ip != "" {
		return ip
	}
	if forwarded := strings.TrimSpace(string(c.Request.Header.Peek("X-Forwarded-For"))); forwarded != "" {
		if comma := strings.IndexByte(forwarded, ','); comma >= 0 {
			forwarded = forwarded[:comma]
		}
		if ip := strings.TrimSpace(forwarded); ip != "" {
			return ip
		}
	}
	return c.ClientIP()
}

func (h *Handler) sessionStatus(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	sessionID := string(c.Cookie(sessionCookieName))
	authenticated, err := h.service.Authenticated(requestCtx, sessionID)
	if err != nil {
		log.Printf("查询登录状态失败: %v", err)
		writeServiceError(c, err)
		return
	}
	if authenticated {
		// 浏览器会限制持久 Cookie 的最长时间，因此每次启动应用时续写 Cookie。
		h.setSessionCookie(c, sessionID)
	}
	apiresponse.Success(c, map[string]bool{"authenticated": authenticated})
}

func (h *Handler) logout(ctx context.Context, c *app.RequestContext) {
	if err := h.service.Logout(ctx, string(c.Cookie(sessionCookieName))); err != nil {
		log.Printf("退出登录失败: %v", err)
		writeServiceError(c, err)
		return
	}
	c.SetCookie(sessionCookieName, "", -1, "/", "", protocol.CookieSameSiteLaxMode, h.secureCookie, true)
	apiresponse.Success(c, map[string]bool{"authenticated": false})
}

func (h *Handler) getStudentProfile(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	profile, err := h.service.GetStudentProfile(requestCtx, string(c.Cookie(sessionCookieName)))
	if err != nil {
		log.Printf("查询个人信息失败: %v", err)
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, profile)
}

func (h *Handler) getPlanCompletion(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	result, err := h.service.GetPlanCompletion(requestCtx, string(c.Cookie(sessionCookieName)))
	if err != nil {
		log.Printf("查询计划完成情况失败: %v", err)
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, result)
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
	apiresponse.Success(c, semesters)
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
	apiresponse.Success(c, grades)
}

func (h *Handler) getExams(ctx context.Context, c *app.RequestContext) {
	semesterID := strings.TrimSpace(c.Query("semester_id"))
	examType := strings.TrimSpace(c.Query("exam_type"))
	if semesterID == "" || (examType != jwxt.ExamTypeFinal && examType != jwxt.ExamTypeMakeup) {
		writeError(c, http.StatusBadRequest, 40000, "考试查询参数无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()

	exams, err := h.service.GetExams(
		requestCtx,
		string(c.Cookie(sessionCookieName)),
		semesterID,
		examType,
	)
	if err != nil {
		log.Printf("查询考试安排失败: semester_id=%s exam_type=%s: %v", semesterID, examType, err)
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, exams)
}

func (h *Handler) setSessionCookie(c *app.RequestContext, sessionID string) {
	// 前端脚本不可读取会话标识；SQLite 只保存随机 Token 的哈希。
	c.SetCookie(
		sessionCookieName,
		sessionID,
		int(sessionCookieMaxAge.Seconds()),
		"/",
		"",
		protocol.CookieSameSiteLaxMode,
		h.secureCookie,
		true,
	)
}

func writeError(c *app.RequestContext, status int, code int, message string) {
	apiresponse.Error(c, status, code, message)
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
	case errors.Is(err, jwxt.ErrExamQueryFailed):
		writeError(c, http.StatusBadGateway, 50208, "考试安排查询失败，请稍后重试")
	case errors.Is(err, jwxt.ErrProfileQueryFailed):
		writeError(c, http.StatusBadGateway, 50205, "个人信息查询失败，请稍后重试")
	case errors.Is(err, jwxt.ErrPlanCompletionQueryFailed):
		writeError(c, http.StatusBadGateway, 50206, "计划完成情况查询失败，请稍后重试")
	default:
		writeError(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
	}
}
