import type { ContactType, ListingType, MarketplaceItem } from './api'

export const campusLabels = { airport: '航空港校区', longquan: '龙泉校区' }
export const contactLabels = { wechat: '微信', qq: 'QQ', phone: '手机号' }
export const statusLabels = { on_sale: '在售', sold: '已售出', withdrawn: '已下架' }
const wantedStatusLabels = { on_sale: '求购中', sold: '已求到', withdrawn: '已关闭' }
export const listingTypes = [{ value: 'sell', label: '出售' }, { value: 'wanted', label: '求购' }] as const

export function listingTypeFromQuery(value: unknown): ListingType {
  return value === 'wanted' ? 'wanted' : 'sell'
}
export function listingStatusLabel(item: Pick<MarketplaceItem, 'listing_type' | 'status'>) {
  return (item.listing_type === 'wanted' ? wantedStatusLabels : statusLabels)[item.status]
}

export function parsePriceCents(value: string): number | null {
  const match = /^(\d{1,5})(?:\.(\d{1,2}))?$/.exec(value.trim())
  if (!match) return null
  const cents = Number(match[1]) * 100 + Number((match[2] ?? '').padEnd(2, '0'))
  return cents >= 1 && cents <= 9999999 ? cents : null
}
export function formatPrice(cents: number) {
  return (cents / 100).toFixed(2).replace(/\.00$/, '').replace(/(\.\d)0$/, '$1')
}
export function validContact(type: ContactType, value: string) {
  const contact = value.trim()
  if (!contact || contact.length > 80 || /\s/.test(contact)) return false
  if (type === 'phone') return /^1[3-9]\d{9}$/.test(contact)
  if (type === 'qq') return /^[1-9]\d{4,11}$/.test(contact)
  return true
}
