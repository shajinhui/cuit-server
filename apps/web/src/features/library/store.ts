import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'

import {
  cancelLibraryAutoRenewal,
  cancelLibraryReservation,
  createLibraryReservation,
  finishLibraryReservation,
  getLibraryCapabilities,
  getLibraryRenewalOptions,
  listLibraryAutoRenewals,
  listLibraryAreas,
  listLibraryReservations,
  listLibrarySeats,
  renewLibraryReservation,
  scheduleLibraryAutoRenewal,
  temporaryLeaveLibraryReservation,
  type LibraryArea,
  type LibraryAutoRenewal,
  type LibraryCapabilities,
  type LibraryKind,
  type LibraryReservation,
  type LibrarySeat,
} from './api'
import {
  defaultLibraryStartDate,
  defaultLibraryTimes,
  flattenLibraryAreas,
  libraryDate,
} from './model'

const defaultTimes = defaultLibraryTimes()
const defaultStartDate = defaultLibraryStartDate()

export const useLibraryStore = defineStore('library', {
  state: () => ({
    initialized: false,
    initializing: false,
    initializationError: '',
    capabilities: null as LibraryCapabilities | null,
    kind: 'seat' as LibraryKind,
    areas: [] as LibraryArea[],
    selectedRoomID: '',
    loadingAreas: false,
    areaError: '',
    startDate: defaultStartDate,
    endDate: addDays(defaultStartDate, 6),
    startTime: defaultTimes.start,
    endTime: defaultTimes.end,
    seats: [] as LibrarySeat[],
    loadingSeats: false,
    hasSearched: false,
    seatError: '',
    reservations: [] as LibraryReservation[],
    loadingReservations: false,
    reservationsLoaded: false,
    reservationError: '',
    autoRenewals: [] as LibraryAutoRenewal[],
    autoRenewalError: '',
    mutating: false,
    seatRequestVersion: 0,
  }),
  getters: {
    areaOptions(state) {
      return flattenLibraryAreas(state.areas)
    },
    selectedAreaLabel(): string {
      return this.areaOptions.find((area) => area.value === this.selectedRoomID)?.label ?? ''
    },
    availableSeats(state) {
      return state.seats.filter((seat) => seat.Status === 'available' && !seat.OnlyView)
    },
    autoRenewalByReservation: (state) => (reservationID: string) =>
      state.autoRenewals.find((item) => item.ReservationID === reservationID),
  },
  actions: {
    async initialize(force = false) {
      if ((this.initialized && !force) || this.initializing) return
      if (!this.initialized) this.resetFilters()
      this.initializing = true
      this.initializationError = ''
      try {
        this.capabilities = await getLibraryCapabilities()
        await Promise.all([this.loadAreas(), this.loadReservations()])
        if (!this.selectedRoomID && this.areaOptions.length) {
          this.selectedRoomID = this.areaOptions[0].value
        }
        this.initialized = true
        useSessionStore().markAuthenticated()
      } catch (error) {
        this.handleAuthorizationError(error)
        this.initializationError = errorMessage(error, '图书馆预约服务读取失败，请稍后重试')
      } finally {
        this.initializing = false
      }
    },
    async changeKind(kind: LibraryKind) {
      if (kind === this.kind) return
      this.kind = kind
      this.selectedRoomID = ''
      this.areas = []
      this.resetSeats()
      if (kind === 'study') {
        this.startDate = libraryDate()
        this.endDate = libraryDate(6)
      } else {
        this.startDate = defaultLibraryStartDate()
        const times = defaultLibraryTimes()
        this.startTime = times.start
        this.endTime = times.end
      }
      await this.loadAreas()
      if (this.areaOptions.length) this.selectedRoomID = this.areaOptions[0].value
    },
    async loadAreas() {
      this.loadingAreas = true
      this.areaError = ''
      try {
        this.areas = await listLibraryAreas(this.kind)
        if (!this.areaOptions.some((area) => area.value === this.selectedRoomID)) {
          this.selectedRoomID = this.areaOptions[0]?.value ?? ''
        }
        return true
      } catch (error) {
        this.handleAuthorizationError(error)
        this.areaError = errorMessage(error, '预约区域读取失败')
        return false
      } finally {
        this.loadingAreas = false
      }
    },
    async searchSeats() {
      if (!this.selectedRoomID) {
        this.seatError = '请先选择预约区域'
        return false
      }
      const version = ++this.seatRequestVersion
      this.loadingSeats = true
      this.seatError = ''
      try {
        const seats = await listLibrarySeats({
          kind: this.kind,
          roomID: this.selectedRoomID,
          startDate: this.startDate,
          endDate: this.kind === 'study' ? this.endDate : this.startDate,
          startTime: this.kind === 'seat' ? this.startTime : '',
          endTime: this.kind === 'seat' ? this.endTime : '',
        })
        if (version !== this.seatRequestVersion) return false
        this.seats = seats
        this.hasSearched = true
        useSessionStore().markAuthenticated()
        return true
      } catch (error) {
        if (version !== this.seatRequestVersion) return false
        this.handleAuthorizationError(error)
        this.seatError = errorMessage(error, '可预约座位读取失败，请稍后重试')
        this.hasSearched = true
        return false
      } finally {
        if (version === this.seatRequestVersion) this.loadingSeats = false
      }
    },
    async loadReservations() {
      this.loadingReservations = true
      this.reservationError = ''
      try {
        this.reservations = await listLibraryReservations()
        this.reservationsLoaded = true
        useSessionStore().markAuthenticated()
        await this.loadAutoRenewals()
        return true
      } catch (error) {
        this.handleAuthorizationError(error)
        this.reservationError = errorMessage(error, '预约记录读取失败，请稍后重试')
        this.reservationsLoaded = true
        return false
      } finally {
        this.loadingReservations = false
      }
    },
    async loadAutoRenewals() {
      this.autoRenewalError = ''
      try {
        this.autoRenewals = await listLibraryAutoRenewals()
        return true
      } catch (error) {
        this.handleAuthorizationError(error)
        this.autoRenewalError = errorMessage(error, '自动续座状态读取失败')
        return false
      }
    },
    async create(seatID: string, memo: string, captcha: string) {
      return this.mutate(async () => {
        const result = await createLibraryReservation({
          Kind: this.kind,
          RoomID: this.selectedRoomID,
          SeatID: seatID,
          StartDate: this.startDate,
          EndDate: this.kind === 'study' ? this.endDate : this.startDate,
          StartTime: this.kind === 'seat' ? this.startTime : '',
          EndTime: this.kind === 'seat' ? this.endTime : '',
          Title: '座位预约',
          Memo: memo.trim(),
          Captcha: captcha.trim(),
        })
        await Promise.all([this.searchSeats(), this.loadReservations()])
        return result
      })
    },
    async cancel(reservation: LibraryReservation) {
      return this.mutate(async () => {
        const result = await cancelLibraryReservation(reservation.UUID)
        await this.loadReservations()
        return result
      })
    },
    async finish(reservation: LibraryReservation) {
      return this.mutate(async () => {
        const result = await finishLibraryReservation(reservation.UUID)
        await this.loadReservations()
        return result
      })
    },
    async temporaryLeave(reservation: LibraryReservation) {
      return this.mutate(async () => {
        const result = await temporaryLeaveLibraryReservation(
          reservation.UUID,
          reservation.ReservationID,
        )
        await this.loadReservations()
        return result
      })
    },
    async renewalOptions(reservation: LibraryReservation) {
      try {
        const result = await getLibraryRenewalOptions(reservation.ReservationID)
        useSessionStore().markAuthenticated()
        return result
      } catch (error) {
        this.handleAuthorizationError(error)
        throw error
      }
    },
    async renew(reservation: LibraryReservation, durationMinutes: number) {
      return this.mutate(async () => {
        const result = await renewLibraryReservation(reservation.ReservationID, durationMinutes)
        await this.loadReservations()
        return result
      })
    },
    async scheduleAutoRenewal(reservation: LibraryReservation, durationMinutes: number) {
      return this.mutate(async () => {
        const result = await scheduleLibraryAutoRenewal(
          reservation.ReservationID,
          durationMinutes,
        )
        await this.loadAutoRenewals()
        return result
      })
    },
    async cancelAutoRenewal(reservation: LibraryReservation) {
      return this.mutate(async () => {
        const result = await cancelLibraryAutoRenewal(reservation.ReservationID)
        await this.loadAutoRenewals()
        return result
      })
    },
    async mutate<T>(operation: () => Promise<T>): Promise<T> {
      if (this.mutating) throw new Error('上一项操作仍在处理中')
      this.mutating = true
      try {
        const result = await operation()
        useSessionStore().markAuthenticated()
        return result
      } catch (error) {
        this.handleAuthorizationError(error)
        throw error
      } finally {
        this.mutating = false
      }
    },
    resetSeats() {
      this.seatRequestVersion += 1
      this.seats = []
      this.hasSearched = false
      this.loadingSeats = false
      this.seatError = ''
    },
    resetFilters() {
      const startDate = defaultLibraryStartDate()
      const times = defaultLibraryTimes()
      this.startDate = startDate
      this.endDate = addDays(startDate, 6)
      this.startTime = times.start
      this.endTime = times.end
    },
    clearData() {
      this.seatRequestVersion += 1
      this.initialized = false
      this.initializing = false
      this.initializationError = ''
      this.capabilities = null
      this.kind = 'seat'
      this.areas = []
      this.selectedRoomID = ''
      this.loadingAreas = false
      this.areaError = ''
      this.seats = []
      this.loadingSeats = false
      this.hasSearched = false
      this.seatError = ''
      this.reservations = []
      this.loadingReservations = false
      this.reservationsLoaded = false
      this.reservationError = ''
      this.autoRenewals = []
      this.autoRenewalError = ''
      this.mutating = false
      this.resetFilters()
    },
    handleAuthorizationError(error: unknown) {
      if (error instanceof ApiError && error.status === 401) {
        useSessionStore().markAnonymous()
      }
    },
  },
})

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback
}

function addDays(value: string, days: number) {
  const [year, month, day] = value.split('-').map(Number)
  return libraryDate(days, new Date(year, month - 1, day, 12))
}
