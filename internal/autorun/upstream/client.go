package upstream

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

var clubSuccessCodes = map[int]struct{}{
	10000: {},
	1000:  {},
}

// Client calls the fixed tanmasports HTTP API.  It does not retry requests;
// in particular a timeout after a mutation may mean that the upstream already
// accepted it, so sending the mutation a second time would be unsafe.
type Client struct {
	httpClient       *http.Client
	appKey           string
	appSecret        string
	baseURL          string
	timeout          time.Duration
	maxResponseBytes int64
	userAgent        string
}

// NewClient creates a client with standard net/http.  A custom Transport can
// inspect requests or return fixture responses without any real network call.
// The production base URL is fixed to run-lb.tanmasports.com; BaseURL exists
// only to make httptest.Server-based tests convenient.
func NewClient(options Options) *Client {
	httpClient := options.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{}
	} else {
		copy := *httpClient
		httpClient = &copy
	}
	if options.Transport != nil {
		httpClient.Transport = options.Transport
	}
	// Never let net/http automatically follow a redirect.  A 307/308 can
	// replay a POST body and would violate the single-send mutation contract.
	httpClient.CheckRedirect = func(_ *http.Request, _ []*http.Request) error {
		return http.ErrUseLastResponse
	}

	timeout := options.Timeout
	if timeout <= 0 {
		timeout = DefaultTimeout
	}
	maxBody := options.MaxResponseBytes
	if maxBody <= 0 {
		maxBody = DefaultMaxBodyBytes
	}
	base := strings.TrimSpace(options.BaseURL)
	if base == "" {
		base = BaseURL
	}
	if !strings.HasSuffix(base, "/") {
		base += "/"
	}
	agent := options.UserAgent
	if agent == "" {
		agent = UserAgent
	}

	return &Client{
		httpClient:       httpClient,
		appKey:           options.AppKey,
		appSecret:        options.AppSecret,
		baseURL:          base,
		timeout:          timeout,
		maxResponseBytes: maxBody,
		userAgent:        agent,
	}
}

// New is a short constructor alias for callers that prefer the package-level
// name used by other clients in this repository.
func New(options Options) *Client { return NewClient(options) }

// NewClientWithTransport is a compact test-friendly constructor.
func NewClientWithTransport(appKey, appSecret string, transport http.RoundTripper) *Client {
	return NewClient(Options{AppKey: appKey, AppSecret: appSecret, Transport: transport})
}

// UpstreamError preserves the safe error metadata needed by the action layer
// without retaining request bodies, tokens, cookies, or redirect URLs.
type UpstreamError struct {
	Operation string
	Status    int
	Code      int
	Expired   bool
	Cause     error
}

func (e *UpstreamError) Error() string {
	if e == nil {
		return ""
	}
	message := e.Operation
	if e.Status != 0 {
		message += fmt.Sprintf(" (HTTP %d)", e.Status)
	}
	if e.Code != 0 {
		message += fmt.Sprintf(" (code %d)", e.Code)
	}
	if e.Cause != nil {
		message += ": " + e.Cause.Error()
	}
	return message
}

func (e *UpstreamError) Unwrap() error { return e.Cause }

// IsTokenExpired reports whether an error requires the caller to discard the
// cached upstream token and ask for a fresh login.
func IsTokenExpired(err error) bool {
	if err == nil {
		return false
	}
	var upstreamErr *UpstreamError
	if errors.As(err, &upstreamErr) {
		if upstreamErr.Expired || upstreamErr.Status == http.StatusUnauthorized {
			return true
		}
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "登录过期") ||
		strings.Contains(message, "请重新登录") ||
		strings.Contains(message, "token") ||
		strings.Contains(message, "not_login") ||
		strings.Contains(message, "unauthorized")
}

// IsTokenExpiredError is the compatibility spelling used by AutoRun-ts.
func IsTokenExpiredError(err error) bool { return IsTokenExpired(err) }

// Login performs the password login request and returns the token plus the
// three IDs used by subsequent run and club calls.  The password is MD5
// encoded only in the request body and is never stored or logged here.
func (c *Client) Login(ctx context.Context, phone, password, appVersion, brand, deviceToken, deviceType, mobileType, sysVersion string) (LoginInfo, error) {
	body := loginBody{
		AppVersion:  appVersion,
		Brand:       brand,
		DeviceToken: deviceToken,
		DeviceType:  deviceType,
		MobileType:  mobileType,
		Password:    MD5Password(password),
		SysVersion:  sysVersion,
		UserPhone:   phone,
	}
	encoded, err := json.Marshal(body)
	if err != nil {
		return LoginInfo{}, c.localError("登录失败：请求编码失败", err)
	}
	envelope, err := c.request(ctx, http.MethodPost, "v1/auth/login/password", nil, encoded, "", "登录失败", nil, false)
	if err != nil {
		return LoginInfo{}, err
	}
	user, err := decodeUserInfo(envelope.response)
	if err != nil {
		return LoginInfo{}, c.localError("登录失败：上游响应数据格式无效", err)
	}
	if user.OAuthToken.Token == "" {
		return LoginInfo{}, c.localError("登录失败：上游登录响应不完整", nil)
	}
	return LoginInfo{Token: user.OAuthToken.Token, UserID: user.UserID, StudentID: user.StudentID, SchoolID: user.SchoolID}, nil
}

func (c *Client) GetSchoolBound(ctx context.Context, token string, schoolID int64) ([]SchoolBound, error) {
	value := strconv.FormatInt(schoolID, 10)
	query := []queryParam{{key: "schoolId", value: value}}
	envelope, err := c.request(ctx, http.MethodGet, "v1/unirun/querySchoolBound", query, nil, token, "获取围栏失败", nil, false)
	if err != nil {
		return nil, err
	}
	result, err := decodeSchoolBounds(envelope.response)
	if err != nil {
		return nil, c.dataError("获取围栏失败", err)
	}
	return result, nil
}

func (c *Client) GetRunStandard(ctx context.Context, token string, schoolID int64) (RunStandard, error) {
	value := strconv.FormatInt(schoolID, 10)
	query := []queryParam{{key: "schoolId", value: value}}
	envelope, err := c.request(ctx, http.MethodGet, "v1/unirun/query/runStandard", query, nil, token, "获取标准失败", nil, false)
	if err != nil {
		return RunStandard{}, err
	}
	result, err := decodeRunStandard(envelope.response)
	if err != nil {
		return RunStandard{}, c.dataError("获取标准失败", err)
	}
	return result, nil
}

func (c *Client) RecordNew(ctx context.Context, token string, body NewRecordBody) (string, error) {
	encoded, err := json.Marshal(body)
	if err != nil {
		return "", c.localError("提交失败：请求编码失败", err)
	}
	// Mutation responses from the current upstream are inconsistent: some
	// return response:null and some omit response entirely.  The envelope code
	// is still validated, while the original JSON is returned to the caller.
	envelope, err := c.request(ctx, http.MethodPost, "v1/unirun/save/run/record/new", nil, encoded, token, "提交失败", nil, true)
	if err != nil {
		return "", err
	}
	return envelope.raw, nil
}

func (c *Client) GetSignInTask(ctx context.Context, token string, studentID int64) (*SignInTask, error) {
	value := strconv.FormatInt(studentID, 10)
	query := []queryParam{{key: "studentId", value: value}}
	envelope, err := c.request(ctx, http.MethodGet, "v1/clubactivity/getSignInTf", query, nil, token, "获取签到信息失败", clubSuccessCodes, false)
	if err != nil {
		return nil, err
	}
	result, err := decodeSignInTask(envelope.response)
	if err != nil {
		return nil, c.dataError("获取签到信息失败", err)
	}
	return result, nil
}

// GetSignInTf is the original upstream method spelling.
func (c *Client) GetSignInTf(ctx context.Context, token string, studentID int64) (*SignInTf, error) {
	return c.GetSignInTask(ctx, token, studentID)
}

func (c *Client) SignInOrSignBack(ctx context.Context, token string, body SignRequestBody) (string, error) {
	encoded, err := json.Marshal(body)
	if err != nil {
		return "", c.localError("签到/签退失败：请求编码失败", err)
	}
	envelope, err := c.request(ctx, http.MethodPost, "v1/clubactivity/signInOrSignBack", nil, encoded, token, "签到/签退失败", clubSuccessCodes, true)
	if err != nil {
		return "", err
	}
	return envelope.raw, nil
}

func (c *Client) GetClubActivities(ctx context.Context, token string, studentID int64, date string, schoolID int64) ([]ClubInfo, error) {
	query := []queryParam{
		{key: "queryTime", value: date},
		{key: "studentId", value: strconv.FormatInt(studentID, 10)},
		{key: "schoolId", value: strconv.FormatInt(schoolID, 10)},
		{key: "pageNo", value: "1"},
		{key: "pageSize", value: "15"},
	}
	envelope, err := c.request(ctx, http.MethodGet, "v1/clubactivity/queryActivityList", query, nil, token, "查询活动失败", clubSuccessCodes, false)
	if err != nil {
		return nil, err
	}
	result, err := decodeClubActivities(envelope.response)
	if err != nil {
		return nil, c.dataError("查询活动失败", err)
	}
	return result, nil
}

// GetClubActivityList is the original upstream method spelling.
func (c *Client) GetClubActivityList(ctx context.Context, token string, studentID int64, date string, schoolID int64) ([]ClubInfo, error) {
	return c.GetClubActivities(ctx, token, studentID, date, schoolID)
}

func (c *Client) JoinClubActivity(ctx context.Context, token string, studentID, activityID int64) (string, error) {
	query := []queryParam{
		{key: "studentId", value: strconv.FormatInt(studentID, 10)},
		{key: "activityId", value: strconv.FormatInt(activityID, 10)},
	}
	envelope, err := c.request(ctx, http.MethodGet, "v1/clubactivity/joinClubActivity", query, nil, token, "加入俱乐部失败", clubSuccessCodes, true)
	if err != nil {
		return "", err
	}
	return envelope.raw, nil
}

func (c *Client) CancelClubActivity(ctx context.Context, token string, studentID, activityID int64) (string, error) {
	query := []queryParam{
		{key: "studentId", value: strconv.FormatInt(studentID, 10)},
		{key: "activityId", value: strconv.FormatInt(activityID, 10)},
	}
	envelope, err := c.request(ctx, http.MethodGet, "v1/clubactivity/cancelActivity", query, nil, token, "取消报名失败", clubSuccessCodes, true)
	if err != nil {
		return "", err
	}
	return envelope.raw, nil
}

func (c *Client) GetRunInfo(ctx context.Context, token string, userID int64, yearSemester string) (RunInfo, error) {
	query := []queryParam{
		{key: "userId", value: strconv.FormatInt(userID, 10)},
		{key: "yearSemester", value: yearSemester},
	}
	envelope, err := c.request(ctx, http.MethodGet, "v1/unirun/query/runInfo", query, nil, token, "查询跑步信息失败", nil, false)
	if err != nil {
		return RunInfo{}, err
	}
	result, err := decodeRunInfo(envelope.response)
	if err != nil {
		return RunInfo{}, c.dataError("查询跑步信息失败", err)
	}
	return result, nil
}

func (c *Client) GetClubJoinProgress(ctx context.Context, token string, schoolID, studentID int64) (ClubJoinProgress, error) {
	query := []queryParam{
		{key: "schoolId", value: strconv.FormatInt(schoolID, 10)},
		{key: "studentId", value: strconv.FormatInt(studentID, 10)},
	}
	envelope, err := c.request(ctx, http.MethodGet, "v1/clubactivity/getJoinNum", query, nil, token, "查询俱乐部参与进度失败", clubSuccessCodes, false)
	if err != nil {
		return ClubJoinProgress{}, err
	}
	result, err := decodeClubJoinProgress(envelope.response)
	if err != nil {
		return ClubJoinProgress{}, c.dataError("查询俱乐部参与进度失败", err)
	}
	return result, nil
}

// GetClubJoinNum is the original upstream method spelling.
func (c *Client) GetClubJoinNum(ctx context.Context, token string, schoolID, studentID int64) (ClubJoinNum, error) {
	return c.GetClubJoinProgress(ctx, token, schoolID, studentID)
}

func (c *Client) GetTopActivities(ctx context.Context, token string) ([]ClubTopActivity, error) {
	envelope, err := c.request(ctx, http.MethodGet, "v1/clubactivity/querySchoolActivityTopThree", nil, nil, token, "查询俱乐部推荐活动失败", clubSuccessCodes, false)
	if err != nil {
		return nil, err
	}
	result, err := decodeTopActivities(envelope.response)
	if err != nil {
		return nil, c.dataError("查询俱乐部推荐活动失败", err)
	}
	return result, nil
}

// GetSchoolActivityTopThree is the original upstream method spelling.
func (c *Client) GetSchoolActivityTopThree(ctx context.Context, token string) ([]ClubTopActivity, error) {
	return c.GetTopActivities(ctx, token)
}

type loginBody struct {
	AppVersion  string `json:"appVersion"`
	Brand       string `json:"brand"`
	DeviceToken string `json:"deviceToken"`
	DeviceType  string `json:"deviceType"`
	MobileType  string `json:"mobileType"`
	Password    string `json:"password"`
	SysVersion  string `json:"sysVersion"`
	UserPhone   string `json:"userPhone"`
}

type queryParam struct {
	key   string
	value string
}

type rawEnvelope struct {
	code        int
	message     string
	response    json.RawMessage
	hasResponse bool
	raw         string
}

func (c *Client) request(ctx context.Context, method, path string, query []queryParam, body []byte, token, label string, successCodes map[int]struct{}, allowMissingResponse bool) (rawEnvelope, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	requestURL, err := c.buildURL(path, query)
	if err != nil {
		return rawEnvelope{}, c.localError(label+"：请求地址无效", err)
	}
	queryMap := make(map[string]string, len(query))
	for _, item := range query {
		queryMap[item.key] = item.value
	}
	bodyText := string(body)
	sign := GenerateSign(queryMap, bodyText, c.appKey, c.appSecret)
	requestContext := ctx
	var cancel context.CancelFunc
	if c.timeout > 0 {
		requestContext, cancel = context.WithTimeout(ctx, c.timeout)
		defer cancel()
	}

	var reader io.Reader
	if method != http.MethodGet {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(requestContext, method, requestURL, reader)
	if err != nil {
		return rawEnvelope{}, c.localError(label+"：请求创建失败", err)
	}
	req.Header.Set("sign", sign)
	req.Header.Set("appkey", c.appKey)
	req.Header.Set("token", token)
	req.Header.Set("User-Agent", c.userAgent)
	if method != http.MethodGet {
		req.Header.Set("Content-Type", "application/json; charset=UTF-8")
	}

	response, err := c.httpClient.Do(req)
	if err != nil {
		if errors.Is(requestContext.Err(), context.DeadlineExceeded) || errors.Is(ctx.Err(), context.DeadlineExceeded) {
			// A timeout says nothing about token validity.  In particular, a
			// mutation can already have been accepted when its response times
			// out, so callers must not retry it or discard a healthy session.
			return rawEnvelope{}, c.upstreamError(label+"：上游请求超时", false, 0, 0, err)
		}
		return rawEnvelope{}, c.upstreamError(label+"：上游网络请求失败", false, 0, 0, err)
	}
	if response == nil {
		return rawEnvelope{}, c.upstreamError(label+"：上游网络请求失败", false, 0, 0, errors.New("empty HTTP response"))
	}
	defer response.Body.Close()
	responseBody, err := readResponseBody(response.Body, c.maxResponseBytes)
	if err != nil {
		return rawEnvelope{}, c.upstreamError(label+"："+err.Error(), false, response.StatusCode, 0, nil)
	}
	if IsHTMLResponse(responseBody) {
		return rawEnvelope{}, c.upstreamError(label+"：上游接口被风控拦截，请稍后重试或更换网络", false, response.StatusCode, 0, nil)
	}
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return rawEnvelope{}, c.upstreamError(fmt.Sprintf("%s：上游 HTTP %d", label, response.StatusCode), response.StatusCode == http.StatusUnauthorized, response.StatusCode, 0, nil)
	}

	trimmed := bytes.TrimSpace(responseBody)
	var object map[string]json.RawMessage
	if err := json.Unmarshal(trimmed, &object); err != nil || object == nil {
		return rawEnvelope{}, c.upstreamError(label+"：上游响应不是有效 JSON", strings.TrimSpace(token) != "", response.StatusCode, 0, err)
	}
	code, ok := integerRaw(object["code"])
	if !ok {
		return rawEnvelope{}, c.upstreamError(label+"：上游响应格式无效", strings.TrimSpace(token) != "", response.StatusCode, 0, nil)
	}
	message := stringRaw(object["msg"])
	if message == "" {
		message = stringRaw(object["message"])
	}
	if successCodes == nil {
		successCodes = map[int]struct{}{10000: {}}
	}
	if _, ok := successCodes[code]; !ok {
		expired := code == 40100 || code == 30005 || code == 10001 || isTokenMessage(message)
		return rawEnvelope{}, c.upstreamError(label+"："+safeMessage(message), expired, response.StatusCode, code, nil)
	}
	responseValue, hasResponse := object["response"]
	if !allowMissingResponse && !hasResponse {
		return rawEnvelope{}, c.upstreamError(label+"：上游响应格式无效", strings.TrimSpace(token) != "", response.StatusCode, code, nil)
	}
	if !hasResponse {
		responseValue = json.RawMessage("null")
	}
	return rawEnvelope{code: code, message: message, response: responseValue, hasResponse: hasResponse, raw: string(responseBody)}, nil
}

func (c *Client) buildURL(path string, query []queryParam) (string, error) {
	parsed, err := url.Parse(c.baseURL)
	if err != nil {
		return "", err
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return "", errors.New("base URL must include scheme and host")
	}
	parsed.Path = "/" + strings.TrimPrefix(path, "/")
	parsed.RawPath = ""
	encoded := make([]string, 0, len(query))
	for _, item := range query {
		if item.value == "" {
			continue
		}
		encoded = append(encoded, url.QueryEscape(item.key)+"="+url.QueryEscape(item.value))
	}
	parsed.RawQuery = strings.Join(encoded, "&")
	return parsed.String(), nil
}

func (c *Client) localError(operation string, cause error) error {
	return &UpstreamError{Operation: operation, Cause: cause}
}

func (c *Client) dataError(label string, cause error) error {
	return &UpstreamError{Operation: label + "：上游响应数据格式无效", Cause: cause}
}

func (c *Client) upstreamError(operation string, expired bool, status, code int, cause error) error {
	return &UpstreamError{Operation: operation, Expired: expired, Status: status, Code: code, Cause: cause}
}

// IsHTMLResponse identifies common WAF HTML bodies before JSON decoding.  It
// is intentionally conservative and accepts arbitrary JSON, including JSON
// whose content happens to mention HTML.
func IsHTMLResponse(body []byte) bool {
	trimmed := strings.ToLower(strings.TrimSpace(string(body)))
	compact := strings.ReplaceAll(trimmed, " ", "")
	return strings.HasPrefix(trimmed, "<html") ||
		strings.HasPrefix(trimmed, "<!doctype") ||
		strings.HasPrefix(compact, "<!doctypehtml") ||
		strings.Contains(trimmed, "your request has been blocked") ||
		strings.Contains(trimmed, "errors.aliyun.com") ||
		strings.Contains(trimmed, "block_traceid")
}

func readResponseBody(reader io.Reader, limit int64) ([]byte, error) {
	if limit <= 0 {
		limit = DefaultMaxBodyBytes
	}
	limited := io.LimitReader(reader, limit+1)
	body, err := io.ReadAll(limited)
	if err != nil {
		return nil, fmt.Errorf("上游响应读取失败: %w", err)
	}
	if int64(len(body)) > limit {
		return nil, errors.New("上游响应过大")
	}
	return body, nil
}

func safeMessage(value string) string {
	normalized := strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(value, "\r", " "), "\n", " "))
	runes := []rune(normalized)
	if len(runes) > 200 {
		return string(runes[:200])
	}
	return normalized
}

func isTokenMessage(value string) bool {
	message := strings.ToLower(value)
	return strings.Contains(message, "token") ||
		strings.Contains(message, "not_login") ||
		strings.Contains(message, "登录过期") ||
		strings.Contains(message, "请重新登录") ||
		strings.Contains(message, "unauthorized")
}

func stringRaw(raw json.RawMessage) string {
	var value string
	if json.Unmarshal(raw, &value) == nil {
		return value
	}
	return ""
}

func integerRaw(raw json.RawMessage) (int, bool) {
	value, ok := integer64Raw(raw)
	if !ok || value > int64(math.MaxInt) || value < int64(math.MinInt) {
		return 0, false
	}
	return int(value), true
}

func integer64Raw(raw json.RawMessage) (int64, bool) {
	if len(raw) == 0 || string(raw) == "null" {
		return 0, false
	}
	var number json.Number
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.UseNumber()
	if err := decoder.Decode(&number); err == nil {
		if parsed, err := strconv.ParseInt(number.String(), 10, 64); err == nil {
			return parsed, true
		}
		parsed, err := strconv.ParseFloat(number.String(), 64)
		if err == nil && math.Trunc(parsed) == parsed && parsed >= math.MinInt64 && parsed <= math.MaxInt64 {
			return int64(parsed), true
		}
	}
	var text string
	if json.Unmarshal(raw, &text) == nil {
		parsed, err := strconv.ParseInt(strings.TrimSpace(text), 10, 64)
		return parsed, err == nil
	}
	return 0, false
}
