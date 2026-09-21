export type RatingBoardSort = 'newest' | 'popular'
export type RatingItemSort = 'popular' | 'newest' | 'highest' | 'lowest'
export type RatingCommentSort = 'newest' | 'oldest'
export type RatingMineKind = 'boards' | 'items' | 'votes' | 'comments'
export type RatingAdminReportStatus = 'open' | 'resolved' | 'rejected'
export type RatingAdminTargetType = 'board' | 'item' | 'comment'

export interface RatingAuthor {
  id: string
  display_name: string
  avatar_preset: number
}

export interface RatingAssetRef {
  id: string
  content_url?: string
}

export interface RatingCapabilities {
  can_edit: boolean
  can_delete: boolean
  can_rate?: boolean
  can_comment?: boolean
  can_report?: boolean
}

export interface RatingBoard {
  id: string
  title: string
  description: string
  cover_asset: RatingAssetRef | null
  creator: RatingAuthor
  item_count: number
  rating_count: number
  version: number
  created_at: string
  capabilities?: RatingCapabilities
}

export interface RatingSummary {
  count: number
  sum: number
  score: number | null
  distribution: Record<'1' | '2' | '3' | '4' | '5', number>
}

export interface UserRating {
  stars: number
  version: number
  status: 'active' | 'withdrawn' | 'excluded'
}

export interface RatingItem {
  id: string
  board_id: string
  name: string
  description: string
  image_asset: RatingAssetRef | null
  creator: RatingAuthor
  rating: RatingSummary
  version: number
  created_at: string
  capabilities?: RatingCapabilities
}

export interface RatingItemDetail extends RatingItem {
  board: Pick<RatingBoard, 'id' | 'title'>
  my_rating: UserRating | null
  comment_count: number
}

export interface RatingComment {
  id: string
  item_id: string
  parent_id: string | null
  author: RatingAuthor
  body: string
  stars_snapshot: number | null
  reply_count: number
  version: number
  created_at: string
  capabilities?: RatingCapabilities
}

export interface CursorPage<T> {
  items: T[]
  next_cursor: string | null
  has_more: boolean
}

export interface RatingAdminReport {
  id: string
  reporter_id: string
  reporter_name: string
  target_type: RatingAdminTargetType
  target_id: string
  reason: string
  status: RatingAdminReportStatus
  created_at: string
  resolved_at: string | null
}

export interface RatingAdminContentRecord {
  id: string
  status: 'published' | 'hidden' | 'deleted'
  version: number
  title?: string
  name?: string
  body?: string
  description?: string
  creator_name?: string
  author_name?: string
  created_at: string
  updated_at: string
}

export interface RatingAdminContent {
  type: RatingAdminTargetType
  content: RatingAdminContentRecord
}

export function scoreLabel(score: number | null) {
  return score === null ? '暂无评分' : score.toFixed(1)
}

export function ratingCountLabel(count: number) {
  return count > 0 ? `${count} 人评分` : '等待第一份评分'
}

export function formatRatingTime(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const now = Date.now()
  const difference = now - date.getTime()
  if (difference >= 0 && difference < 60_000) return '刚刚'
  if (difference >= 0 && difference < 3_600_000) return `${Math.floor(difference / 60_000)} 分钟前`
  if (difference >= 0 && difference < 86_400_000) return `${Math.floor(difference / 3_600_000)} 小时前`
  return new Intl.DateTimeFormat('zh-CN', {
    year: date.getFullYear() === new Date().getFullYear() ? undefined : 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date)
}

export function ratingPercentage(count: number, total: number) {
  return total > 0 ? Math.round((count / total) * 100) : 0
}

export function createRequestID() {
  return crypto.randomUUID()
}
