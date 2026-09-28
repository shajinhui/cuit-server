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
  id: 'sponsor-workbuddy-2026-09-29',
  title: '接了个小广告，谢谢支持',
  description:
    '作者维护需要成本，这里打一个小广告，大家动动手指支持作者：点击专属链接进去注册，然后领取积分，谢谢支持。',
  promotion: {
    tag: '作者小广告',
    headline: '点击领取 WorkBuddy 积分，让 AI 替你肝',
    url: 'https://uv.qq.com/s1gi24WP',
    actionLabel: '立即领取积分',
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
