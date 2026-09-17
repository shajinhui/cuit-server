import type { LibraryArea, LibraryReservation, LibraryRule, LibrarySeat } from './api'

export interface LibraryAreaOption {
  value: string
  label: string
  available: number
  total: number
}

export interface LibrarySeatPosition {
  left: string
  top: string
}

export function flattenLibraryAreas(areas: LibraryArea[]): LibraryAreaOption[] {
  return areas.flatMap((area) => {
    const children = area.Children ?? []
    if (children.length) return flattenLibraryAreas(children)
    if (!area.ID) return []
    return [
      {
        value: area.ID,
        label: area.Path || area.Name,
        available: area.Available,
        total: area.Total,
      },
    ]
  })
}

export function libraryDate(offset = 0, from = new Date()) {
  const date = new Date(from)
  date.setHours(12, 0, 0, 0)
  date.setDate(date.getDate() + offset)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function defaultLibraryTimes(from = new Date()) {
  const currentMinutes = from.getHours() * 60 + from.getMinutes()
  if (currentMinutes >= 20 * 60) return { start: '08:00', end: '10:00' }
  const minutes = Math.ceil((currentMinutes + 15) / 30) * 30
  const startMinutes = Math.min(Math.max(minutes, 8 * 60), 20 * 60)
  const endMinutes = Math.min(startMinutes + 2 * 60, 22 * 60)
  return { start: minuteLabel(startMinutes), end: minuteLabel(endMinutes) }
}

export function defaultLibraryStartDate(from = new Date()) {
  return libraryDate(from.getHours() * 60 + from.getMinutes() >= 20 * 60 ? 1 : 0, from)
}

export function formatLibraryDateTime(value: string) {
  const normalized = value.trim().replace('T', ' ')
  const match = normalized.match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})/)
  if (!match) return normalized || '时间待定'
  return `${Number(match[2])}月${Number(match[3])}日 ${match[4]}:${match[5]}`
}

export function reservationLocation(reservation: LibraryReservation) {
  return [reservation.Building, reservation.Room, reservation.Seat].filter(Boolean).join(' · ') || '地点待定'
}

export function seatTitle(seat: LibrarySeat) {
  if (seat.Number && seat.Name && seat.Number !== seat.Name) return `${seat.Number} · ${seat.Name}`
  return seat.Number || seat.Name || '未命名座位'
}

export function librarySeatPosition(coordinate: string): LibrarySeatPosition | null {
  const [leftValue, topValue] = coordinate.split(',')
  const left = Number.parseFloat(leftValue ?? '')
  const top = Number.parseFloat(topValue ?? '')
  if (!Number.isFinite(left) || !Number.isFinite(top)) return null
  if (left < 0 || left > 100 || top < 0 || top > 100) return null
  return { left: `${left}%`, top: `${top}%` }
}

export function ruleSummary(rule: LibraryRule) {
  const parts: string[] = []
  if (rule.MinimumMinutes || rule.MaximumMinutes) {
    parts.push(`${rule.MinimumMinutes || 0}–${rule.MaximumMinutes || '不限'} 分钟`)
  }
  if (rule.CancelMinutes) parts.push(`开始前 ${rule.CancelMinutes} 分钟可取消`)
  return parts.join(' · ')
}

function minuteLabel(value: number) {
  const hours = Math.floor(value / 60)
  const minutes = value % 60
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`
}
