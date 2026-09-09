import { describe, expect, it } from 'vitest'
import { semesterWeekForDate } from './semesterCalendar'

import {
  buildCourseBlocks,
  buildTimeSlots,
  buildWeekDates,
  buildWeekOptions,
  dateForSemesterWeek,
  scheduleCampusFromName,
} from './calendar'

import type { Course, CourseActivity } from '../api'
import type { CourseOverride } from './courseOverride'
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

  it('anchors the first week of an autumn semester to the September teaching week', () => {
    const semester = { ID: 'semester-1', SchoolYear: '2026-2027', Term: '1' }

    expect(dateForSemesterWeek(semester, 1, 1)).toEqual(new Date(2026, 8, 7))
    expect(dateForSemesterWeek(semester, 1, 5)).toEqual(new Date(2026, 8, 11))
    expect(dateForSemesterWeek(semester, 2, 1)).toEqual(new Date(2026, 8, 14))
    expect(semesterWeekForDate(semester, new Date(2026, 8, 4))).toBe(0)
    expect(semesterWeekForDate(semester, new Date(2026, 8, 13))).toBe(1)
    expect(semesterWeekForDate(semester, new Date(2026, 8, 14))).toBe(2)
  })

  it('uses the published March calendar for the 2025-2026 spring semester', () => {
    const semester = { ID: 'semester-2', SchoolYear: '2025-2026', Term: '2' }

    expect(dateForSemesterWeek(semester, 1, 1)).toEqual(new Date(2026, 2, 2))
    expect(dateForSemesterWeek(semester, 1, 5)).toEqual(new Date(2026, 2, 6))
    expect(dateForSemesterWeek(semester, 2, 1)).toEqual(new Date(2026, 2, 9))
    expect(semesterWeekForDate(semester, new Date(2026, 2, 6))).toBe(1)
    expect(semesterWeekForDate(semester, new Date(2026, 2, 9))).toBe(2)
  })

  it('uses the February start for 2026-2027 and crosses months and years correctly', () => {
    const spring = { ID: 'spring', SchoolYear: '2026-2027', Term: '2' }
    const autumn = { ...spring, Term: '1' }
    expect(dateForSemesterWeek(spring, 1, 1)).toEqual(new Date(2027, 1, 22))
    expect(dateForSemesterWeek(spring, 2, 1)).toEqual(new Date(2027, 2, 1))
    expect(dateForSemesterWeek(autumn, 17, 5)).toEqual(new Date(2027, 0, 1))
    expect(dateForSemesterWeek({ ...spring, SchoolYear: '2030-2031' }, 1, 1)).toBeNull()
    expect(dateForSemesterWeek(spring, 1.5, 1)).toBeNull()
    expect(dateForSemesterWeek(spring, 1, 8)).toBeNull()
  })

  it('uses the updated twelve-section timetable', () => {
    const slots = buildTimeSlots([])

    expect(slots).toHaveLength(12)
    expect(slots[0]).toEqual(['08:20', '09:05'])
    expect(slots[1]).toEqual(['09:15', '10:00'])
    expect(slots[8]).toEqual(['17:40', '18:25'])
    expect(slots[11]).toEqual(['21:20', '22:05'])
  })

  it('selects the timetable from the student campus', () => {
    expect(scheduleCampusFromName('龙泉校区')).toBe('longquan')
    expect(scheduleCampusFromName('龙泉驿区')).toBe('longquan')
    expect(scheduleCampusFromName('航空港校区')).toBe('airport')
    expect(scheduleCampusFromName(undefined)).toBe('airport')

    const history = { ID: 'history', SchoolYear: '2025-2026', Term: '2' }
    const airportSlots = buildTimeSlots([], 'airport', history)
    const longquanSlots = buildTimeSlots([], 'longquan', history)
    expect(airportSlots.slice(0, 2)).toEqual([
      ['08:20', '09:05'],
      ['09:15', '10:00'],
    ])
    expect(longquanSlots.slice(0, 2)).toEqual([
      ['08:30', '09:15'],
      ['09:25', '10:10'],
    ])
    expect(longquanSlots.slice(2)).toEqual(airportSlots.slice(2))
    expect(buildTimeSlots([], 'longquan', { ...history, SchoolYear: '2026-2027', Term: '1' }))
      .toEqual(airportSlots)
    expect(buildTimeSlots([], 'longquan', { ...history, SchoolYear: '2026-2027', Term: '2' }))
      .toEqual(airportSlots)
    expect(buildTimeSlots([], 'longquan')).toEqual(airportSlots)
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

  it('applies a saved course color to every card of the same course', () => {
    const course = createCourse('same-course', [
      createActivity({ Weekday: 1, Weeks: [1] }),
      createActivity({ Weekday: 3, Weeks: [1] }),
    ])
    const automaticBlock = buildCourseBlocks([course], 1)[0]
    const customizedBlocks = buildCourseBlocks([course], 1, [], [], [
      {
        semesterID: 'semester-1',
        courseKey: automaticBlock.colorKey,
        tone: 'muted-coral',
      },
    ])

    expect(customizedBlocks).toHaveLength(2)
    expect(customizedBlocks.every((block) => block.tone === 'muted-coral')).toBe(true)
    expect(customizedBlocks.every((block) => block.colorKey === automaticBlock.colorKey)).toBe(true)
  })

  it('keeps the color key stable when only the course name changes', () => {
    const course = createCourse('原课程名', [createActivity({ Weeks: [1] })])
    const originalColorKey = buildCourseBlocks([course], 1)[0].colorKey
    course.Name = '修改后的课程名'

    expect(buildCourseBlocks([course], 1)[0].colorKey).toBe(originalColorKey)
  })

  it('assigns fifteen different stable colors before reusing the palette', () => {
    const courses = Array.from({ length: 15 }, (_, index) =>
      createCourse(`课程${String(index + 1).padStart(2, '0')}`, [createActivity({ Weeks: [1] })]),
    )
    const colorsByName = new Map(
      buildCourseBlocks(courses, 1)[0].courses.map((course) => [course.name, course.tone]),
    )
    const reversedColorsByName = new Map(
      buildCourseBlocks([...courses].reverse(), 1)[0].courses.map((course) => [
        course.name,
        course.tone,
      ]),
    )

    expect(new Set(colorsByName.values()).size).toBe(15)
    expect(reversedColorsByName).toEqual(colorsByName)
  })

  it('applies a persisted local edit to an original course', () => {
    const course = createCourse('原始课程', [
      createActivity({ Weekday: 1, StartSection: 1, EndSection: 2, Weeks: [1, 2, 3] }),
    ])
    const courseOverride: CourseOverride = {
      targetID: '原始课程-1-1-2',
      semesterID: 'semester-1',
      name: '修改后的课程',
      room: 'H2201',
      weekday: 4,
      startSection: 5,
      endSection: 6,
      weeks: [2, 4],
    }

    expect(buildCourseBlocks([course], 4, [], [courseOverride])[0]).toMatchObject({
      id: courseOverride.targetID,
      name: '修改后的课程',
      room: 'H2201',
      day: 4,
      start: 5,
      span: 2,
      weeks: [2, 4],
      muted: false,
      source: 'jwxt',
    })
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
      arrangements: [
        {
          room: 'H1208',
          teachers: ['张老师'],
          weeks: [1, 2, 3, 5],
        },
      ],
      source: 'jwxt',
    })
  })

  it('shows precise time on experiment cards only', () => {
    const experiment = createCourse('实验 编译原理', [
      createActivity({
        StartTime: '18:30',
        EndTime: '21:30',
        ActivityType: '实验',
      }),
    ])
    const theory = createCourse('编译原理', [
      createActivity({
        StartTime: '08:20',
        EndTime: '10:00',
        ActivityType: '理论',
      }),
    ])

    expect(buildCourseBlocks([experiment], 1)[0]).toMatchObject({
      experimentStartTime: '18:30',
      experimentEndTime: '21:30',
    })
    expect(buildCourseBlocks([theory], 1)[0].experimentStartTime).toBeUndefined()
    expect(buildCourseBlocks([theory], 1)[0].experimentEndTime).toBeUndefined()
  })

  it('combines room and week variants that share the same course time', () => {
    const course = createCourse('C语言程序设计', [
      createActivity({
        Weekday: 4,
        StartSection: 1,
        EndSection: 1,
        RoomName: 'H1502',
        Weeks: [5, 6, 7, 8],
      }),
      createActivity({
        Weekday: 4,
        StartSection: 1,
        EndSection: 1,
        RoomName: 'H1307',
        Weeks: [9, 10, 11, 12],
      }),
      createActivity({
        Weekday: 4,
        StartSection: 2,
        EndSection: 2,
        RoomName: 'H1502',
        Weeks: [5, 6, 7, 8],
      }),
      createActivity({
        Weekday: 4,
        StartSection: 2,
        EndSection: 2,
        RoomName: 'H1307',
        Weeks: [9, 10, 11, 12],
      }),
    ])

    const beforeCourseStarts = buildCourseBlocks([course], 1)
    const firstArrangement = buildCourseBlocks([course], 6)
    const secondArrangement = buildCourseBlocks([course], 10)

    expect(beforeCourseStarts).toHaveLength(1)
    expect(beforeCourseStarts[0]).toMatchObject({
      room: 'H1502',
      start: 1,
      span: 2,
      muted: true,
    })
    expect(firstArrangement).toHaveLength(1)
    expect(firstArrangement[0]).toMatchObject({ room: 'H1502', muted: false })
    expect(secondArrangement).toHaveLength(1)
    expect(secondArrangement[0]).toMatchObject({ room: 'H1307', muted: false })
    expect(secondArrangement[0].arrangements).toEqual([
      { room: 'H1502', teachers: [], weeks: [5, 6, 7, 8] },
      { room: 'H1307', teachers: [], weeks: [9, 10, 11, 12] },
    ])
  })

  it('keeps non-continuous time slots from the same course as separate cards', () => {
    const course = createCourse('大学英语', [
      createActivity({ Weekday: 2, StartSection: 1, EndSection: 2 }),
      createActivity({ Weekday: 2, StartSection: 5, EndSection: 6 }),
    ])

    expect(buildCourseBlocks([course], 1)).toHaveLength(2)
  })

  it('does not draw overlapping inactive schedule variants', () => {
    const course = createCourse('实验 数字电路与逻辑设计B', [
      createActivity({
        Weekday: 3,
        StartSection: 5,
        EndSection: 6,
        Weeks: [8, 9, 10, 11],
        ActivityType: '实验',
      }),
      createActivity({
        Weekday: 3,
        StartSection: 5,
        EndSection: 8,
        Weeks: [12, 13],
        ActivityType: '实验',
      }),
      createActivity({
        Weekday: 3,
        StartSection: 7,
        EndSection: 8,
        Weeks: [8, 9, 10, 11],
        ActivityType: '实验',
      }),
    ])

    const blocks = buildCourseBlocks([course], 1)

    expect(blocks.map(({ start, span }) => ({ start, span }))).toEqual([
      { start: 5, span: 2 },
      { start: 7, span: 2 },
    ])
  })

  it('preserves an every-week arrangement when duplicate activities are combined', () => {
    const course = createCourse('每周课程', [
      createActivity({ RoomName: 'H2101', Weeks: [] }),
      createActivity({ RoomName: 'H2101', Weeks: [5, 6] }),
    ])

    expect(buildCourseBlocks([course], 12)[0]).toMatchObject({
      room: 'H2101',
      weeks: [],
      muted: false,
      arrangements: [{ room: 'H2101', teachers: [], weeks: [] }],
    })
  })

  it('shows the course active in the selected week when courses share one time slot', () => {
    const english = createCourse('大学英语1', [
      createActivity({
        Weekday: 2,
        StartSection: 5,
        EndSection: 6,
        RoomName: 'H4502',
        Weeks: Array.from({ length: 12 }, (_, index) => index + 3),
      }),
    ])
    const politics = createCourse('形势与政策Ⅰ', [
      createActivity({
        Weekday: 2,
        StartSection: 5,
        EndSection: 6,
        RoomName: 'H1202',
        Weeks: [16, 17],
      }),
    ])

    const englishWeek = buildCourseBlocks([english, politics], 6)
    const politicsWeek = buildCourseBlocks([english, politics], 16)
    const inactiveWeek = buildCourseBlocks([english, politics], 1)

    expect(englishWeek).toHaveLength(1)
    expect(englishWeek[0]).toMatchObject({
      name: '大学英语1',
      room: 'H4502',
      conflict: false,
      muted: false,
    })
    expect(englishWeek[0].courses.map((course) => course.name)).toEqual([
      '大学英语1',
      '形势与政策Ⅰ',
    ])
    expect(politicsWeek).toHaveLength(1)
    expect(politicsWeek[0]).toMatchObject({
      name: '形势与政策Ⅰ',
      room: 'H1202',
      conflict: false,
      muted: false,
    })
    expect(inactiveWeek).toHaveLength(1)
    expect(inactiveWeek[0]).toMatchObject({
      name: '大学英语1',
      room: 'H4502',
      conflict: false,
      muted: true,
    })
  })

  it('marks a real same-week overlap as a course conflict', () => {
    const first = createCourse('课程A', [
      createActivity({ Weekday: 3, StartSection: 3, EndSection: 4, Weeks: [4, 5] }),
    ])
    const second = createCourse('课程B', [
      createActivity({ Weekday: 3, StartSection: 3, EndSection: 4, Weeks: [5, 6] }),
    ])

    const blocks = buildCourseBlocks([first, second], 5)

    expect(blocks).toHaveLength(1)
    expect(blocks[0]).toMatchObject({ name: '课程A', conflict: true, muted: false })
    expect(blocks[0].courses.map((course) => course.name)).toEqual(['课程A', '课程B'])
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
