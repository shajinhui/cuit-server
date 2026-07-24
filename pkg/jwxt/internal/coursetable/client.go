package coursetable

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

const (
	entryPath       = "/eams/courseTableForStd.action"
	projectDataPath = "/eams/dataQuery.action"
	courseTablePath = "/eams/courseTableForStd!courseTable.action"
)

func GetCourseTable(ctx context.Context, client *resty.Client, baseURL *url.URL, semesterID string) (CourseTable, error) {
	// semester.id 会决定课表入口页初始化的学期。先写入目标值，避免先加载默认学期再切换。
	if err := setSemesterCookie(client, baseURL, semesterID); err != nil {
		return CourseTable{}, err
	}
	page, err := loadPageContext(ctx, client, baseURL)
	if err != nil {
		return CourseTable{}, err
	}

	// 真实浏览器会先查询入口页当前选中的学期，用这一步建立 EAMS 的课表页面上下文。
	initialBody, err := queryCourseTable(ctx, client, baseURL, page.defaultSemesterID, page.studentID, "", entryPath, "course-table-initial")
	if err != nil {
		return CourseTable{}, err
	}
	if semesterID == page.defaultSemesterID {
		return ParseCourseTable(initialBody, semesterID)
	}

	body, err := queryCourseTable(ctx, client, baseURL, semesterID, page.studentID, page.projectID, courseTablePath, "course-table-query")
	if err != nil {
		return CourseTable{}, err
	}
	return ParseCourseTable(body, semesterID)
}

func setSemesterCookie(client *resty.Client, baseURL *url.URL, semesterID string) error {
	jar := client.GetClient().Jar
	if jar == nil {
		return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "cookie jar not configured")
	}
	// EAMS 会在生成课表入口页时读取这个 Cookie，决定页面初始化的学期。
	jar.SetCookies(resolvePath(baseURL, "/eams/"), []*http.Cookie{{
		Name: "semester.id", Value: semesterID, Path: "/eams/",
	}})
	return nil
}

type pageContext struct {
	studentID         string
	defaultSemesterID string
	projectID         string
}

func loadPageContext(ctx context.Context, client *resty.Client, baseURL *url.URL) (pageContext, error) {
	entryBody, err := getEntry(ctx, client, resolvePath(baseURL, entryPath))
	if err != nil {
		return pageContext{}, err
	}
	studentID, err := ParseStudentID(entryBody)
	if err != nil {
		return pageContext{}, err
	}
	tagID, defaultSemesterID, err := ParseCalendarContext(entryBody)
	if err != nil {
		return pageContext{}, err
	}

	projectURL := resolvePath(baseURL, projectDataPath)
	// 入口页脚本从 home.action 发起初始化请求，并按页面表单顺序编码字段。
	calendarForm := "tagId=" + url.QueryEscape(tagID) +
		"&dataType=semesterCalendar&value=" + url.QueryEscape(defaultSemesterID) +
		"&empty=false"
	_, err = postEncodedForm(
		ctx, client, projectURL, calendarForm, "/eams/home.action",
		"text/plain, */*; q=0.01", "course-table-calendar",
	)
	if err != nil {
		return pageContext{}, err
	}
	projectBody, err := postEncodedForm(
		ctx, client, projectURL, "dataType=projectId", "/eams/home.action",
		"*/*", "course-table-project",
	)
	if err != nil {
		return pageContext{}, err
	}
	projectID, err := ParseProjectID(projectBody)
	if err != nil {
		return pageContext{}, err
	}
	if _, err := postEncodedForm(
		ctx, client, projectURL, "entityId=", "/eams/home.action",
		"text/plain, */*; q=0.01", "course-table-project-options",
	); err != nil {
		return pageContext{}, err
	}
	return pageContext{studentID: studentID, defaultSemesterID: defaultSemesterID, projectID: projectID}, nil
}

func queryCourseTable(ctx context.Context, client *resty.Client, baseURL *url.URL, semesterID string, studentID string, projectID string, refererPath string, op string) ([]byte, error) {
	// EAMS 浏览器页面按表单控件顺序编码字段，这里保留成功请求的原始字段顺序。
	form := "ignoreHead=1&setting.kind=std&startWeek="
	if projectID != "" {
		form += "&project.id=" + url.QueryEscape(projectID)
	}
	form += "&semester.id=" + url.QueryEscape(semesterID) + "&ids=" + url.QueryEscape(studentID)
	return postEncodedForm(ctx, client, resolvePath(baseURL, courseTablePath), form, refererPath, "*/*", op)
}

func getEntry(ctx context.Context, client *resty.Client, targetURL *url.URL) ([]byte, error) {
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/html, */*; q=0.01").
		SetHeader("X-Requested-With", "XMLHttpRequest").
		SetHeader("Referer", resolvePath(targetURL, "/eams/home.action").String()).
		Get(targetURL.String())
	return responseBody(resp, err, targetURL, "course-table-entry")
}

func postEncodedForm(ctx context.Context, client *resty.Client, targetURL *url.URL, form string, refererPath string, accept string, op string) ([]byte, error) {
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", accept).
		SetHeader("Accept-Language", "zh-CN,zh;q=0.9").
		SetHeader("Accept-Encoding", "gzip, deflate").
		SetHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8").
		SetHeader("X-Requested-With", "XMLHttpRequest").
		SetHeader("Origin", targetURL.Scheme+"://"+targetURL.Host).
		SetHeader("Referer", resolvePath(targetURL, refererPath).String()).
		SetBody(form).
		Post(targetURL.String())
	body, responseErr := responseBody(resp, err, targetURL, op)
	if responseErr != nil {
		return nil, fmt.Errorf("%w\nrequest_debug: %s", responseErr, requestDebug(resp, form))
	}
	return body, nil
}

func requestDebug(resp *resty.Response, form string) string {
	if resp == nil || resp.Request == nil || resp.Request.RawRequest == nil {
		return fmt.Sprintf("form=%q raw_request=false", form)
	}
	req := resp.Request.RawRequest
	values, _ := url.ParseQuery(form)
	cookieNames := make([]string, 0)
	cookieValues := make(map[string]string)
	for _, cookie := range req.Cookies() {
		cookieNames = append(cookieNames, cookie.Name)
		cookieValues[cookie.Name] = cookie.Value
	}
	sort.Strings(cookieNames)
	semesterCookie, semesterCookiePresent := cookieValues["semester.id"]
	jsessionID, jsessionPresent := cookieValues["JSESSIONID"]
	gsessionID, gsessionPresent := cookieValues["GSESSIONID"]
	_, ywtbSessionPresent := cookieValues["YWTBSESSIONID"]
	return fmt.Sprintf(
		"method=%s uri=%q referer=%q user_agent=%q form=%q cookie_names=%s semester_cookie_present=%t semester_cookie_matches_form=%t jsessionid_present=%t gsessionid_present=%t ywtbsessionid_present=%t jsessionid_equals_gsessionid=%t",
		req.Method,
		req.URL.RequestURI(),
		req.Referer(),
		req.UserAgent(),
		form,
		strings.Join(cookieNames, ","),
		semesterCookiePresent,
		semesterCookiePresent && semesterCookie == values.Get("semester.id"),
		jsessionPresent,
		gsessionPresent,
		ywtbSessionPresent,
		jsessionPresent && gsessionPresent && jsessionID == gsessionID,
	)
}

func responseBody(resp *resty.Response, requestErr error, targetURL *url.URL, op string) ([]byte, error) {
	if requestErr != nil && !(errors.Is(requestErr, resty.ErrAutoRedirectDisabled) && resp != nil) {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, op, targetURL, 0, "")
	}
	if resp == nil {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, op, targetURL, 0, "empty response")
	}
	status := resp.StatusCode()
	// EAMS Session 失效后会重定向到登录链路，不能把这个响应当作普通课表查询失败。
	if status >= http.StatusMultipleChoices && status < http.StatusBadRequest {
		return nil, jwxterr.WithURL(jwxterr.ErrSessionExpired, op, targetURL, status, "redirected from EAMS")
	}
	if status < http.StatusOK || status >= http.StatusMultipleChoices {
		// EAMS 的 500 页面可能只在 HTML 源码中包含具体原因，按当前诊断要求保留原始响应体。
		message := fmt.Sprintf("content_type=%q body_bytes=%d response_body=%s", resp.Header().Get("Content-Type"), len(resp.Body()), resp.String())
		return nil, jwxterr.WithURL(jwxterr.ErrCourseTableQueryFailed, op, targetURL, status, message)
	}
	return resp.Body(), nil
}

func resolvePath(baseURL *url.URL, path string) *url.URL {
	resolved := *baseURL
	resolved.Path = path
	// Struts 的动态方法路由使用字面量 !；RawPath 防止 net/url 把它改写为 %21。
	resolved.RawPath = path
	resolved.RawQuery = ""
	resolved.Fragment = ""
	return &resolved
}
