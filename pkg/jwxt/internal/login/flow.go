// Package login 实现了教务系统登录流（包含起始跳转、Portal 解析、Portal 登录、CAS 跳转与会话验证）。
//
// 主要职责：
// - 解析学校门户跳转路由（Portal）
// - 提交门户登录并处理学校账户切换
// - 跟随跳转完成 CAS / EAMS 会话建立
package login

import (
	"context"
	"net/url"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

func Login(ctx context.Context, client *resty.Client, cfg Config, username string, password string) error {
	// Login 按顺序执行：
	// 1. 访问 EAMS 根地址以得到跳转到 Portal 的页面
	// 2. 解析 Portal 路由并在 Portal 提交账号密码
	// 3. 跟随 Portal 重定向，完成 CAS/EAMS 会话建立
	loginPage, err := follow(ctx, client, cfg.EAMSBaseURL, cfg.MaxRedirects)
	if err != nil {
		return err
	}
	if !isCASLoginURL(loginPage.URL) {
		return jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "login-start", loginPage.URL, loginPage.Status, "final page is not CAS login")
	}

	route, err := ParsePortalRoute(loginPage.URL, loginPage.Body)
	if err != nil {
		return err
	}

	if err := loginViaPortal(ctx, client, cfg, route, username, password); err != nil {
		return err
	}
	if err := VerifySession(ctx, client, cfg); err != nil {
		return err
	}
	return nil
}

// LoginTarget 复用一网通办账号登录任意受学校 CAS 保护的业务系统。
// startURL 必须由目标系统生成，其中的 service/redirect 参数必须原样保留。
func LoginTarget(
	ctx context.Context,
	client *resty.Client,
	cfg Config,
	startURL *url.URL,
	username string,
	password string,
) error {
	loginPage, err := follow(ctx, client, startURL, cfg.MaxRedirects)
	if err != nil {
		return err
	}
	if !isCASLoginURL(loginPage.URL) {
		return jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, "target-login-start", loginPage.URL, loginPage.Status, "final page is not CAS login")
	}
	route, err := ParsePortalRoute(loginPage.URL, loginPage.Body)
	if err != nil {
		// 部分目标系统的 CAS 登录页在已有 Portal Cookie 时不再输出跳转链接。
		// 学校公开登录页对应的固定入口仍是 loginType=cas，redirectUrl 必须使用当前完整 CAS URL。
		portalPage := cloneURL(cfg.PortalBaseURL)
		portalPage.Path = "/"
		portalPage.Fragment = "/login"
		route = &PortalRoute{
			PageURL:     portalPage,
			LoginType:   "cas",
			RedirectURL: loginPage.URL.String(),
		}
	}
	return loginTargetViaPortal(ctx, client, cfg, route, username, password)
}
