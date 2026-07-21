package login

import (
	"context"
	"fmt"

	"github.com/go-resty/resty/v2"
)

func Inspect(ctx context.Context, client *resty.Client, cfg Config) error {
	page, err := follow(ctx, client, cfg.EAMSBaseURL, cfg.MaxRedirects)
	if err != nil {
		return err
	}
	for _, step := range page.Steps {
		fmt.Fprintf(cfg.Output, "request: host=%s path=%s status=%d\n", step.URL.Host, safePath(step.URL), step.Status)
		if step.Location != nil {
			fmt.Fprintf(cfg.Output, "location: host=%s path=%s\n", step.Location.Host, safePath(step.Location))
		}
	}

	route, err := ParsePortalRoute(page.URL, page.Body)
	if err != nil {
		return err
	}
	fmt.Fprintf(cfg.Output, "portal: host=%s path=%s route=/login fields=loginType,redirectUrl\n", route.PageURL.Host, safePath(route.PageURL))
	return nil
}

func safePath(u interface{ EscapedPath() string }) string {
	path := u.EscapedPath()
	if path == "" {
		return "/"
	}
	return path
}
