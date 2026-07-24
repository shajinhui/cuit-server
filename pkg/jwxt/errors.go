package jwxt

import "cuit-server/pkg/jwxt/internal/jwxterr"

var (
	ErrRemoteUnavailable         = jwxterr.ErrRemoteUnavailable
	ErrUnsupportedLoginPage      = jwxterr.ErrUnsupportedLoginPage
	ErrInvalidCredentials        = jwxterr.ErrInvalidCredentials
	ErrLoginVerificationFailed   = jwxterr.ErrLoginVerificationFailed
	ErrSessionExpired            = jwxterr.ErrSessionExpired
	ErrGradeQueryFailed          = jwxterr.ErrGradeQueryFailed
	ErrCourseTableQueryFailed    = jwxterr.ErrCourseTableQueryFailed
	ErrExamQueryFailed           = jwxterr.ErrExamQueryFailed
	ErrProfileQueryFailed        = jwxterr.ErrProfileQueryFailed
	ErrPlanCompletionQueryFailed = jwxterr.ErrPlanCompletionQueryFailed
)
