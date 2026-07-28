package feedback

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strings"
	"unicode/utf8"

	"cuit-server/internal/academic"
	apiresponse "cuit-server/internal/platform/response"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
)

const sessionCookieName = "campus_session"

type UserResolver interface {
	ResolveUserID(ctx context.Context, sessionID string) (int64, error)
}

type FeedbackRepository interface {
	Create(ctx context.Context, userID int64, submission Submission) (Record, error)
}

type Handler struct {
	users      UserResolver
	repository FeedbackRepository
}

type createRequest struct {
	Type     string `json:"type"`
	Platform string `json:"platform"`
	Content  string `json:"content"`
}

type createResponse struct {
	ID        int64  `json:"id"`
	CreatedAt string `json:"created_at"`
}

func NewHandler(users UserResolver, repository FeedbackRepository) *Handler {
	return &Handler{users: users, repository: repository}
}

func (h *Handler) Register(server *server.Hertz) {
	server.POST("/api/v1/feedback", h.create)
}

func (h *Handler) create(ctx context.Context, c *app.RequestContext) {
	var request createRequest
	if err := c.BindJSON(&request); err != nil {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "反馈内容格式无效")
		return
	}
	submission, ok := normalizeSubmission(request, string(c.Request.Header.Peek("User-Agent")))
	if !ok {
		apiresponse.Error(c, http.StatusBadRequest, 40000, "请完整选择反馈类型、问题平台并填写 10 至 2000 字")
		return
	}

	userID, err := h.users.ResolveUserID(ctx, string(c.Cookie(sessionCookieName)))
	if errors.Is(err, academic.ErrUnauthenticated) {
		apiresponse.Error(c, http.StatusUnauthorized, 40101, "请先登录")
		return
	}
	if err != nil {
		log.Printf("问题反馈用户校验失败: %v", err)
		apiresponse.Error(c, http.StatusInternalServerError, 50000, "反馈服务暂时不可用")
		return
	}

	record, err := h.repository.Create(ctx, userID, submission)
	if err != nil {
		log.Printf("保存问题反馈失败: user_id=%d type=%s platform=%s: %v", userID, submission.Type, submission.Platform, err)
		apiresponse.Error(c, http.StatusInternalServerError, 50000, "反馈提交失败，请稍后重试")
		return
	}
	apiresponse.Success(c, createResponse{
		ID:        record.ID,
		CreatedAt: record.CreatedAt.Format(timeFormat),
	})
}

const timeFormat = "2006-01-02T15:04:05Z07:00"

func normalizeSubmission(request createRequest, userAgent string) (Submission, bool) {
	feedbackType := strings.ToLower(strings.TrimSpace(request.Type))
	platform := strings.ToLower(strings.TrimSpace(request.Platform))
	content := strings.TrimSpace(request.Content)
	contentLength := utf8.RuneCountInString(content)
	if (feedbackType != TypeSuggestion && feedbackType != TypeBug) ||
		(platform != PlatformAndroid && platform != PlatformIOS) ||
		contentLength < minContentLength ||
		contentLength > maxContentLength {
		return Submission{}, false
	}
	userAgent = strings.TrimSpace(userAgent)
	userAgentRunes := []rune(userAgent)
	if len(userAgentRunes) > 512 {
		userAgent = string(userAgentRunes[:512])
	}
	return Submission{
		Type:      feedbackType,
		Platform:  platform,
		Content:   content,
		UserAgent: userAgent,
	}, true
}
