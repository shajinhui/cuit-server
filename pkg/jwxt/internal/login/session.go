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
