import {
  ACTIVE_ANNOUNCEMENT,
  getAnnouncementViewCount,
  recordAnnouncementPresentation,
  type AnnouncementViewState,
} from './model'

export const APP_ANNOUNCEMENT_OPEN_EVENT = 'app:announcement:open'
export const APP_ANNOUNCEMENT_VIEW_STATE_EVENT = 'app:announcement:view-state'

const storageKey = 'app-announcement-view-state'
const legacyStorageKey = 'app-announcement-seen-id'

export function openActiveAnnouncement() {
  window.dispatchEvent(new Event(APP_ANNOUNCEMENT_OPEN_EVENT))
}

export function readActiveAnnouncementViewState(): AnnouncementViewState | null {
  try {
    const stored = window.localStorage.getItem(storageKey)
    if (stored) {
      const state = JSON.parse(stored) as Partial<AnnouncementViewState>
      if (typeof state.id === 'string' && typeof state.viewCount === 'number') {
        return { id: state.id, viewCount: state.viewCount }
      }
    }

    const legacySeenID = window.localStorage.getItem(legacyStorageKey)
    return legacySeenID ? { id: legacySeenID, viewCount: 1 } : null
  } catch {
    return null
  }
}

export function activeAnnouncementHasBeenViewed() {
  return getAnnouncementViewCount(readActiveAnnouncementViewState(), ACTIVE_ANNOUNCEMENT.id) > 0
}

export function recordActiveAnnouncementView() {
  try {
    const state = recordAnnouncementPresentation(
      readActiveAnnouncementViewState(),
      ACTIVE_ANNOUNCEMENT.id,
    )
    window.localStorage.setItem(storageKey, JSON.stringify(state))
    window.localStorage.removeItem(legacyStorageKey)
  } catch {
    // 存储受限时仍通知当前页面更新，当前会话不会再次自动弹出。
  }
  window.dispatchEvent(
    new CustomEvent(APP_ANNOUNCEMENT_VIEW_STATE_EVENT, { detail: { viewed: true } }),
  )
}
