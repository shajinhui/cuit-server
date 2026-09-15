export const SCHEDULE_SOURCE_UPDATE_ID = 'labms-primary-100-2026-09-15'

const storageKey = 'schedule-source-update-shown-id'

export function shouldPromptScheduleSourceUpdate(seenID: string | null): boolean {
  return seenID !== SCHEDULE_SOURCE_UPDATE_ID
}

export function readScheduleSourceUpdatePrompt(): boolean {
  try {
    return shouldPromptScheduleSourceUpdate(window.localStorage.getItem(storageKey))
  } catch {
    return true
  }
}

export function recordScheduleSourceUpdatePrompt() {
  try {
    window.localStorage.setItem(storageKey, SCHEDULE_SOURCE_UPDATE_ID)
  } catch {
    // 存储受限时仍允许用户关闭当前弹窗。
  }
}
