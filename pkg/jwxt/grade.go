package jwxt

import (
	"context"
	"errors"
	"net/url"
	"strings"

	gradeflow "cuit-server/pkg/jwxt/internal/grade"
	"cuit-server/pkg/jwxt/internal/jwxterr"
)

type Semester = gradeflow.Semester

type Grade = gradeflow.Grade

func (c *Client) ListSemesters(ctx context.Context) ([]Semester, error) {
	baseURL, err := c.gradeBaseURL()
	if err != nil {
		return nil, err
	}
	semesters, err := gradeflow.ListSemesters(ctx, c.resty, baseURL)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return semesters, err
}

func (c *Client) GetGrades(ctx context.Context, semesterID string) ([]Grade, error) {
	if strings.TrimSpace(semesterID) == "" {
		return nil, jwxterr.WithMessage(ErrGradeQueryFailed, "semester ID is required")
	}
	baseURL, err := c.gradeBaseURL()
	if err != nil {
		return nil, err
	}
	grades, err := gradeflow.GetGrades(ctx, c.resty, baseURL, semesterID)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return grades, err
}

func (c *Client) gradeBaseURL() (*url.URL, error) {
	if !c.loggedIn {
		return nil, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return nil, jwxterr.WithMessage(ErrGradeQueryFailed, "invalid EAMS base URL")
	}
	return baseURL, nil
}
