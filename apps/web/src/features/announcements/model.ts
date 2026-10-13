import { ANDROID_DOWNLOAD_URL } from '@/shared/config/downloads'

/** 公告里的推广位：作者用来放赞助广告，例如专属注册链接。 */
export interface AnnouncementPromotion {
  /** 角标文案，说明这是推广内容。 */
  tag: string
  /** 广告主文案。 */
  headline: string
  /** 专属链接，必须使用 HTTPS。 */
  url: string
  /** 主按钮文案。 */
  actionLabel: string
}

export interface AppAnnouncement {
  id: string
  title: string
  description: string
  /** 可选推广位，存在时公告弹窗展示专属链接入口。 */
  promotion?: AnnouncementPromotion
}

export interface AnnouncementViewState {
  id: string
  viewCount: number
}

export const ANNOUNCEMENT_AUTO_PRESENTATION_LIMIT = 2

export const ACTIVE_ANNOUNCEMENT: AppAnnouncement = {
  id: 'android-apk-1-0-0-2026-10-09',
  title: '安卓最新版已发布',
  description:
    '安卓用户请下载最新版成信友友，已修复页面布局问题。点击下方链接下载安装包。',
  promotion: {
    tag: 'Android 最新版',
    headline: '成信友友 Android 1.0.0',
    url: ANDROID_DOWNLOAD_URL,
    actionLabel: '下载最新版',
  },
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
