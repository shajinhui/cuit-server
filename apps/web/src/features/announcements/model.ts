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
  id: 'feedback-community-2026-09-17',
  title: '遇到问题？欢迎加群反馈',
  description:
    '使用中遇到登录、课表、成绩、校园跑等问题，欢迎加入交流群反馈；请说明设备和复现步骤，截图时注意遮挡个人信息。',
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
