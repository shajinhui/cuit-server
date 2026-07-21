package login

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/PuerkitoBio/goquery"
	"github.com/go-resty/resty/v2"
)

type PortalRoute struct {
	PageURL     *url.URL
	LoginType   string
	RedirectURL string
}

type portalLoginResponse struct {
	Code        int    `json:"code"`
	Message     string `json:"msg"`
	RedirectURI string `json:"redirect_uri"`
	RedirectURL string `json:"redirectUrl"`
}

type portalAccountRef struct {
	ID       json.RawMessage `json:"id"`
	DataType int             `json:"dataType"`
}

type portalSwitchResponse struct {
	Code        int    `json:"code"`
	Message     string `json:"msg"`
	RedirectURI string `json:"redirect_uri"`
	RedirectURL string `json:"redirectUrl"`
}

func ParsePortalRoute(baseURL *url.URL, body []byte) (*PortalRoute, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "parse-portal", baseURL, 0, "invalid portal jump html")
	}

	var routeURL *url.URL
	doc.Find("a[href]").EachWithBreak(func(_ int, link *goquery.Selection) bool {
		href, _ := link.Attr("href")
		if u := parsePortalHref(baseURL, href); u != nil {
			routeURL = u
			return false
		}
		return true
	})
	if routeURL == nil {
		return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "parse-portal", baseURL, 0, "portal login route not found")
	}

	queryPart, ok := portalRouteQuery(routeURL)
	if !ok {
		return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "parse-portal", baseURL, 0, "portal login query missing")
	}
	loginType := extractQueryValue(queryPart, "loginType")
	redirectURL := strings.TrimSpace(extractRedirectURL(queryPart))
	if redirectURL == "" {
		return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "parse-portal", baseURL, 0, "redirectUrl missing")
	}

	return &PortalRoute{
		PageURL:     routeURL,
		LoginType:   loginType,
		RedirectURL: redirectURL,
	}, nil
}

func parsePortalBridgeRedirect(baseURL *url.URL, body []byte) (*url.URL, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "portal-bridge", baseURL, 0, "invalid bridge html")
	}
	href, ok := doc.Find("a#jump[href]").First().Attr("href")
	if !ok {
		return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "portal-bridge", baseURL, 0, "jump link not found")
	}
	jumpURL, err := baseURL.Parse(strings.TrimSpace(href))
	if err != nil || jumpURL.Host == "" {
		return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "portal-bridge", baseURL, 0, "invalid jump link")
	}
	if queryPart, ok := portalRouteQuery(jumpURL); ok {
		redirectURL, err := url.Parse(extractRedirectURL(queryPart))
		if err != nil || redirectURL.Host == "" {
			return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "portal-bridge", baseURL, 0, "invalid redirectUrl")
		}
		return redirectURL, nil
	}
	return jumpURL, nil
}

func parsePortalHref(baseURL *url.URL, href string) *url.URL {
	u, err := baseURL.Parse(strings.TrimSpace(href))
	if err != nil {
		return nil
	}
	if _, ok := portalRouteQuery(u); ok {
		return u
	}
	return nil
}

func hasPortalRoute(baseURL *url.URL, body []byte) bool {
	_, err := ParsePortalRoute(baseURL, body)
	return err == nil
}

func portalRouteQuery(u *url.URL) (string, bool) {
	if u == nil {
		return "", false
	}
	if before, after, ok := strings.Cut(u.Fragment, "?"); ok && strings.Contains(before, "/login") && strings.Contains(after, "redirectUrl=") {
		return after, true
	}
	if strings.Contains(u.Path, "/login") && strings.Contains(u.RawQuery, "redirectUrl=") {
		return u.RawQuery, true
	}
	return "", false
}

func extractRedirectURL(queryPart string) string {
	return extractQueryValue(queryPart, "redirectUrl")
}

func extractQueryValue(queryPart string, key string) string {
	prefix := key + "="
	for _, part := range strings.Split(queryPart, "&") {
		if !strings.HasPrefix(part, prefix) {
			continue
		}
		raw := strings.TrimPrefix(part, prefix)
		value, err := url.QueryUnescape(raw)
		if err != nil {
			return raw
		}
		return value
	}
	return ""
}

func loginViaPortal(ctx context.Context, client *resty.Client, cfg Config, route *PortalRoute, username string, password string) error {
	if strings.TrimSpace(username) == "" || password == "" {
		return jwxterr.WithMessage(jwxterr.ErrInvalidCredentials, "empty username or password")
	}

	loginURL := resolvePortalPath(cfg.PortalBaseURL, "/api/base/login")
	result, status, err := submitPortalLogin(ctx, client, loginURL, route, username, password)
	if err != nil {
		return err
	}

	redirect := ""
	if result.Code == http.StatusFound {
		redirect = firstNonEmpty(result.RedirectURI, result.RedirectURL)
	}
	switchRedirect, err := switchSchoolAccount(ctx, client, cfg)
	if err != nil {
		return err
	}
	if redirect == "" {
		redirect = switchRedirect
	}
	if redirect == "" {
		redirect = route.RedirectURL
	}

	redirectURL, err := url.Parse(redirect)
	if err != nil || redirectURL.Host == "" {
		return jwxterr.WithURL(jwxterr.ErrLoginVerificationFailed, "portal-login", loginURL, status, "invalid portal redirect")
	}

	return followPortalRedirect(ctx, client, cfg, redirectURL)
}

func submitPortalLogin(ctx context.Context, client *resty.Client, loginURL *url.URL, route *PortalRoute, username string, password string) (portalLoginResponse, int, error) {
	payload := map[string]string{
		"username":     username,
		"password":     password,
		"validateCode": "",
		"loginType":    route.LoginType,
		"redirectUrl":  route.RedirectURL,
	}

	var result portalLoginResponse
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "application/json, text/plain, */*").
		SetHeader("Content-Type", "application/json").
		SetHeader("Origin", "https://sso.cuit.edu.cn").
		SetHeader("Referer", route.PageURL.String()).
		SetBody(payload).
		SetResult(&result).
		Post(loginURL.String())
	if err != nil {
		return result, 0, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-login", loginURL, 0, "")
	}
	if resp == nil {
		return result, 0, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-login", loginURL, 0, "empty response")
	}
	status := resp.StatusCode()
	if status < 200 || status >= 400 {
		return result, status, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-login", loginURL, status, "")
	}

	switch result.Code {
	case 0, http.StatusFound:
		return result, status, nil
	default:
		return result, status, classifyPortalLoginError(result.Message, loginURL, status)
	}
}

func switchSchoolAccount(ctx context.Context, client *resty.Client, cfg Config) (string, error) {
	refs, err := fetchPortalRefs(ctx, client, cfg)
	if err != nil {
		return "", err
	}
	for _, ref := range refs {
		if ref.DataType == 0 {
			return switchPortalAccount(ctx, client, cfg, ref)
		}
	}
	return "", jwxterr.WithURL(jwxterr.ErrLoginVerificationFailed, "portal-ref", cfg.PortalBaseURL, 0, "school account not found")
}

func fetchPortalRefs(ctx context.Context, client *resty.Client, cfg Config) ([]portalAccountRef, error) {
	refURL := resolvePortalPath(cfg.PortalBaseURL, "/api/user/ref/list")
	var refs []portalAccountRef
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "application/json, text/plain, */*").
		SetResult(&refs).
		Get(refURL.String())
	if err != nil {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-ref", refURL, 0, "")
	}
	if resp == nil {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-ref", refURL, 0, "empty response")
	}
	if resp.StatusCode() < 200 || resp.StatusCode() >= 400 {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-ref", refURL, resp.StatusCode(), "")
	}
	return refs, nil
}

func switchPortalAccount(ctx context.Context, client *resty.Client, cfg Config, ref portalAccountRef) (string, error) {
	switchURL := resolvePortalPath(cfg.PortalBaseURL, "/api/user/switch")
	var result portalSwitchResponse
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "application/json, text/plain, */*").
		SetQueryParam("id", portalRefID(ref.ID)).
		SetQueryParam("main", "true").
		SetResult(&result).
		Get(switchURL.String())
	if err != nil {
		return "", jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-switch", switchURL, 0, "")
	}
	if resp == nil {
		return "", jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-switch", switchURL, 0, "empty response")
	}
	if resp.StatusCode() < 200 || resp.StatusCode() >= 400 {
		return "", jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, "portal-switch", switchURL, resp.StatusCode(), "")
	}
	if result.Code == http.StatusFound {
		return firstNonEmpty(result.RedirectURI, result.RedirectURL), nil
	}
	if result.Code == 0 {
		return "", nil
	}
	return "", classifyPortalLoginError(result.Message, switchURL, resp.StatusCode())
}

func portalRefID(raw json.RawMessage) string {
	var text string
	if err := json.Unmarshal(raw, &text); err == nil {
		return text
	}
	return strings.TrimSpace(string(raw))
}

func followPortalRedirect(ctx context.Context, client *resty.Client, cfg Config, redirectURL *url.URL) error {
	resultPage, err := follow(ctx, client, redirectURL, cfg.MaxRedirects)
	if err != nil {
		return err
	}
	if resultPage.URL.Path == "/cas/login" {
		nextURL, err := parsePortalBridgeRedirect(resultPage.URL, resultPage.Body)
		if err != nil {
			return err
		}
		resultPage, err = follow(ctx, client, nextURL, cfg.MaxRedirects)
		if err != nil {
			return err
		}
	}
	if isLoginPage(resultPage) {
		return jwxterr.WithURL(jwxterr.ErrLoginVerificationFailed, "portal-callback", resultPage.URL, resultPage.Status, "redirected to login page")
	}
	if resultPage.Status < 200 || resultPage.Status >= 400 {
		return jwxterr.WithURL(jwxterr.ErrLoginVerificationFailed, "portal-callback", resultPage.URL, resultPage.Status, "")
	}
	return nil
}

func classifyPortalLoginError(message string, loginURL *url.URL, status int) error {
	msg := strings.TrimSpace(message)
	lower := strings.ToLower(msg)
	if strings.Contains(msg, "验证码") || strings.Contains(lower, "captcha") {
		return jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "portal-login", loginURL, status, "captcha required")
	}
	if strings.Contains(msg, "密码") || strings.Contains(msg, "账号") || strings.Contains(msg, "不存在") || strings.Contains(msg, "错误") {
		return jwxterr.WithURL(jwxterr.ErrInvalidCredentials, "portal-login", loginURL, status, msg)
	}
	if msg == "" {
		msg = "portal login failed"
	}
	return jwxterr.WithURL(jwxterr.ErrLoginVerificationFailed, "portal-login", loginURL, status, msg)
}

func resolvePortalPath(base *url.URL, path string) *url.URL {
	u := cloneURL(base)
	u.Path = path
	u.RawQuery = ""
	u.Fragment = ""
	return u
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}
