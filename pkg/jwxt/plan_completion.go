package jwxt

import (
	"context"
	"errors"
	"net/url"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	planflow "cuit-server/pkg/jwxt/internal/plancompletion"
)

type PlanCompletion = planflow.PlanCompletion

type PlanCompletionSummary = planflow.PlanCompletionSummary

type PlanCompletionItem = planflow.PlanCompletionItem

type PlanCompletionItemKind = planflow.PlanCompletionItemKind

const (
	PlanCompletionRequirement = planflow.PlanCompletionRequirement
	PlanCompletionCourse      = planflow.PlanCompletionCourse
)

// GetPlanCompletion 查询当前登录学生的培养计划完成情况。
func (c *Client) GetPlanCompletion(ctx context.Context) (PlanCompletion, error) {
	if !c.loggedIn {
		return PlanCompletion{}, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return PlanCompletion{}, jwxterr.WithMessage(ErrPlanCompletionQueryFailed, "invalid EAMS base URL")
	}
	result, err := planflow.GetPlanCompletion(ctx, c.resty, baseURL)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return result, err
}
