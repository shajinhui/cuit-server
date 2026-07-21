package login

import (
	"io"
	"net/url"
)

type Config struct {
	EAMSBaseURL   *url.URL
	VerifyURL     *url.URL
	PortalBaseURL *url.URL
	MaxRedirects  int
	Output        io.Writer
}
