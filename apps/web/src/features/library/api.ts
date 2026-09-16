import { request, requestBlob } from '@/shared/api/client'

export type LibraryKind = 'seat' | 'study'

export interface LibraryArea {
  ID: string
  Name: string
  Path: string
  Available: number
  Total: number
  Leaf: boolean
  Children?: LibraryArea[]
}

export interface LibraryOpenTime {
  Start: string
  End: string
  Limit: number
}

export interface LibraryReservationPeriod {
  Start: string
  End: string
}

export interface LibraryRule {
  ID: string
  EarliestMinutes: number
  LatestMinutes: number
  MinimumMinutes: number
  MaximumMinutes: number
  CancelMinutes: number
  Deadline: string
  LaterLineTime: string
}

export interface LibrarySeat {
  ID: string
  Number: string
  Name: string
  Building: string
  Room: string
  Coordinate: string
  Status: 'available' | 'reserved' | 'unavailable'
  OnlyView: boolean
  OpenStart: string
  OpenEnd: string
  OpenTimes: LibraryOpenTime[] | null
  Reservations: LibraryReservationPeriod[] | null
  Rule: LibraryRule
}

export interface LibraryReservation {
  UUID: string
  ReservationID: string
  Kind: LibraryKind
  Name: string
  Building: string
  Room: string
  Seat: string
  Start: string
  End: string
  ActualEnd: string
  Status: number
  StatusLabel: string
  CanCancel: boolean
  CanTemporaryLeave: boolean
  CanFinish: boolean
  TemporaryLeaveUntil: string
  ViolationReason: string
}

export interface LibraryCapabilities {
  CaptchaMode: 'none' | 'image' | 'interactive'
  MemoMaximumLength: number
  MemoRequired: boolean
  TemporaryLeave: boolean
  FinishEarly: boolean
  OfficialURL: string
}

export interface LibrarySeatQuery {
  kind: LibraryKind
  roomID: string
  startDate: string
  endDate: string
  startTime: string
  endTime: string
}

export interface LibraryCreateRequest {
  Kind: LibraryKind
  RoomID: string
  SeatID: string
  StartDate: string
  EndDate: string
  StartTime: string
  EndTime: string
  Title: string
  Memo: string
  Captcha: string
}

export interface LibraryOperationResult {
  Message: string
  Detail?: string
}

export function getLibraryCapabilities() {
  return request<LibraryCapabilities>('/api/v1/library/capabilities')
}

export function listLibraryAreas(kind: LibraryKind) {
  return request<LibraryArea[]>(`/api/v1/library/areas?kind=${kind}`)
}

export function listLibrarySeats(query: LibrarySeatQuery) {
  const parameters = new URLSearchParams({
    kind: query.kind,
    room_id: query.roomID,
    start_date: query.startDate,
    end_date: query.endDate,
    start_time: query.startTime,
    end_time: query.endTime,
  })
  return request<LibrarySeat[]>(`/api/v1/library/seats?${parameters}`)
}

export function listLibraryReservations(startDate = '', endDate = '') {
  const parameters = new URLSearchParams()
  if (startDate) parameters.set('start_date', startDate)
  if (endDate) parameters.set('end_date', endDate)
  const suffix = parameters.size ? `?${parameters}` : ''
  return request<LibraryReservation[]>(`/api/v1/library/reservations${suffix}`)
}

export function createLibraryReservation(payload: LibraryCreateRequest) {
  return request<LibraryOperationResult>('/api/v1/library/reservations', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export function cancelLibraryReservation(uuid: string) {
  return request<LibraryOperationResult>(
    `/api/v1/library/reservations/${encodeURIComponent(uuid)}`,
    { method: 'DELETE' },
  )
}

export function finishLibraryReservation(uuid: string) {
  return request<LibraryOperationResult>(
    `/api/v1/library/reservations/${encodeURIComponent(uuid)}/finish`,
    { method: 'POST' },
  )
}

export function temporaryLeaveLibraryReservation(uuid: string, reservationID: string) {
  return request<LibraryOperationResult>(
    `/api/v1/library/reservations/${encodeURIComponent(uuid)}/temporary-leave`,
    {
      method: 'POST',
      body: JSON.stringify({ ReservationID: reservationID }),
    },
  )
}

export function getLibraryCaptcha() {
  return requestBlob(`/api/v1/library/captcha?t=${Date.now()}`)
}
