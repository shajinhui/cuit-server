package relay

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"cuit-server/internal/autorun/upstream"
)

const (
	executePath      = "/internal/scheduler/execute"
	clientTimeout    = 20 * time.Second
	maxResponseBytes = 2 * 1024 * 1024
)

// Client makes every scheduled upstream call through the Worker. It never
// retries: a failed mutation can have succeeded remotely even without a reply.
type Client struct {
	baseURL    string
	secret     string
	httpClient *http.Client
	now        func() time.Time
}

func NewClient(baseURL, secret string) (*Client, error) {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	parsed, err := url.Parse(baseURL)
	if err != nil || parsed.Host == "" || (parsed.Scheme != "https" && parsed.Scheme != "http") {
		return nil, errors.New("autorun relay: invalid Worker URL")
	}
	if len(strings.TrimSpace(secret)) < 32 {
		return nil, errors.New("autorun relay: internal secret must contain at least 32 characters")
	}
	client := &http.Client{Timeout: clientTimeout}
	client.CheckRedirect = func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }
	return &Client{baseURL: baseURL, secret: secret, httpClient: client, now: time.Now}, nil
}

func (c *Client) GetClubActivityList(ctx context.Context, token string, studentID int64, date string, schoolID int64) ([]upstream.ClubInfo, error) {
	var response struct {
		Activities []upstream.ClubInfo `json:"activities"`
	}
	err := c.request(ctx, map[string]any{
		"action": "activities", "token": token, "studentId": studentID,
		"queryDate": date, "schoolId": schoolID,
	}, &response)
	return response.Activities, err
}

func (c *Client) GetSignInTf(ctx context.Context, token string, studentID int64) (*upstream.SignInTf, error) {
	var response struct {
		SignTask *upstream.SignInTf `json:"signTask"`
	}
	err := c.request(ctx, map[string]any{"action": "probe", "token": token, "studentId": studentID}, &response)
	return response.SignTask, err
}

// SignInOrSignBack exists only to satisfy the scheduler's rollback-compatible
// interface. Scheduled mutations must carry the durable action key.
func (c *Client) SignInOrSignBack(context.Context, string, upstream.SignRequestBody) (string, error) {
	return "", errors.New("autorun relay: scheduled mutation requires an action key")
}

func (c *Client) SignInOrSignBackWithKey(ctx context.Context, token, actionKey string, body upstream.SignRequestBody) (string, error) {
	var response struct {
		RawResponse string `json:"rawResponse"`
		AlreadyDone bool   `json:"alreadyDone"`
	}
	err := c.request(ctx, map[string]any{
		"action": "sign", "token": token, "studentId": body.StudentID,
		"actionKey": actionKey, "request": body,
	}, &response)
	if err != nil {
		return "", err
	}
	return response.RawResponse, nil
}

func (c *Client) request(ctx context.Context, payload any, destination any) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("autorun relay: encode request: %w", err)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+executePath, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("autorun relay: create request: %w", err)
	}
	timestamp, signature := signRequest(c.secret, http.MethodPost, executePath, body, c.now())
	request.Header.Set("Accept", "application/json")
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set(timestampHeader, timestamp)
	request.Header.Set(signatureHeader, signature)

	response, err := c.httpClient.Do(request)
	if err != nil {
		return &upstream.UpstreamError{Operation: "Worker 转发失败", Cause: err}
	}
	defer response.Body.Close()
	limited := io.LimitReader(response.Body, maxResponseBytes+1)
	responseBody, err := io.ReadAll(limited)
	if err != nil {
		return &upstream.UpstreamError{Operation: "Worker 转发失败", Status: response.StatusCode, Cause: err}
	}
	if len(responseBody) > maxResponseBytes {
		return &upstream.UpstreamError{Operation: "Worker 转发失败", Status: response.StatusCode, Cause: errors.New("response too large")}
	}
	var envelope struct {
		Code     int             `json:"code"`
		Msg      string          `json:"msg"`
		Response json.RawMessage `json:"response"`
	}
	if err := json.Unmarshal(responseBody, &envelope); err != nil {
		return &upstream.UpstreamError{Operation: "Worker 转发失败", Status: response.StatusCode, Cause: errors.New("invalid response")}
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 || envelope.Code != 10000 {
		message := strings.ReplaceAll(strings.ReplaceAll(envelope.Msg, "\r", " "), "\n", " ")
		if len(message) > 200 {
			message = message[:200]
		}
		return &upstream.UpstreamError{
			Operation: "Worker 转发失败", Status: response.StatusCode, Code: envelope.Code,
			Expired: envelope.Code == 40100 || strings.Contains(strings.ToLower(message), "token"),
			Cause:   errors.New(message),
		}
	}
	if destination == nil {
		return nil
	}
	if err := json.Unmarshal(envelope.Response, destination); err != nil {
		return &upstream.UpstreamError{Operation: "Worker 转发失败", Status: response.StatusCode, Cause: errors.New("invalid response data")}
	}
	return nil
}
