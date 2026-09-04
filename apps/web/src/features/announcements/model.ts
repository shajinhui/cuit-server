export interface AppAnnouncement {
  id: string
  title: string
  description: string
}

export const ACTIVE_ANNOUNCEMENT: AppAnnouncement = {
  id: 'qq-community-2026-09-04',
  title: '加入成信友友交流群',
  description: '欢迎加入交流互助群，与同学讨论使用体验、反馈问题或提出建议。',
}

export function isAnnouncementUnread(
  seenAnnouncementID: string | null,
  activeAnnouncementID: string,
): boolean {
  return seenAnnouncementID !== activeAnnouncementID
}
