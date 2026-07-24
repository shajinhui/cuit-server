// Package jwxt 的成绩查询部分包装了内部的解析与请求逻辑，给上层提供简单易用的接口。
package jwxt

import (
	"context"
	"errors"
	"net/url"
	"strings"

	gradeflow "cuit-server/pkg/jwxt/internal/grade"
	"cuit-server/pkg/jwxt/internal/jwxterr"
)

// Semester 表示学期元数据（学年、学期标识、ID 等），直接重用内部解析包的类型。
type Semester = gradeflow.Semester

// Grade 表示单条成绩记录（课程名、成绩、学分等），直接重用内部解析包的类型。
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

// ListSemesters 列出该账户可查询的学期列表。返回的 Semester.ID 可直接用于 `GetGrades`。
// 注意：如果会话失效，方法会将客户端的 `loggedIn` 标志清除，调用者应处理重试或重新登录逻辑。

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

// GetGrades 根据内部的 semesterID 拉取该学期的成绩。semesterID 通常来自 `ListSemesters`。
// 若 semesterID 为空，会返回参数错误；若会话失效，会把客户端状态置为未登录。

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
