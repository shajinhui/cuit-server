import { describe, expect, it } from 'vitest'

import { currentSchoolWeek, semesterWeekForDate } from './semesterCalendar'

describe('published semester calendars', () => {
  it.each([
    [2024, 9, 2, 1], [2025, 2, 24, 1], [2025, 9, 8, 1],
    [2026, 3, 2, 1], [2026, 7, 19, 20], [2026, 7, 20, 0],
    [2026, 9, 6, 0], [2026, 9, 7, 1], [2026, 9, 13, 1], [2026, 9, 14, 2],
    [2027, 1, 17, 19], [2027, 1, 18, 0],
    [2027, 2, 21, 0], [2027, 2, 22, 1], [2027, 2, 28, 1], [2027, 3, 1, 2],
    [2027, 7, 4, 19], [2027, 7, 5, 0],
  ])('maps %i-%i-%i to current week %i independently of cached data', (year, month, day, week) => {
    expect(currentSchoolWeek(new Date(year, month - 1, day))).toBe(week)
  })

  it('returns unknown rather than guessing a March start for unpublished years', () => {
    expect(currentSchoolWeek(new Date(2031, 2, 1))).toBeNull()
    expect(semesterWeekForDate(undefined, new Date())).toBeNull()
  })
})
