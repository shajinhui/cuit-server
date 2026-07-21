package jwxt

import (
	"io"
	"os"
	"time"
)

const (
	defaultEAMSBaseURL   = "http://jwgl.cuit.edu.cn/eams/"
	defaultPortalBaseURL = "https://ywtb.cuit.edu.cn/"
	defaultUserAgent     = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
	defaultAccept        = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
)

type Config struct {
	EAMSBaseURL   string
	VerifyURL     string
	PortalBaseURL string
	Timeout       time.Duration
	MaxRedirects  int
	UserAgent     string
	Output        io.Writer
}

type Option func(*Config)

func DefaultConfig() Config {
	return Config{
		EAMSBaseURL:   defaultEAMSBaseURL,
		VerifyURL:     defaultEAMSBaseURL,
		PortalBaseURL: defaultPortalBaseURL,
		Timeout:       15 * time.Second,
		MaxRedirects:  10,
		UserAgent:     defaultUserAgent,
		Output:        os.Stdout,
	}
}

func WithEAMSBaseURL(rawURL string) Option {
	return func(cfg *Config) {
		cfg.EAMSBaseURL = rawURL
	}
}

func WithVerifyURL(rawURL string) Option {
	return func(cfg *Config) {
		cfg.VerifyURL = rawURL
	}
}

func WithPortalBaseURL(rawURL string) Option {
	return func(cfg *Config) {
		cfg.PortalBaseURL = rawURL
	}
}

func WithTimeout(timeout time.Duration) Option {
	return func(cfg *Config) {
		cfg.Timeout = timeout
	}
}

func WithMaxRedirects(maxRedirects int) Option {
	return func(cfg *Config) {
		cfg.MaxRedirects = maxRedirects
	}
}

func WithUserAgent(userAgent string) Option {
	return func(cfg *Config) {
		cfg.UserAgent = userAgent
	}
}

func WithOutput(output io.Writer) Option {
	return func(cfg *Config) {
		cfg.Output = output
	}
}
