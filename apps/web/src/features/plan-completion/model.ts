import type { PlanCompletionItem } from './api'

export type CompletionStatusTone = 'complete' | 'incomplete' | 'neutral'

export interface PlanCompletionGroup {
  requirement: PlanCompletionItem | null
  courses: PlanCompletionItem[]
}

export function creditProgress(requiredCredits: string, earnedCredits: string) {
  const required = Number.parseFloat(requiredCredits)
  const earned = Number.parseFloat(earnedCredits)
  if (!Number.isFinite(required) || !Number.isFinite(earned) || required <= 0 || earned < 0) return null
  return Math.min(100, Math.max(0, (earned / required) * 100))
}

export function completionStatusTone(status: string): CompletionStatusTone {
  const normalized = status.trim().toLowerCase()
  if (!normalized) return 'neutral'
  if (/(缺|否|未通过|不通过|未完成)/.test(normalized)) return 'incomplete'
  if (normalized === '是' || /(通过|完成|满足)/.test(normalized)) return 'complete'
  return 'neutral'
}

export function groupPlanCompletionItems(items: PlanCompletionItem[]) {
  const groups: PlanCompletionGroup[] = []
  let currentGroup: PlanCompletionGroup | undefined

  for (const item of items) {
    if (item.Kind === 'requirement') {
      currentGroup = { requirement: item, courses: [] }
      groups.push(currentGroup)
      continue
    }

    if (!currentGroup) {
      currentGroup = { requirement: null, courses: [] }
      groups.push(currentGroup)
    }
    currentGroup.courses.push(item)
  }

  return groups
}
