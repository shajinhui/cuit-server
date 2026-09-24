export const DEFAULT_NON_CURRENT_WEEK_OPACITY = 0.48
export const MIN_NON_CURRENT_WEEK_OPACITY = 0
export const MAX_NON_CURRENT_WEEK_OPACITY = 1
export const NON_CURRENT_WEEK_OPACITY_STEP = 0.05

const storageKey = 'schedule-non-current-week-opacity'

export function normalizeNonCurrentWeekOpacity(value: number) {
  if (!Number.isFinite(value)) return DEFAULT_NON_CURRENT_WEEK_OPACITY

  const clamped = Math.min(
    MAX_NON_CURRENT_WEEK_OPACITY,
    Math.max(MIN_NON_CURRENT_WEEK_OPACITY, value),
  )
  return Math.round(clamped * 100) / 100
}

export function readNonCurrentWeekOpacity() {
  if (typeof window === 'undefined') return DEFAULT_NON_CURRENT_WEEK_OPACITY

  try {
    const stored = window.localStorage.getItem(storageKey)
    return stored === null
      ? DEFAULT_NON_CURRENT_WEEK_OPACITY
      : normalizeNonCurrentWeekOpacity(Number(stored))
  } catch {
    return DEFAULT_NON_CURRENT_WEEK_OPACITY
  }
}

export function writeNonCurrentWeekOpacity(value: number) {
  const normalized = normalizeNonCurrentWeekOpacity(value)
  if (typeof window === 'undefined') return normalized

  try {
    window.localStorage.setItem(storageKey, String(normalized))
  } catch {
    // 显示偏好在当前会话仍然生效；存储受限时无需阻断课表使用。
  }
  return normalized
}
