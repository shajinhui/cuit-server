import { publicRatingsRequest, ratingsRequest } from '@/features/ratings'

export type AnnouncementPlatform = 'all' | 'android' | 'ios' | 'ohos' | 'web'
export type AnnouncementStatus = 'draft' | 'published' | 'archived'
export interface OnlineAnnouncement {
  id: string
  revision: number
  title: string
  body: string
  auto_show: boolean
  action: { label: string; url: string } | null
  starts_at: string | null
  expires_at: string | null
}
export interface AdminAnnouncement extends OnlineAnnouncement {
  platform: AnnouncementPlatform
  status: AnnouncementStatus
  version: number
  created_at: string
  updated_at: string
}
export interface AnnouncementInput {
  title: string; body: string; platform: AnnouncementPlatform; status: AnnouncementStatus
  auto_show: boolean; action: OnlineAnnouncement['action']; starts_at: string | null; expires_at: string | null
  expected_version: number
}

export async function fetchAnnouncements(platform: string): Promise<OnlineAnnouncement[]> {
  const data = await publicRatingsRequest<unknown>(`/api/v1/ratings/announcements?platform=${encodeURIComponent(platform)}`)
  if (!data || typeof data !== 'object' || !('items' in data) || !Array.isArray(data.items) || data.items.length > 20) throw new Error('公告响应格式异常')
  const items = data.items.map(parseOnlineAnnouncement)
  if (new Set(items.map(item => item.id)).size !== items.length) throw new Error('公告列表重复')
  return items
}
export function listAdminAnnouncements(cursor?: string) {
  return ratingsRequest<{ items: AdminAnnouncement[]; has_more: boolean; next_cursor: string | null }>(
    `/api/v1/admin/ratings/announcements${cursor ? `?cursor=${encodeURIComponent(cursor)}` : ''}`,
  )
}
export function saveAdminAnnouncement(id: string, input: AnnouncementInput) {
  return ratingsRequest<AdminAnnouncement>(`/api/v1/admin/ratings/announcements/${encodeURIComponent(id)}`, {
    method: 'PUT', body: JSON.stringify(input),
  })
}
export function parseOnlineAnnouncement(value: unknown): OnlineAnnouncement {
  if (!value || typeof value !== 'object') throw new Error('公告格式异常')
  const row = value as Record<string, unknown>
  if (typeof row.id !== 'string' || !/^[a-zA-Z0-9_-]{1,80}$/.test(row.id) || !Number.isSafeInteger(row.revision) || Number(row.revision) < 1 || typeof row.auto_show !== 'boolean') throw new Error('公告格式异常')
  const title = text(row.title, 80), body = text(row.body, 4000)
  let action: OnlineAnnouncement['action'] = null
  if (row.action != null) {
    if (typeof row.action !== 'object') throw new Error('公告按钮无效')
    const input = row.action as Record<string, unknown>
    const url = text(input.url, 2048), parsed = new URL(url)
    if (parsed.protocol !== 'https:' || !parsed.hostname || parsed.username || parsed.password || [...url].some(character => character.charCodeAt(0) <= 32)) throw new Error('公告链接无效')
    action = { label: text(input.label, 30), url }
  }
  const start = date(row.starts_at), end = date(row.expires_at)
  if (start && end && Date.parse(end) <= Date.parse(start)) throw new Error('公告时间无效')
  return { id: row.id, revision: Number(row.revision), title, body, auto_show: row.auto_show, action, starts_at: start, expires_at: end }
}
function text(value: unknown, limit: number): string {
  if (typeof value !== 'string' || !value.trim() || [...value].length > limit) throw new Error('公告文本无效')
  return value.trim()
}
function date(value: unknown): string | null {
  if (value == null) return null
  if (typeof value !== 'string' || !/(Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value))) throw new Error('公告时间无效')
  return value
}
