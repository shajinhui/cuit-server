package jwxt

import (
	"context"
	"errors"
	"net/url"
	"strings"

	examflow "cuit-server/pkg/jwxt/internal/exam"
	"cuit-server/pkg/jwxt/internal/jwxterr"
)

type ExamBatch = examflow.Batch

type Exam = examflow.Exam

const (
	ExamTypeMakeup = examflow.ExamTypeMakeup
	ExamTypeFinal  = examflow.ExamTypeFinal
)

// ListExamBatches 查询指定学期可用的考试批次。semesterID 来自 ListSemesters；
// 学期尚未设置排考批次时返回空列表。
func (c *Client) ListExamBatches(ctx context.Context, semesterID string) ([]ExamBatch, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return nil, jwxterr.WithMessage(ErrExamQueryFailed, "semester ID is required")
	}
	baseURL, err := c.examBaseURL()
	if err != nil {
		return nil, err
	}
	batches, err := examflow.ListBatches(ctx, c.resty, baseURL, semesterID)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return batches, err
}

// GetExams 查询一个考试批次下的考场安排。examBatchID 必须来自
// ListExamBatches，避免把不同学期的同名批次混为一谈。
func (c *Client) GetExams(ctx context.Context, examBatchID string) ([]Exam, error) {
	examBatchID = strings.TrimSpace(examBatchID)
	if examBatchID == "" {
		return nil, jwxterr.WithMessage(ErrExamQueryFailed, "exam batch ID is required")
	}
	baseURL, err := c.examBaseURL()
	if err != nil {
		return nil, err
	}
	exams, err := examflow.GetExams(ctx, c.resty, baseURL, examBatchID)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return exams, err
}

// GetExamsByType 使用稳定的考试类型查询指定学期；SDK 会在内部解析该学期真实的批次 ID。
func (c *Client) GetExamsByType(ctx context.Context, semesterID string, examType string) ([]Exam, error) {
	semesterID = strings.TrimSpace(semesterID)
	examType = strings.TrimSpace(examType)
	if semesterID == "" || examType == "" {
		return nil, jwxterr.WithMessage(ErrExamQueryFailed, "semester ID and exam type are required")
	}
	baseURL, err := c.examBaseURL()
	if err != nil {
		return nil, err
	}
	exams, err := examflow.GetExamsByType(ctx, c.resty, baseURL, semesterID, examType)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return exams, err
}

func (c *Client) examBaseURL() (*url.URL, error) {
	if !c.loggedIn {
		return nil, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return nil, jwxterr.WithMessage(ErrExamQueryFailed, "invalid EAMS base URL")
	}
	return baseURL, nil
}
