package jwxt

import (
	"context"
	"errors"
	"net/url"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	labmsflow "cuit-server/pkg/jwxt/internal/labms"
	loginflow "cuit-server/pkg/jwxt/internal/login"
)

// LoginLABMS 通过实验教学系统自己的 CAS service 建立会话。
// 凭据只在本次调用期间使用，不保存到 Client。
func (c *Client) LoginLABMS(ctx context.Context, username string, password string) error {
	loginCfg, err := c.loginConfig()
	if err != nil {
		return err
	}
	baseURL, err := url.Parse(c.cfg.LABMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return jwxterr.WithMessage(ErrUnsupportedLoginPage, "invalid LABMS base URL")
	}
	if err := loginflow.LoginTarget(ctx, c.labmsResty, loginCfg, labmsflow.LoginURL(baseURL), username, password); err != nil {
		c.labmsLoggedIn = false
		return err
	}
	c.labmsLoggedIn = true
	return nil
}

// GetLABMSCourseTable 从实验教学系统读取个人课表，并转换成现有统一课表模型。
func (c *Client) GetLABMSCourseTable(ctx context.Context, semesterID string) (CourseTable, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return CourseTable{}, jwxterr.WithMessage(ErrCourseTableQueryFailed, "semester ID is required")
	}
	if !c.loggedIn {
		return CourseTable{}, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	if !c.labmsLoggedIn {
		return CourseTable{}, jwxterr.WithMessage(ErrSessionExpired, "LABMS login required")
	}
	semesters, err := c.ListSemesters(ctx)
	if err != nil {
		return CourseTable{}, err
	}
	var selected *Semester
	for index := range semesters {
		if semesters[index].ID == semesterID {
			selected = &semesters[index]
			break
		}
	}
	if selected == nil {
		return CourseTable{}, jwxterr.WithMessage(ErrCourseTableQueryFailed, "semester metadata not found")
	}
	semesterName, err := labmsflow.SemesterName(selected.SchoolYear, selected.Term)
	if err != nil {
		return CourseTable{}, err
	}
	baseURL, err := url.Parse(c.cfg.LABMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return CourseTable{}, jwxterr.WithMessage(ErrCourseTableQueryFailed, "invalid LABMS base URL")
	}
	items, err := labmsflow.FetchCourseTable(ctx, c.labmsResty, baseURL, semesterName)
	if err != nil {
		if errors.Is(err, ErrSessionExpired) {
			c.labmsLoggedIn = false
		}
		return CourseTable{}, err
	}
	return labmsflow.ToCourseTable(items, semesterID)
}
