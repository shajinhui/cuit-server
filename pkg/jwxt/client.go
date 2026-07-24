// Package jwxt 提供独立的教务系统访问 SDK（JWXT / EAMS / CAS）。
//
// 设计原则：
// - 仅封装与学校系统交互的逻辑（HTTP、登录、会话、HTML 解析）
// - 不依赖项目内部的业务层（如 DB、Redis、HTTP 框架）
// - 对外暴露简洁的客户端接口，供上层业务进行调用和编排
package jwxt

import (
	"context"
	"net/http"
	"net/http/cookiejar"
	"net/url"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	loginflow "cuit-server/pkg/jwxt/internal/login"

	"github.com/go-resty/resty/v2"
)

// Client 是 JWXT SDK 的核心客户端类型，封装了 HTTP 客户端、配置和会话状态。
// 注意：每个 Client 实例维护自己的 CookieJar（在 NewClient 中创建），以避免多用户会话混淆。
type Client struct {
	resty    *resty.Client
	cfg      Config
	loggedIn bool
}

// NewClient 创建一个新的 JWXT SDK 客户端实例。
// 返回的客户端可重复用于同一用户的多个操作（在并发场景下请为不同用户使用不同 Client 实例或不同 CookieJar）。
func NewClient(options ...Option) (*Client, error) {
	cfg := DefaultConfig()
	for _, option := range options {
		option(&cfg)
	}
	if cfg.VerifyURL == "" {
		cfg.VerifyURL = cfg.EAMSBaseURL
	}
	if cfg.PortalBaseURL == "" {
		cfg.PortalBaseURL = DefaultConfig().PortalBaseURL
	}
	if cfg.Timeout <= 0 {
		cfg.Timeout = DefaultConfig().Timeout
	}
	if cfg.MaxRedirects <= 0 {
		cfg.MaxRedirects = DefaultConfig().MaxRedirects
	}
	if cfg.UserAgent == "" {
		cfg.UserAgent = defaultUserAgent
	}
	if cfg.Output == nil {
		cfg.Output = DefaultConfig().Output
	}
	if _, err := url.ParseRequestURI(cfg.EAMSBaseURL); err != nil {
		return nil, jwxterr.WithMessage(ErrUnsupportedLoginPage, "invalid EAMS base URL")
	}
	if _, err := url.ParseRequestURI(cfg.VerifyURL); err != nil {
		return nil, jwxterr.WithMessage(ErrUnsupportedLoginPage, "invalid EAMS verify URL")
	}
	if _, err := url.ParseRequestURI(cfg.PortalBaseURL); err != nil {
		return nil, jwxterr.WithMessage(ErrUnsupportedLoginPage, "invalid portal base URL")
	}

	// 每个用户必须使用独立 CookieJar。CAS Cookie、EAMS JSESSIONID 和一次性
	// ticket 都属于某个用户的认证上下文；如果多个用户共享 CookieJar，可能出现
	// 会话串号、身份混淆和隐私泄露。
	jar, err := cookiejar.New(nil)
	if err != nil {
		return nil, jwxterr.WithMessage(ErrRemoteUnavailable, "create cookie jar failed")
	}

	restyClient := resty.New().
		SetCookieJar(jar).
		SetTimeout(cfg.Timeout).
		SetRetryCount(0).
		SetHeader("User-Agent", cfg.UserAgent).
		SetHeader("Accept", defaultAccept).
		SetHeader("Accept-Language", "zh-CN,zh;q=0.9").
		SetRedirectPolicy(resty.RedirectPolicyFunc(func(_ *http.Request, _ []*http.Request) error {
			// 保留 3xx 响应交给 SDK 自己处理，避免 Resty.NoRedirectPolicy 把正常跳转当成错误。
			return http.ErrUseLastResponse
		}))

	return &Client{
		resty: restyClient,
		cfg:   cfg,
	}, nil
}

func (c *Client) InspectLoginFlow(ctx context.Context) error {
	loginCfg, err := c.loginConfig()
	if err != nil {
		return err
	}
	return loginflow.Inspect(ctx, c.resty, loginCfg)
}

// Login 使用给定的学号/密码执行登录（包含 CAS 跳转与 EAMS 会话初始化）。
// 登录成功后，客户端会将内部状态 `loggedIn` 设为 true。
// 上层调用应传入带有超时或取消的 Context，以避免长时间阻塞。
func (c *Client) Login(ctx context.Context, username string, password string) error {
	loginCfg, err := c.loginConfig()
	if err != nil {
		return err
	}
	if err := loginflow.Login(ctx, c.resty, loginCfg, username, password); err != nil {
		c.loggedIn = false
		return err
	}
	c.loggedIn = true
	return nil
}

// IsLoggedIn 验证当前客户端是否仍保持有效会话（会触发一次远端验证）。
// 如果会话失效，返回 false 并将内部状态重置。通常用在长时间运行的进程中检测会话有效性。
func (c *Client) IsLoggedIn(ctx context.Context) (bool, error) {
	if !c.loggedIn {
		return false, nil
	}
	loginCfg, err := c.loginConfig()
	if err != nil {
		return false, err
	}
	if err := loginflow.VerifySession(ctx, c.resty, loginCfg); err != nil {
		c.loggedIn = false
		return false, err
	}
	return true, nil
}

func (c *Client) loginConfig() (loginflow.Config, error) {
	eamsURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || eamsURL.Host == "" {
		return loginflow.Config{}, jwxterr.WithMessage(ErrUnsupportedLoginPage, "invalid EAMS base URL")
	}
	verifyURL, err := url.Parse(c.cfg.VerifyURL)
	if err != nil || verifyURL.Host == "" {
		return loginflow.Config{}, jwxterr.WithMessage(ErrUnsupportedLoginPage, "invalid EAMS verify URL")
	}
	portalURL, err := url.Parse(c.cfg.PortalBaseURL)
	if err != nil || portalURL.Host == "" {
		return loginflow.Config{}, jwxterr.WithMessage(ErrUnsupportedLoginPage, "invalid portal base URL")
	}
	return loginflow.Config{
		EAMSBaseURL:   eamsURL,
		VerifyURL:     verifyURL,
		PortalBaseURL: portalURL,
		MaxRedirects:  c.cfg.MaxRedirects,
		Output:        c.cfg.Output,
	}, nil
}
