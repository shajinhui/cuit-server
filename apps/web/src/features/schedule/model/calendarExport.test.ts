import { describe, expect, it } from 'vitest'

import type { Course, CourseTable } from '../api'
import { createScheduleCalendarExport } from './calendarExport'

const semester = { ID: 'semester-1', SchoolYear: '2026-2027', Term: '1' }

describe('schedule calendar export', () => {
  it('exports exact dates, course times, locations and reminders', () => {
    const course = createCourse({
      Name: '高等数学, A;班',
      Teachers: ['张老师'],
      Activities: [
        {
          TeacherIDs: null,
          Teachers: ['张老师'],
          RoomID: 'room-1',
          RoomName: 'H1101',
          Weekday: 1,
          StartSection: 1,
          EndSection: 2,
          Weeks: [1, 3],
        },
      ],
    })

    const result = createScheduleCalendarExport({
      semester,
      table: createTable([course]),
      reminderMinutes: 10,
      generatedAt: new Date('2026-09-01T00:00:00.000Z'),
    })

    expect(result.courseCount).toBe(1)
    expect(result.eventCount).toBe(2)
    expect(result.content).toContain('DTSTART;TZID=Asia/Shanghai:20260907T082000')
    expect(result.content).toContain('DTEND;TZID=Asia/Shanghai:20260907T100000')
    expect(result.content).toContain('DTSTART;TZID=Asia/Shanghai:20260921T082000')
    expect(result.content).toContain('SUMMARY:高等数学\\, A\\;班')
    expect(result.content).toContain('LOCATION:H1101')
    expect(result.content).toContain('TRIGGER:-PT10M')
    expect(result.content).toContain('DTSTAMP:20260901T000000Z')
  })

  it('uses the room assigned to each teaching week', () => {
    const course = createCourse({
      Activities: [
        createActivity('H1502', [1]),
        createActivity('H1307', [2]),
      ],
    })

    const result = createScheduleCalendarExport({
      semester,
      table: createTable([course]),
      reminderMinutes: 0,
    })

    expect(result.eventCount).toBe(2)
    expect(result.content.match(/LOCATION:H1502/g)).toHaveLength(1)
    expect(result.content.match(/LOCATION:H1307/g)).toHaveLength(1)
    expect(result.content).not.toContain('BEGIN:VALARM')
  })

  it('prefers precise LABMS times over the fixed section clock', () => {
    const result = createScheduleCalendarExport({
      semester,
      table: createTable([
        createCourse({
          Activities: [
            {
              ...createActivity('实验楼 A201', [6]),
              Weekday: 3,
              StartSection: 10,
              EndSection: 12,
              StartTime: '18:30',
              EndTime: '21:30',
              ActivityType: '实验',
              ProjectName: '信号采集实验',
            },
          ],
        }),
      ]),
    })

    expect(result.content).toContain('DTSTART;TZID=Asia/Shanghai:20261014T183000')
    expect(result.content).toContain('DTEND;TZID=Asia/Shanghai:20261014T213000')
    expect(result.content).toContain('课程类型：实验')
    expect(result.content).toContain('授课项目：信号采集实验')
  })

  it('includes manual courses and applies saved course overrides', () => {
    const course = createCourse()
    const result = createScheduleCalendarExport({
      semester,
      table: createTable([course]),
      manualCourses: [
        {
          id: 'manual-1',
          semesterID: semester.ID,
          name: '自习',
          room: '图书馆',
          weekday: 2,
          startSection: 3,
          endSection: 4,
          weeks: [1],
        },
      ],
      courseOverrides: [
        {
          targetID: 'lesson-1-1-1-2',
          semesterID: semester.ID,
          name: '修改后的课程',
          room: 'H2201',
          weekday: 4,
          startSection: 5,
          endSection: 6,
          weeks: [2],
        },
      ],
    })

    expect(result.courseCount).toBe(2)
    expect(result.eventCount).toBe(2)
    expect(result.content).toContain('SUMMARY:修改后的课程')
    expect(result.content).toContain('DTSTART;TZID=Asia/Shanghai:20260917T140000')
    expect(result.content).toContain('SUMMARY:自习')
  })

  it('treats an empty week list as every week in the semester', () => {
    const result = createScheduleCalendarExport({
      semester,
      table: createTable([createCourse({ Activities: [createActivity('H1101', [])] })]),
    })

    expect(result.eventCount).toBe(19)
  })

  it('keeps every physical ICS line within 75 UTF-8 bytes', () => {
    const result = createScheduleCalendarExport({
      semester,
      table: createTable([
        createCourse({ Name: '这是一个用于检查中文日历折行是否按字节计算的特别长课程名称' }),
      ]),
    })
    const encoder = new TextEncoder()

    expect(
      result.content
        .split('\r\n')
        .filter(Boolean)
        .every((line) => encoder.encode(line).byteLength <= 75),
    ).toBe(true)
  })

  it('keeps event identifiers stable when the file is generated again', () => {
    const options = {
      semester,
      table: createTable([createCourse()]),
    }
    const first = createScheduleCalendarExport({
      ...options,
      generatedAt: new Date('2026-09-01T00:00:00.000Z'),
    })
    const second = createScheduleCalendarExport({
      ...options,
      generatedAt: new Date('2026-09-02T00:00:00.000Z'),
    })
    const uid = (content: string) => content.match(/^UID:(.+)$/m)?.[1]?.trim()

    expect(uid(first.content)).toBeTruthy()
    expect(uid(first.content)).toBe(uid(second.content))
  })

  it('rejects semesters without verified calendar dates', () => {
    expect(() =>
      createScheduleCalendarExport({
        semester: { ...semester, SchoolYear: '2030-2031' },
        table: createTable([createCourse()]),
      }),
    ).toThrow('该学期校历日期尚未收录')
  })
})

function createTable(courses: Course[]): CourseTable {
  return {
    SemesterID: semester.ID,
    WeekCount: 19,
    SectionsPerDay: 12,
    Courses: courses,
  }
}

function createCourse(overrides: Partial<Course> = {}): Course {
  return {
    LessonID: 'lesson-1',
    Code: 'MATH101',
    Name: '高等数学',
    Credits: '4',
    Sequence: '1',
    TeachingClass: '教学班 1',
    Teachers: ['李老师'],
    Activities: [createActivity('H1101', [1])],
    ...overrides,
  }
}

function createActivity(room: string, weeks: number[]) {
  return {
    TeacherIDs: null,
    Teachers: null,
    RoomID: room,
    RoomName: room,
    Weekday: 1,
    StartSection: 1,
    EndSection: 2,
    Weeks: weeks,
  }
}
