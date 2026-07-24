import { describe, expect, it } from 'vitest'

import { compareSemestersNewestFirst, findCurrentSemester, type Semester } from './academic'

const futureSemester: Semester = {
  ID: 'future',
  SchoolYear: '2026-2027',
  Term: '1',
}
const currentSemester: Semester = {
  ID: 'current',
  SchoolYear: '2025-2026',
  Term: '2',
}

describe('academic semester selection', () => {
  it('uses the semester explicitly marked current instead of the newest semester', () => {
    const semesters = [
      { ...currentSemester, Current: true },
      futureSemester,
    ].sort(compareSemestersNewestFirst)

    expect(semesters[0].ID).toBe(futureSemester.ID)
    expect(findCurrentSemester(semesters)?.ID).toBe(currentSemester.ID)
  })

  it('falls back to the academic period containing the reference date', () => {
    const semesters = [futureSemester, currentSemester].sort(compareSemestersNewestFirst)

    expect(findCurrentSemester(semesters, new Date(2026, 6, 24))?.ID).toBe(currentSemester.ID)
  })
})
