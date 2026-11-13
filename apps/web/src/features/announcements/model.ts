import type { OnlineAnnouncement } from './api'

export interface AnnouncementViewState {
  id: string
  viewCount: number
}

export const ANNOUNCEMENT_AUTO_PRESENTATION_LIMIT = 2

/**
 * 旧版 PWA 与 Capacitor 网页套壳共用的前端公告。
 *
 * 这条公告不依赖后台管理员发布：在线公告接口为空或暂时不可用时，
 * 旧客户端仍能提示用户前往官网获取最新版。
 */
export const LOCAL_ACTIVE_ANNOUNCEMENT: OnlineAnnouncement = {
  id: 'legacy-web-app-update-2026-11-13',
  revision: 1,
  title: '旧版客户端请更新',
  body: '如果你正在使用旧版 PWA 或旧安卓网页套壳，请前往官网下载最新版成信友友。新版已更新校园社区、页面适配和交互，旧版后续不再继续维护。',
  auto_show: true,
  action: {
    label: '前往官网下载',
    url: 'https://fanxiaogao05.dpdns.org/official',
  },
  starts_at: null,
  expires_at: null,
}

export function getAnnouncementViewCount(
  state: AnnouncementViewState | null,
  activeAnnouncementID: string,
): number {
  if (state?.id !== activeAnnouncementID || !Number.isFinite(state.viewCount)) return 0
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
