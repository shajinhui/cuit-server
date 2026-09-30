import type { Semester } from '@/shared/models/academic'

export type SelectValue = string | number
export type SelectVariant = 'field' | 'inline' | 'menu'
export type SelectSize = 'sm' | 'md' | 'lg'

export interface SelectOption<T extends SelectValue = SelectValue> {
  value: T
  label: string
  disabled?: boolean
}

export interface GlassSelectProps<T extends SelectValue = SelectValue> {
  modelValue: T
  options: readonly SelectOption<T>[]
  title: string
  ariaLabel?: string
  disabled?: boolean
  placeholder?: string
  variant?: SelectVariant
  size?: SelectSize
  /** Reuse the surrounding popover's material rather than nesting glass surfaces. */
  embedded?: boolean
}

export function semesterLabel(semester: Semester) {
  return `${semester.SchoolYear} · 第${semester.Term}学期`
}

export function semesterSelectOptions(semesters: readonly Semester[]): SelectOption<string>[] {
  return semesters.map(semester => ({ value: semester.ID, label: semesterLabel(semester) }))
}

interface SelectRect { left: number; top: number; bottom: number; width: number }
interface SelectViewport { left: number; top: number; width: number; height: number }

/** Keep body portals within the visible viewport, including an open mobile keyboard. */
export function selectPopoverPosition(trigger: SelectRect, viewport: SelectViewport, contentHeight: number) {
  const padding = 12
  const gap = 7
  const leftEdge = viewport.left + padding
  const rightEdge = viewport.left + viewport.width - padding
  const topEdge = viewport.top + padding
  const bottomEdge = viewport.top + viewport.height - padding
  const width = Math.max(1, Math.min(Math.max(trigger.width, 190), 300, rightEdge - leftEdge))
  const below = Math.max(0, bottomEdge - trigger.bottom - gap)
  const above = Math.max(0, trigger.top - topEdge - gap)
  const maxHeight = Math.max(1, Math.min(360, Math.max(above, below), bottomEdge - topEdge))
  const height = Math.min(Math.max(1, contentHeight), maxHeight)
  const placeBelow = below >= height || below >= above
  const preferredTop = placeBelow ? trigger.bottom + gap : trigger.top - gap - height
  return {
    top: Math.max(topEdge, Math.min(preferredTop, bottomEdge - height)),
    left: Math.max(leftEdge, Math.min(trigger.left, rightEdge - width)),
    width,
    maxHeight,
    origin: placeBelow ? 'top' : 'bottom',
  }
}
