export interface AppAnnouncement {
  id: string
  title: string
  description: string
}

export interface AnnouncementViewState {
  id: string
  viewCount: number
}

export const ANNOUNCEMENT_AUTO_PRESENTATION_LIMIT = 1

export const ACTIVE_ANNOUNCEMENT: AppAnnouncement = {
  id: 'qq-community-2026-09-04',
  title: '加入成信友友交流群',
  description: '欢迎加入交流互助群，与同学讨论使用体验、反馈问题或提出建议。',
}

export function getAnnouncementViewCount(
  state: AnnouncementViewState | null,
  activeAnnouncementID: string,
): number {
  if (state?.id !== activeAnnouncementID) return 0
  return Math.max(0, Math.floor(state.viewCount))
}

export function shouldAutoPresentAnnouncement(
  state: AnnouncementViewState | null,
  activeAnnouncementID: string,
  limit = ANNOUNCEMENT_AUTO_PRESENTATION_LIMIT,
): boolean {
  return getAnnouncementViewCount(state, activeAnnouncementID) < limit
}

export function recordAnnouncementPresentation(
  state: AnnouncementViewState | null,
  activeAnnouncementID: string,
  limit = ANNOUNCEMENT_AUTO_PRESENTATION_LIMIT,
): AnnouncementViewState {
  return {
    id: activeAnnouncementID,
    viewCount: Math.min(getAnnouncementViewCount(state, activeAnnouncementID) + 1, limit),
  }
}
