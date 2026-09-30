import { ratingsRequest, type CursorPage, type RatingAssetRef, type RatingAuthor } from '@/features/ratings'

export type ListingStatus = 'on_sale' | 'sold' | 'withdrawn'
export type ContactType = 'wechat' | 'qq' | 'phone'
export type Campus = 'airport' | 'longquan'
export interface MarketplaceItem {
  id: string
  title: string
  description: string
  price_cents: number
  campus: Campus
  image_asset: RatingAssetRef | null
  seller: RatingAuthor
  status: ListingStatus
  version: number
  created_at: string
  updated_at: string
  is_mine: boolean
}
export interface SellerContact {
  contact_type: ContactType
  contact_value: string
}
export interface CreateMarketplaceItem extends SellerContact {
  title: string
  description: string
  price_cents: number
  campus: Campus
  image_asset_id?: string
  create_request_id: string
}

export function listMarketplaceItems(options: { mine?: boolean; q?: string; cursor?: string } = {}) {
  const params = new URLSearchParams({ limit: '20' })
  if (options.q) params.set('q', options.q)
  if (options.cursor) params.set('cursor', options.cursor)
  return ratingsRequest<CursorPage<MarketplaceItem>>(`/api/v1/marketplace/${options.mine ? 'me/items' : 'items'}?${params}`)
}
export function getMarketplaceItem(id: string) {
  return ratingsRequest<MarketplaceItem>(`/api/v1/marketplace/items/${encodeURIComponent(id)}`)
}
export function createMarketplaceItem(input: CreateMarketplaceItem) {
  return ratingsRequest<MarketplaceItem>('/api/v1/marketplace/items', { method: 'POST', body: JSON.stringify(input) })
}
export function updateMarketplaceStatus(item: MarketplaceItem, status: ListingStatus) {
  return ratingsRequest<MarketplaceItem>(`/api/v1/marketplace/items/${encodeURIComponent(item.id)}/status`, {
    method: 'PATCH', body: JSON.stringify({ status, expected_version: item.version }),
  })
}
export function revealSellerContact(id: string) {
  return ratingsRequest<SellerContact>(`/api/v1/marketplace/items/${encodeURIComponent(id)}/contact`, { method: 'POST' })
}
