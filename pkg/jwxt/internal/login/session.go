// Package login 的会话验证实现：通过访问 VerifyURL 判断当前 Cookie/Session 是否仍然有效。
//
// 说明：上层可以调用 VerifySession 在重要操作前确认会话是否过期，若检测到登录页则
// 返回 ErrSessionExpired，调用者应触发重新登录或提示用户。
package login

import (
	"context"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

func VerifySession(ctx context.Context, client *resty.Client, cfg Config) error {
	page, err := follow(ctx, client, cfg.VerifyURL, cfg.MaxRedirects)
	if err != nil {
		return err
	}
	if isLoginPage(page) {
		return jwxterr.WithURL(jwxterr.ErrSessionExpired, "verify-session", page.URL, page.Status, "redirected to login page")
	}
	if page.Status < 200 || page.Status >= 400 {
		return jwxterr.WithURL(jwxterr.ErrLoginVerificationFailed, "verify-session", page.URL, page.Status, "")
	}
	return nil
}
