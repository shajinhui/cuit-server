import { request } from '@/shared/api/client'

export type PlanCompletionItemKind = 'requirement' | 'course'

export interface PlanCompletionSummary {
  StudentNo: string
  Name: string
  Grade: string
  EducationLevel: string
  StudentCategory: string
  College: string
  Major: string
  RequiredCredits: string
  EarnedCredits: string
  GPA: string
  AuditResult: string
  AuditTime: string
  Auditor: string
  Remark: string
}

export interface PlanCompletionItem {
  Kind: PlanCompletionItemKind
  Sequence: string
  CourseCode: string
  Name: string
  RequiredCredits: string
  EarnedCredits: string
  Score: string
  Status: string
  Remark: string
}

export interface PlanCompletion {
  Summary: PlanCompletionSummary
  Items: PlanCompletionItem[]
}

export function getPlanCompletion() {
  return request<PlanCompletion>('/api/v1/jwxt/plan-completion')
}
