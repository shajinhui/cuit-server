import { describe, expect, it } from 'vitest'

import { buildManualCourseWeeks, createManualCourse, type ManualCourseInput } from './manualCourse'

describe('manual course model', () => {
  it('builds weekly, odd-week and even-week ranges', () => {
    expect(buildManualCourseWeeks(2, 6, 'weekly')).toEqual([2, 3, 4, 5, 6])
    expect(buildManualCourseWeeks(2, 6, 'odd')).toEqual([3, 5])
    expect(buildManualCourseWeeks(2, 6, 'even')).toEqual([2, 4, 6])
  })

  it('normalizes a valid manual course', () => {
    const course = createManualCourse(
      createInput({ name: '  自习  ', room: '  图书馆  ', repeat: 'odd' }),
      'semester-1',
      'manual-1',
    )

    expect(course).toEqual({
      id: 'manual-1',
      semesterID: 'semester-1',
      name: '自习',
      room: '图书馆',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weeks: [1, 3],
    })
  })

  it('rejects empty names and reversed section ranges', () => {
    expect(() => createManualCourse(createInput({ name: '  ' }), 'semester-1', 'manual-1')).toThrow(
      '请输入课程名称',
    )
    expect(() =>
      createManualCourse(createInput({ startSection: 4, endSection: 3 }), 'semester-1', 'manual-1'),
    ).toThrow('请选择正确的上课节次')
  })

  it('preserves an irregular week pattern while editing a course', () => {
    const course = createManualCourse(
      createInput({ startWeek: 2, endWeek: 15, weeks: [2, 4, 8, 15] }),
      'semester-1',
      'manual-1',
    )

    expect(course.weeks).toEqual([2, 4, 8, 15])
  })
})

function createInput(overrides: Partial<ManualCourseInput>): ManualCourseInput {
  return {
    name: '自习',
    room: '',
    weekday: 1,
    startSection: 1,
    endSection: 2,
    startWeek: 1,
    endWeek: 4,
    repeat: 'weekly',
    ...overrides,
  }
}
