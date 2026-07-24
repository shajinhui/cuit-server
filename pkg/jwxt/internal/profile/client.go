package profile

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

const profilePath = "/eams/stdDetail.action"

// GetStudentProfile 请求“学籍信息”页面。该菜单是普通页面 GET，不需要 AJAX 请求头或查询参数。
func GetStudentProfile(ctx context.Context, client *resty.Client, baseURL *url.URL) (StudentProfile, error) {
	targetURL := resolvePath(baseURL, profilePath)
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8").
		SetHeader("Referer", resolvePath(baseURL, "/eams/home.action").String()).
		Get(targetURL.String())
	body, err := responseBody(resp, err, targetURL)
	if err != nil {
		return StudentProfile{}, err
	}
	return ParseStudentProfile(body)
}

func responseBody(resp *resty.Response, requestErr error, targetURL *url.URL) ([]byte, error) {
	if requestErr != nil && !(errors.Is(requestErr, resty.ErrAutoRedirectDisabled) && resp != nil) {
		safeErr := jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "student-profile", targetURL, 0, "")
		return nil, fmt.Errorf("%w: %w", safeErr, requestErr)
	}
	if resp == nil {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "student-profile", targetURL, 0, "empty response")
	}
	status := resp.StatusCode()
	if status >= http.StatusMultipleChoices && status < http.StatusBadRequest {
		return nil, jwxterr.WithURL(jwxterr.ErrSessionExpired, "student-profile", targetURL, status, "redirected from EAMS")
	}
	if status < http.StatusOK || status >= http.StatusMultipleChoices {
		return nil, jwxterr.WithURL(jwxterr.ErrProfileQueryFailed, "student-profile", targetURL, status, "")
	}
	return resp.Body(), nil
}

func resolvePath(baseURL *url.URL, path string) *url.URL {
	resolved := *baseURL
	resolved.Path = path
	resolved.RawQuery = ""
	resolved.Fragment = ""
	return &resolved
}
