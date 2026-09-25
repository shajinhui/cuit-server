import { currentRatingAccessToken, clearRatingAccessToken, currentRatingAssetScope } from './auth'
import { cachedRatingAssetSource, clearRatingAssetCache } from './assetCache'
import { ratingsBlob, ratingsRequest, revokeRatingToken } from './client'
import type {
  CursorPage,
  RatingAdminContent,
  RatingAdminReport,
  RatingAdminReportStatus,
  RatingAdminTargetType,
  RatingBoard,
  RatingBoardSort,
  RatingComment,
  RatingCommentSort,
  RatingItem,
  RatingItemDetail,
  RatingItemSort,
  RatingMineKind,
  UserRating,
} from './model'

export interface CreateBoardInput {
  title: string
  description: string
  cover_asset_id?: string
  create_request_id: string
}

export interface CreateItemInput {
  name: string
  description: string
  image_asset_id?: string
  create_request_id: string
}

export interface UploadedRatingAsset {
  id: string
  width: number
  height: number
  bytes: number
}

function queryString(values: Record<string, string | number | undefined>) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== '') query.set(key, String(value))
  }
  const serialized = query.toString()
  return serialized ? `?${serialized}` : ''
}

export function listRatingBoards(options: {
  q?: string
  sort: RatingBoardSort
  cursor?: string
  limit?: number
}) {
  return ratingsRequest<CursorPage<RatingBoard>>(`/api/v1/ratings/boards${queryString(options)}`)
}

export function getRatingBoard(boardID: string) {
  return ratingsRequest<RatingBoard>(`/api/v1/ratings/boards/${encodeURIComponent(boardID)}`)
}

export function createRatingBoard(input: CreateBoardInput) {
  return ratingsRequest<RatingBoard>('/api/v1/ratings/boards', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}

export function listRatingItems(
  boardID: string,
  options: { q?: string; sort: RatingItemSort; cursor?: string; limit?: number },
) {
  return ratingsRequest<CursorPage<RatingItem>>(
    `/api/v1/ratings/boards/${encodeURIComponent(boardID)}/items${queryString(options)}`,
  )
}

export function createRatingItem(boardID: string, input: CreateItemInput) {
  return ratingsRequest<RatingItem>(
    `/api/v1/ratings/boards/${encodeURIComponent(boardID)}/items`,
    { method: 'POST', body: JSON.stringify(input) },
  )
}

export function getRatingItem(itemID: string) {
  return ratingsRequest<RatingItemDetail>(`/api/v1/ratings/items/${encodeURIComponent(itemID)}`)
}

export function submitItemRating(itemID: string, stars: number, expectedVersion: number) {
  return ratingsRequest<{ rating: RatingItemDetail['rating']; my_rating: UserRating }>(
    `/api/v1/ratings/items/${encodeURIComponent(itemID)}/rating`,
    { method: 'PUT', body: JSON.stringify({ stars, expected_version: expectedVersion }) },
  )
}

export function withdrawItemRating(itemID: string, expectedVersion: number) {
  return ratingsRequest<{ rating: RatingItemDetail['rating']; my_rating: null }>(
    `/api/v1/ratings/items/${encodeURIComponent(itemID)}/rating`,
    { method: 'DELETE', body: JSON.stringify({ expected_version: expectedVersion }) },
  )
}

export function listRatingComments(
  itemID: string,
  options: { sort: RatingCommentSort; cursor?: string; limit?: number },
) {
  return ratingsRequest<CursorPage<RatingComment>>(
    `/api/v1/ratings/items/${encodeURIComponent(itemID)}/comments${queryString(options)}`,
  )
}

export function createRatingComment(
  itemID: string,
  input: { body: string; parent_id?: string; create_request_id: string },
) {
  return ratingsRequest<RatingComment>(
    `/api/v1/ratings/items/${encodeURIComponent(itemID)}/comments`,
    { method: 'POST', body: JSON.stringify(input) },
  )
}

export function listRatingCommentReplies(
  commentID: string,
  options: { cursor?: string; limit?: number } = {},
) {
  return ratingsRequest<CursorPage<RatingComment>>(
    `/api/v1/ratings/comments/${encodeURIComponent(commentID)}/replies${queryString(options)}`,
  )
}

export function deleteRatingComment(commentID: string, expectedVersion: number) {
  return ratingsRequest<{ deleted: true }>(
    `/api/v1/ratings/comments/${encodeURIComponent(commentID)}`,
    { method: 'DELETE', body: JSON.stringify({ expected_version: expectedVersion }) },
  )
}

export function listMyRatingContent(
  kind: RatingMineKind,
  options: { cursor?: string; limit?: number } = {},
) {
  return ratingsRequest<CursorPage<RatingBoard | RatingItem | RatingComment>>(
    `/api/v1/ratings/me/content${queryString({ kind, ...options })}`,
  )
}

export function uploadRatingAsset(file: File) {
  const body = new FormData()
  body.append('file', file)
  return ratingsRequest<UploadedRatingAsset>('/api/v1/ratings/assets', { method: 'POST', body })
}

export function loadRatingAsset(assetID: string) {
  return cachedRatingAssetSource(currentRatingAssetScope(), assetID, () =>
    ratingsBlob(`/api/v1/ratings/assets/${encodeURIComponent(assetID)}/content`),
  )
}

export function createRatingReport(input: {
  target_type: 'board' | 'item' | 'comment'
  target_id: string
  reason: string
}) {
  return ratingsRequest<{ id: string; status: 'open' }>('/api/v1/ratings/reports', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}

export function listRatingAdminReports(options: {
  status: RatingAdminReportStatus
  cursor?: string
  limit?: number
}) {
  return ratingsRequest<CursorPage<RatingAdminReport>>(
    `/api/v1/admin/ratings/reports${queryString(options)}`,
  )
}

export function getRatingAdminContent(targetType: RatingAdminTargetType, targetID: string) {
  return ratingsRequest<RatingAdminContent>(
    `/api/v1/admin/ratings/content${queryString({
      target_type: targetType,
      target_id: targetID,
    })}`,
  )
}

export function createRatingModerationAction(input: {
  target_type: RatingAdminTargetType
  target_id: string
  action: 'hide' | 'restore'
  reason: string
  expected_version: number
}) {
  return ratingsRequest<{ status: 'published' | 'hidden' }>(
    '/api/v1/admin/ratings/moderation-actions',
    { method: 'POST', body: JSON.stringify(input) },
  )
}

export function updateRatingAdminReport(
  reportID: string,
  status: RatingAdminReportStatus,
) {
  return ratingsRequest<{ id: string; status: RatingAdminReportStatus }>(
    `/api/v1/admin/ratings/reports/${encodeURIComponent(reportID)}`,
    { method: 'PATCH', body: JSON.stringify({ status }) },
  )
}

export async function logoutRatingsSession() {
  const token = currentRatingAccessToken()
  if (token) await revokeRatingToken(token).catch(() => undefined)
  clearRatingAssetCache()
  clearRatingAccessToken(true)
}
