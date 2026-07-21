package jwxterr

import (
	"errors"
	"fmt"
	"net/url"
	"strings"
)

var (
	ErrRemoteUnavailable       = errors.New("jwxt: remote unavailable")
	ErrUnsupportedLoginPage    = errors.New("jwxt: unsupported login page")
	ErrInvalidCredentials      = errors.New("jwxt: invalid credentials")
	ErrLoginVerificationFailed = errors.New("jwxt: login verification failed")
	ErrSessionExpired          = errors.New("jwxt: session expired")
	ErrGradeQueryFailed        = errors.New("jwxt: grade query failed")
)

type SafeError struct {
	Kind    error
	Op      string
	Host    string
	Path    string
	Status  int
	Message string
}

func (e *SafeError) Error() string {
	var b strings.Builder
	b.WriteString(e.Kind.Error())
	if e.Op != "" {
		b.WriteString(": ")
		b.WriteString(e.Op)
	}
	if e.Host != "" {
		b.WriteString(" host=")
		b.WriteString(e.Host)
	}
	if e.Path != "" {
		b.WriteString(" path=")
		b.WriteString(e.Path)
	}
	if e.Status > 0 {
		b.WriteString(fmt.Sprintf(" status=%d", e.Status))
	}
	if e.Message != "" {
		b.WriteString(": ")
		b.WriteString(e.Message)
	}
	return b.String()
}

func (e *SafeError) Unwrap() error {
	return e.Kind
}

func WithURL(kind error, op string, u *url.URL, status int, message string) error {
	host, path := "", ""
	if u != nil {
		host = u.Host
		path = u.EscapedPath()
		if path == "" {
			path = "/"
		}
	}
	return &SafeError{
		Kind:    kind,
		Op:      op,
		Host:    host,
		Path:    path,
		Status:  status,
		Message: strings.TrimSpace(message),
	}
}

func WithMessage(kind error, message string) error {
	return &SafeError{
		Kind:    kind,
		Message: strings.TrimSpace(message),
	}
}
