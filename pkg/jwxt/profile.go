package jwxt

import (
	"context"
	"errors"
	"net/url"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	profileflow "cuit-server/pkg/jwxt/internal/profile"
)

type StudentProfile = profileflow.StudentProfile

// GetStudentProfile 查询当前登录学生的学籍信息。
func (c *Client) GetStudentProfile(ctx context.Context) (StudentProfile, error) {
	if !c.loggedIn {
		return StudentProfile{}, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return StudentProfile{}, jwxterr.WithMessage(ErrProfileQueryFailed, "invalid EAMS base URL")
	}
	profile, err := profileflow.GetStudentProfile(ctx, c.resty, baseURL)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return profile, err
}
