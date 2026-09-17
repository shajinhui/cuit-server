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
  id: 'library-and-multiplatform-update-2026-09-17',
  title: '近期更新：图书馆与多端体验升级',
  description:
    '图书馆现已支持可视化选座、立即续座与一次性自动续座，并换用全新的日期时间选择器，解决部分 Android 设备无法正常选择时间的问题；同时完成手机横屏、平板和网页大屏适配，优化 iOS 27 顶部显示，并在 iPhone 和 iPad 的安装提示中新增“在浏览器打开”。如遇到问题，欢迎加入交流群反馈。',
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
