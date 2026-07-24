package exam

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

const (
	entryPath                  = "/eams/stdExamTable.action"
	examTablePath              = "/eams/stdExamTable!examTable.action"
	ExamTypeMakeup             = "makeup"
	ExamTypeFinal              = "final"
	makeupExamBatchDisplayName = "开学补考"
	finalExamBatchDisplayName  = "期末考试"
)

// ListBatches 先写入目标 semester.id，再读取考试入口。
// EAMS 会按这个 Cookie 直接渲染目标学期的批次，无需额外提交学期切换表单。
func ListBatches(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	semesterID string,
) ([]Batch, error) {
	if err := validateID(semesterID, "semester ID"); err != nil {
		return nil, err
	}
	semesterID = strings.TrimSpace(semesterID)
	if err := setSemesterCookie(client, baseURL, semesterID); err != nil {
		return nil, err
	}
	entryURL := resolvePath(baseURL, entryPath)
	entryResp, entryErr := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8").
		Get(entryURL.String())
	body, err := responseBody(entryResp, entryErr, entryURL, "exam-entry")
	if err != nil {
		return nil, err
	}
	return ParseBatches(body)
}

func setSemesterCookie(client *resty.Client, baseURL *url.URL, semesterID string) error {
	jar := client.GetClient().Jar
	if jar == nil {
		return jwxterr.WithMessage(jwxterr.ErrExamQueryFailed, "cookie jar not configured")
	}
	eamsURL := resolvePath(baseURL, "/eams/")
	jar.SetCookies(eamsURL, []*http.Cookie{{
		Name: "semester.id", Value: semesterID, Path: "/eams/",
	}})
	return nil
}

// GetExamsByType 让调用方使用稳定的考试类型；真实 examBatch.id 仍按学期动态解析。
func GetExamsByType(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	semesterID string,
	examType string,
) ([]Exam, error) {
	batchName, err := examBatchName(examType)
	if err != nil {
		return nil, err
	}
	batches, err := ListBatches(ctx, client, baseURL, semesterID)
	if err != nil {
		return nil, err
	}
	for _, batch := range batches {
		if batch.Name == batchName {
			return GetExams(ctx, client, baseURL, batch.ID)
		}
	}
	return []Exam{}, nil
}

// GetExams 查询一个考试批次的考场表。批次 ID 必须来自 ListBatches，
// 因为不同学期的“期末考试”具有不同的 EAMS 内部 ID。
func GetExams(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	examBatchID string,
) ([]Exam, error) {
	if err := validateID(examBatchID, "exam batch ID"); err != nil {
		return nil, err
	}
	examBatchID = strings.TrimSpace(examBatchID)
	targetURL := resolvePath(baseURL, examTablePath)
	targetURL.RawQuery = url.Values{"examBatch.id": {examBatchID}}.Encode()
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/html, */*; q=0.01").
		SetHeader("X-Requested-With", "XMLHttpRequest").
		SetHeader("Referer", resolvePath(baseURL, entryPath).String()).
		Get(targetURL.String())
	body, err := responseBody(resp, err, targetURL, "exam-table")
	if err != nil {
		return nil, err
	}
	return ParseExams(body)
}

func responseBody(
	resp *resty.Response,
	requestErr error,
	targetURL *url.URL,
	op string,
) ([]byte, error) {
	if requestErr != nil && !(errors.Is(requestErr, resty.ErrAutoRedirectDisabled) && resp != nil) {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, op, targetURL, 0, "")
	}
	if resp == nil {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, op, targetURL, 0, "empty response")
	}
	status := resp.StatusCode()
	if status >= http.StatusMultipleChoices && status < http.StatusBadRequest {
		return nil, jwxterr.WithURL(jwxterr.ErrSessionExpired, op, targetURL, status, "redirected from EAMS")
	}
	if status < http.StatusOK || status >= http.StatusMultipleChoices {
		return nil, jwxterr.WithURL(jwxterr.ErrExamQueryFailed, op, targetURL, status, "")
	}
	return resp.Body(), nil
}

func resolvePath(baseURL *url.URL, path string) *url.URL {
	resolved := *baseURL
	resolved.Path = path
	// Struts 动态方法路由中的 ! 必须按字面量发送。
	resolved.RawPath = path
	resolved.RawQuery = ""
	resolved.Fragment = ""
	return &resolved
}

func validateID(value string, name string) error {
	if strings.TrimSpace(value) == "" {
		return jwxterr.WithMessage(jwxterr.ErrExamQueryFailed, name+" is required")
	}
	return nil
}

func examBatchName(examType string) (string, error) {
	switch strings.TrimSpace(examType) {
	case ExamTypeMakeup:
		return makeupExamBatchDisplayName, nil
	case ExamTypeFinal:
		return finalExamBatchDisplayName, nil
	default:
		return "", jwxterr.WithMessage(jwxterr.ErrExamQueryFailed, "unsupported exam type")
	}
}
