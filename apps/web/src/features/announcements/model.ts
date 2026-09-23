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
  id: 'ratings-launch-2026-09-23',
  title: '友友评分上线，来给校园生活打个分',
  description:
    '现在可以在工具页打开“友友评分”：创建评分板块、添加评分对象，分享真实评分与评论。请友善表达、尊重他人；发现不当内容时可以直接举报，也欢迎加入交流群反馈建议。',
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
