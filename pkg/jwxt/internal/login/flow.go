package login

import (
	"context"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

func Login(ctx context.Context, client *resty.Client, cfg Config, username string, password string) error {
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
