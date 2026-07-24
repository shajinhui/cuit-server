package plancompletion

type PlanCompletionItemKind string

const (
	PlanCompletionRequirement PlanCompletionItemKind = "requirement"
	PlanCompletionCourse      PlanCompletionItemKind = "course"
)

// PlanCompletion 保存页面顶部摘要和按页面原始顺序排列的完成情况明细。
type PlanCompletion struct {
	Summary PlanCompletionSummary
	Items   []PlanCompletionItem
}

// PlanCompletionSummary 对应页面顶部的学生信息和审核结果。
type PlanCompletionSummary struct {
	StudentNo       string
	Name            string
	Grade           string
	EducationLevel  string
	StudentCategory string
	College         string
	Major           string
	RequiredCredits string
	EarnedCredits   string
	GPA             string
	AuditResult     string
	AuditTime       string
	Auditor         string
	Remark          string
}

// PlanCompletionItem 同时表达要求分类行和课程行。
// requirement 行没有课程序号、课程代码和成绩；Status 保存“是”或缺学分、缺课程等原始结果。
type PlanCompletionItem struct {
	Kind            PlanCompletionItemKind
	Sequence        string
	CourseCode      string
	Name            string
	RequiredCredits string
	EarnedCredits   string
	Score           string
	Status          string
	Remark          string
}
