package labms

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

const (
	userInfoPath       = "/labms/user/info"
	semesterListPath   = "/labms/semester/list"
	scheduleListPath   = "/labms/course/schedule/list/type"
	loginDirectionPath = "/unifiedlogin/v1/loginmanage/login/direction"
)

// FetchCourseTable 使用当前用户已经隔离的学校 SSO Cookie 建立 LABMS 会话，再读取整学期课表。
// LABMS 把业务状态放在 JSON status 字段中，即使未登录也可能返回 HTTP 200。
func FetchCourseTable(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	semesterName string,
) ([]ScheduleItem, error) {
	user, err := getUserInfo(ctx, client, baseURL)
	if err != nil {
		return nil, err
	}

	resolvedSemester, err := resolveSemester(ctx, client, baseURL, semesterName)
	if err != nil {
		return nil, err
	}
	// 真实个人课表页的初始化顺序是 /user/info -> /semester/list -> 本 POST。
	// userCode 同时进入 studentIds 和 teacherIds（页面在 /course/my 路由固定这样构造），
	// semester 来自学期列表中的 semesterName；status=2 和 showMode=table 是页面固定值。
	payload := scheduleRequest{
		StudentIDs:  []string{user.UserCode},
		TeacherIDs:  []string{user.UserCode},
		LabIDs:      []string{},
		ClassIDs:    []string{},
		Status:      2,
		Semester:    resolvedSemester.SemesterName,
		ShowMode:    "table",
		ToBeDeleted: 0,
	}
	var response envelope
	if err := requestJSON(ctx, client, http.MethodPost, resolve(baseURL, scheduleListPath), payload, &response); err != nil {
		return nil, err
	}
	if err := response.check("labms-course-table"); err != nil {
		return nil, err
	}
	items, err := decodeScheduleItems(response.Data)
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid LABMS schedule response")
	}
	return items, nil
}

func LoginURL(baseURL *url.URL) *url.URL {
	redirectTarget := resolve(baseURL, "/labms/")
	// redirect_url 的 hash 路由属于 URL fragment，不能作为 Path 传给 net/url，否则 # 和 ?
	// 会被编码成普通路径字符，LABMS CAS 回调会因目标上下文不匹配返回 500。
	redirectTarget.Fragment = "/course/my?lang=zh-CN"
	start := resolve(baseURL, loginDirectionPath)
	query := start.Query()
	query.Set("redirect_url", redirectTarget.String())
	start.RawQuery = query.Encode()
	return start
}

func getUserInfo(ctx context.Context, client *resty.Client, baseURL *url.URL) (userInfo, error) {
	var response envelope
	if err := requestJSON(ctx, client, http.MethodGet, resolve(baseURL, userInfoPath), nil, &response); err != nil {
		return userInfo{}, err
	}
	if err := response.check("labms-user-info"); err != nil {
		return userInfo{}, err
	}
	var user userInfo
	if err := json.Unmarshal(response.Data, &user); err != nil || strings.TrimSpace(user.UserCode) == "" {
		return userInfo{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "LABMS user code not found")
	}
	return user, nil
}

func resolveSemester(ctx context.Context, client *resty.Client, baseURL *url.URL, semesterName string) (semester, error) {
	var response envelope
	if err := requestJSON(ctx, client, http.MethodGet, resolve(baseURL, semesterListPath), nil, &response); err != nil {
		return semester{}, err
	}
	if err := response.check("labms-semesters"); err != nil {
		return semester{}, err
	}
	var semesters []semester
	if err := json.Unmarshal(response.Data, &semesters); err != nil {
		return semester{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "invalid LABMS semester response")
	}
	for _, item := range semesters {
		if strings.TrimSpace(item.SemesterName) == strings.TrimSpace(semesterName) {
			return item, nil
		}
	}
	return semester{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "LABMS semester not found")
}

func requestJSON(ctx context.Context, client *resty.Client, method string, target *url.URL, body any, output any) error {
	request := client.R().
		SetContext(ctx).
		SetHeader("Accept", "application/json, text/plain, */*").
		SetHeader("Accept-Language", "zh-CN,zh;q=0.9").
		SetHeader("Referer", resolve(target, "/labms/").String())
	if body != nil {
		request.
			SetHeader("Content-Type", "application/json").
			SetHeader("Origin", target.Scheme+"://"+target.Host).
			SetBody(body)
	}
	resp, err := request.Execute(method, target.String())
	if err != nil {
		return jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, method, target, 0, "")
	}
	if resp == nil {
		return jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, method, target, 0, "empty response")
	}
	if resp.StatusCode() < http.StatusOK || resp.StatusCode() >= http.StatusMultipleChoices {
		return jwxterr.WithURL(jwxterr.ErrCourseTableQueryFailed, method, target, resp.StatusCode(), "unexpected LABMS response")
	}
	if err := json.Unmarshal(resp.Body(), output); err != nil {
		return jwxterr.WithURL(jwxterr.ErrCourseTableQueryFailed, method, target, resp.StatusCode(), "invalid LABMS JSON response")
	}
	return nil
}

func resolve(baseURL *url.URL, path string) *url.URL {
	resolved := *baseURL
	resolved.Path = path
	resolved.RawPath = ""
	resolved.RawQuery = ""
	resolved.Fragment = ""
	return &resolved
}
