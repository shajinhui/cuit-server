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

type Client struct {
	resty    *resty.Client
	cfg      Config
	loggedIn bool
}

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
