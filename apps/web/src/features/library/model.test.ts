import { describe, expect, it } from 'vitest'

import type { LibraryArea, LibraryReservation } from './api'
import {
  defaultLibraryTimes,
  defaultLibraryStartDate,
  flattenLibraryAreas,
  formatLibraryDateTime,
  libraryDate,
  reservationLocation,
} from './model'

describe('library presentation model', () => {
  it('flattens only bookable leaf areas and preserves their full path', () => {
    const areas: LibraryArea[] = [
      {
        ID: 'building',
        Name: '图书馆',
        Path: '图书馆',
        Available: 8,
        Total: 10,
        Leaf: false,
        Children: [
          {
            ID: 'room',
            Name: '二楼阅览室',
            Path: '图书馆 / 二楼阅览室',
            Available: 8,
            Total: 10,
            Leaf: true,
          },
        ],
      },
    ]

    expect(flattenLibraryAreas(areas)).toEqual([
      { value: 'room', label: '图书馆 / 二楼阅览室', available: 8, total: 10 },
    ])
  })

  it('uses local calendar math for booking dates', () => {
    expect(libraryDate(1, new Date(2026, 8, 16, 23, 30))).toBe('2026-09-17')
  })

  it('rounds default booking time to a half hour and caps the range', () => {
    expect(defaultLibraryTimes(new Date(2026, 0, 1, 9, 10))).toEqual({
      start: '09:30',
      end: '11:30',
    })
    expect(defaultLibraryTimes(new Date(2026, 0, 1, 21, 30))).toEqual({
      start: '08:00',
      end: '10:00',
    })
    expect(defaultLibraryStartDate(new Date(2026, 0, 1, 21, 30))).toBe('2026-01-02')
  })

  it('formats reservation time and location without UTC conversion', () => {
    const reservation = {
      Building: '航空港图书馆',
      Room: '二楼',
      Seat: 'A-18',
    } as LibraryReservation
    expect(formatLibraryDateTime('2026-09-16 09:30:00')).toBe('9月16日 09:30')
    expect(reservationLocation(reservation)).toBe('航空港图书馆 · 二楼 · A-18')
  })
})
