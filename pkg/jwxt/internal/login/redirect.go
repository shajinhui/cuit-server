package login

import (
	"context"
	"errors"
	"net/http"
	"net/url"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

type Page struct {
	URL    *url.URL
	Status int
	Body   []byte
	Steps  []Step
}

type Step struct {
	URL      *url.URL
	Status   int
	Location *url.URL
}

func follow(ctx context.Context, client *resty.Client, startURL *url.URL, maxRedirects int) (*Page, error) {
	currentURL := cloneURL(startURL)
	steps := make([]Step, 0, maxRedirects+1)

	for redirectCount := 0; ; redirectCount++ {
		resp, err := sendGet(ctx, client, currentURL)
		if err != nil {
			return nil, err
		}

		status := resp.StatusCode()
		step := Step{
			URL:    cloneURL(currentURL),
			Status: status,
		}

		location := resp.Header().Get("Location")
		if !isRedirect(status) {
			steps = append(steps, step)
			return &Page{
				URL:    cloneURL(currentURL),
				Status: status,
				Body:   resp.Body(),
				Steps:  steps,
			}, nil
		}

		if location == "" {
			return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, http.MethodGet, currentURL, status, "redirect without location")
		}
		nextURL, err := currentURL.Parse(location)
		if err != nil || nextURL.Host == "" {
			return nil, jwxterr.WithURL(jwxterr.ErrUnsupportedLoginPage, http.MethodGet, currentURL, status, "invalid redirect location")
		}
		step.Location = cloneURL(nextURL)
		steps = append(steps, step)

		if redirectCount >= maxRedirects {
			return nil, jwxterr.WithURL(jwxterr.ErrLoginVerificationFailed, http.MethodGet, currentURL, status, "too many redirects")
		}
		currentURL = cloneURL(nextURL)
	}
}

func sendGet(ctx context.Context, client *resty.Client, targetURL *url.URL) (*resty.Response, error) {
	req := client.R().SetContext(ctx)

	resp, err := req.Get(targetURL.String())
	if err != nil {
		if errors.Is(err, resty.ErrAutoRedirectDisabled) && resp != nil {
			return resp, nil
		}
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, http.MethodGet, targetURL, 0, "")
	}
	if resp == nil {
		return nil, jwxterr.WithURL(jwxterr.ErrRemoteUnavailable, http.MethodGet, targetURL, 0, "empty response")
	}
	return resp, nil
}

func isRedirect(status int) bool {
	switch status {
	case http.StatusMovedPermanently, http.StatusFound, http.StatusSeeOther, http.StatusTemporaryRedirect, http.StatusPermanentRedirect:
		return true
	default:
		return false
	}
}

func cloneURL(u *url.URL) *url.URL {
	if u == nil {
		return nil
	}
	copied := *u
	return &copied
}
