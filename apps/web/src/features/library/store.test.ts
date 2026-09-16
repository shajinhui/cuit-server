import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useLibraryStore } from './store'

describe('library store privacy lifecycle', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('clears reservations and upstream session-derived data on logout', () => {
    const store = useLibraryStore()
    store.initialized = true
    store.capabilities = {
      CaptchaMode: 'none',
      MemoMaximumLength: 0,
      MemoRequired: false,
      TemporaryLeave: true,
      FinishEarly: true,
      OfficialURL: 'https://example.test',
    }
    store.reservations = [
      {
        UUID: 'private-reservation',
        ReservationID: '1',
        Kind: 'seat',
        Name: '测试预约',
        Building: '图书馆',
        Room: '二楼',
        Seat: 'A-18',
        Start: '2026-09-16 09:00:00',
        End: '2026-09-16 11:00:00',
        ActualEnd: '',
        Status: 2,
        StatusLabel: '待生效',
        CanCancel: true,
        CanTemporaryLeave: false,
        CanFinish: false,
        TemporaryLeaveUntil: '',
        ViolationReason: '',
      },
    ]

    store.clearData()

    expect(store.initialized).toBe(false)
    expect(store.capabilities).toBeNull()
    expect(store.reservations).toEqual([])
    expect(store.selectedRoomID).toBe('')
  })
})
