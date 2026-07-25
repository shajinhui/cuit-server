import { describe, expect, it } from 'vitest'

import {
  buildCourseBlocks,
  buildTimeSlots,
  buildWeekDates,
  buildWeekOptions,
} from './calendar'

import type { Course, CourseActivity } from '../api'
import type { ManualCourse } from './manualCourse'

describe('schedule calendar model', () => {
  it('builds a Monday-to-Sunday strip and marks the selected date', () => {
    const dates = buildWeekDates(new Date(2026, 6, 26))

    expect(dates.map(({ label, date }) => ({ label, date }))).toEqual([
      { label: '一', date: 20 },
      { label: '二', date: 21 },
      { label: '三', date: 22 },
      { label: '四', date: 23 },
      { label: '五', date: 24 },
      { label: '六', date: 25 },
      { label: '日', date: 26 },
    ])
    expect(dates.map((date) => date.active)).toEqual([false, false, false, false, false, false, true])
  })

  it('filters invalid activities and places inactive courses after active courses', () => {
    const activeCourse = createCourse('active', [createActivity({ Weekday: 2, Weeks: [3] })])
    const inactiveCourse = createCourse('inactive', [createActivity({ Weekday: 1, Weeks: [2] })])
    const invalidCourse = createCourse('invalid', [
      createActivity({ Weekday: 0 }),
      createActivity({ StartSection: 4, EndSection: 3 }),
    ])

    const blocks = buildCourseBlocks([inactiveCourse, invalidCourse, activeCourse], 3)

    expect(blocks).toHaveLength(2)
    expect(blocks.map((block) => ({ name: block.name, muted: block.muted }))).toEqual([
      { name: 'active', muted: false },
      { name: 'inactive', muted: true },
    ])
  })

  it('extends rows and week choices when returned data exceeds the defaults', () => {
    const blocks = buildCourseBlocks(
      [createCourse('evening', [createActivity({ StartSection: 12, EndSection: 13 })])],
      1,
    )

    expect(buildTimeSlots(blocks)).toHaveLength(13)
    expect(buildTimeSlots(blocks)[12]).toEqual(['', ''])
    expect(buildWeekOptions(16, 8, 20)).toEqual(Array.from({ length: 20 }, (_, index) => index + 1))
  })

  it('merges a manual course and follows its selected weeks', () => {
    const manualCourse: ManualCourse = {
      id: 'manual-1',
      semesterID: 'semester-1',
      name: '实验室开放',
      room: 'H1201',
      weekday: 4,
      startSection: 10,
      endSection: 11,
      weeks: [2, 4],
    }

    expect(buildCourseBlocks([], 4, [manualCourse])[0]).toMatchObject({
      id: 'manual-1',
      name: '实验室开放',
      room: 'H1201',
      day: 4,
      start: 10,
      span: 2,
      muted: false,
    })
    expect(buildCourseBlocks([], 3, [manualCourse])[0].muted).toBe(true)
  })

  it('keeps the course color when the selected week is inactive', () => {
    const course = createCourse('same-course', [createActivity({ Weeks: [2] })])
    const activeBlock = buildCourseBlocks([course], 2)[0]
    const inactiveBlock = buildCourseBlocks([course], 3)[0]

    expect(inactiveBlock.muted).toBe(true)
    expect(inactiveBlock.tone).toBe(activeBlock.tone)
  })

  it('keeps course and activity details for the detail card', () => {
    const course = createCourse('编译原理', [
      createActivity({
        RoomName: 'H1208',
        Teachers: ['张老师'],
        Weeks: [1, 2, 3, 5],
      }),
    ])
    course.Code = 'CS301'
    course.Credits = '3'
    course.TeachingClass = '软件工程 1 班'
    course.Teachers = ['李老师']

    expect(buildCourseBlocks([course], 1)[0]).toMatchObject({
      room: 'H1208',
      code: 'CS301',
      credits: '3',
      teachingClass: '软件工程 1 班',
      teachers: ['李老师', '张老师'],
      weeks: [1, 2, 3, 5],
      source: 'jwxt',
    })
  })
})

function createCourse(name: string, activities: CourseActivity[]): Course {
  return {
    LessonID: name,
    Code: name,
    Name: name,
    Credits: '',
    Sequence: '',
    TeachingClass: '',
    Teachers: null,
    Activities: activities,
  }
}

function createActivity(overrides: Partial<CourseActivity>): CourseActivity {
  return {
    TeacherIDs: null,
    Teachers: null,
    RoomID: '',
    RoomName: '',
    Weekday: 1,
    StartSection: 1,
    EndSection: 2,
    Weeks: null,
    ...overrides,
  }
}
