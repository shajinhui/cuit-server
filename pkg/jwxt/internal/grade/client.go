package grade

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

const (
	semesterPagePath = "/eams/teach/grade/course/person.action"
	semesterDataPath = "/eams/dataQuery.action"
	gradeSearchPath  = "/eams/teach/grade/course/person!search.action"
)

func ListSemesters(ctx context.Context, client *resty.Client, baseURL *url.URL) ([]Semester, error) {
	pageURL := resolvePath(baseURL, semesterPagePath)
	body, err := get(ctx, client, pageURL, nil, semesterPagePath, "/eams/home.action")
	if err != nil {
		return nil, err
	}
	tagID, currentSemesterID, err := ParseSemesterPage(body)
	if err != nil {
		return nil, err
	}

	dataURL := resolvePath(baseURL, semesterDataPath)
	form := map[string]string{
		"tagId":    tagID,
		"dataType": "semesterCalendar",
		"value":    currentSemesterID,
		"empty":    "false",
	}
	body, err = postForm(ctx, client, dataURL, form, semesterDataPath, "/eams/home.action")
	if err != nil {
		return nil, err
	}
	return ParseSemesters(body)
}

func GetGrades(ctx context.Context, client *resty.Client, baseURL *url.URL, semesterID string) ([]Grade, error) {
	targetURL := resolvePath(baseURL, gradeSearchPath)
	query := map[string]string{
		"semesterId":  semesterID,
		"projectType": "",
		"_":           strconv.FormatInt(time.Now().UnixMilli(), 10),
	}
	body, err := get(ctx, client, targetURL, query, gradeSearchPath, semesterPagePath)
	if err != nil {
		return nil, err
	}
	return ParseGrades(body)
}

func get(ctx context.Context, client *resty.Client, targetURL *url.URL, query map[string]string, op string, refererPath string) ([]byte, error) {
	request := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/html, */*; q=0.01").
		SetHeader("X-Requested-With", "XMLHttpRequest").
		SetHeader("Referer", resolvePath(targetURL, refererPath).String())
	for key, value := range query {
		request.SetQueryParam(key, value)
	}
	resp, err := request.Get(targetURL.String())
	return responseBody(resp, err, targetURL, op)
}

func postForm(ctx context.Context, client *resty.Client, targetURL *url.URL, form map[string]string, op string, refererPath string) ([]byte, error) {
	values := url.Values{}
	for key, value := range form {
		values.Set(key, value)
	}
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/plain, */*; q=0.01").
		SetHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8").
		SetHeader("X-Requested-With", "XMLHttpRequest").
		SetHeader("Origin", targetURL.Scheme+"://"+targetURL.Host).
		SetHeader("Referer", resolvePath(targetURL, refererPath).String()).
		SetBody(values.Encode()).
		Post(targetURL.String())
	return responseBody(resp, err, targetURL, op)
}

func responseBody(resp *resty.Response, requestErr error, targetURL *url.URL, op string) ([]byte, error) {
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
		return nil, jwxterr.WithURL(jwxterr.ErrGradeQueryFailed, op, targetURL, status, "")
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
