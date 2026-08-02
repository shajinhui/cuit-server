import { describe, expect, it } from 'vitest'

import { courseToneOptions, isCourseColorPreference, isCourseTone } from './courseColor'

describe('course color model', () => {
  it('exposes fifteen selectable course colors', () => {
    expect(courseToneOptions).toHaveLength(15)
    expect(new Set(courseToneOptions.map(({ tone }) => tone)).size).toBe(15)
  })

  it('validates persisted color preferences', () => {
    expect(
      isCourseColorPreference({
        semesterID: 'semester-1',
        courseKey: 'course-1',
        tone: 'haze-blue',
      }),
    ).toBe(true)
    expect(isCourseTone('unknown')).toBe(false)
    expect(
      isCourseColorPreference({
        semesterID: 'semester-1',
        courseKey: 'course-1',
        tone: 'unknown',
      }),
    ).toBe(false)
  })
})
