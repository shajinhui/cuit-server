import { describe, expect, it } from 'vitest'

import { academicCalendarURL, academicYearForDate } from './academicYear'

describe('academic calendar year', () => {
  it('uses the previous year through August', () => {
    expect(academicYearForDate(new Date(2026, 0, 1))).toEqual({ startYear: 2025, endYear: 2026 })
    expect(academicYearForDate(new Date(2026, 7, 31))).toEqual({ startYear: 2025, endYear: 2026 })
  })

  it('uses the current year from September', () => {
    expect(academicYearForDate(new Date(2026, 8, 1))).toEqual({ startYear: 2026, endYear: 2027 })
    expect(academicYearForDate(new Date(2026, 11, 31))).toEqual({ startYear: 2026, endYear: 2027 })
  })

  it('builds the public calendar image URL without fixed years', () => {
    expect(academicCalendarURL(new Date(2026, 6, 23))).toBe(
      'https://jwc.cuit.edu.cn/xl2025_2026.png',
    )
    expect(academicCalendarURL(new Date(2026, 8, 1))).toBe(
      'https://jwc.cuit.edu.cn/xl2026_2027.png',
    )
  })
})
