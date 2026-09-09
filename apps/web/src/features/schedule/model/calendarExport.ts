import type { Semester } from '@/shared/models/academic'

import type { CourseTable } from '../api'
import {
  buildScheduleCourseEntries,
  buildTimeSlots,
  dateForSemesterWeek,
  scheduleCampusFromName,
} from './calendar'
import type { CourseOverride } from './courseOverride'
import type { ManualCourse } from './manualCourse'
import { calendarForSemester } from './semesterCalendar'

export interface CalendarExportOptions {
  semester: Semester
  table: CourseTable
  manualCourses?: ManualCourse[]
  courseOverrides?: CourseOverride[]
  campusName?: string
  reminderMinutes?: number
  generatedAt?: Date
}

export interface CalendarExportResult {
  content: string
  courseCount: number
  eventCount: number
  fileName: string
  calendarName: string
}

interface CalendarEvent {
  uid: string
  title: string
  location: string
  description: string
  startsAt: Date
  endsAt: Date
}

export function createScheduleCalendarExport({
  semester,
  table,
  manualCourses = [],
  courseOverrides = [],
  campusName,
  reminderMinutes = 10,
  generatedAt = new Date(),
}: CalendarExportOptions): CalendarExportResult {
  const calendar = calendarForSemester(semester)
  if (!calendar) throw new Error('该学期校历日期尚未收录，暂时无法导入系统日历')

  const semesterManualCourses = manualCourses.filter(
    (course) => course.semesterID === semester.ID,
  )
  const semesterOverrides = courseOverrides.filter(
    (courseOverride) => courseOverride.semesterID === semester.ID,
  )
  const entries = buildScheduleCourseEntries(
    table.Courses,
    0,
    semesterManualCourses,
    semesterOverrides,
  )
  if (entries.length === 0) throw new Error('当前学期没有可以导入的课程')

  const timeSlots = buildTimeSlots(
    entries,
    scheduleCampusFromName(campusName),
    semester,
  )
  const largestCourseWeek = entries.reduce(
    (largest, entry) =>
      Math.max(
        largest,
        ...entry.arrangements.flatMap((arrangement) => arrangement.weeks),
      ),
    0,
  )
  const weekCount = Math.max(table.WeekCount, calendar.weekCount, largestCourseWeek)
  const events: CalendarEvent[] = []

  for (const entry of entries) {
    const endSection = entry.start + entry.span - 1

    for (let week = 1; week <= weekCount; week += 1) {
      const activeArrangements = entry.arrangements.filter(
        (arrangement) => arrangement.weeks.length === 0 || arrangement.weeks.includes(week),
      )
      if (activeArrangements.length === 0) continue

      const startTime = activeArrangements[0]?.startTime || timeSlots[entry.start - 1]?.[0]
      const endTime = activeArrangements[0]?.endTime || timeSlots[endSection - 1]?.[1]
      if (!startTime || !endTime) {
        throw new Error(`“${entry.name}”使用了尚未配置时间的第 ${entry.start}–${endSection} 节`)
      }

      const date = dateForSemesterWeek(semester, week, entry.day)
      if (!date) continue
      const teachers = uniqueStrings(activeArrangements.flatMap((item) => item.teachers))
      const effectiveTeachers = teachers.length > 0 ? teachers : entry.teachers
      const location = uniqueStrings(activeArrangements.map((item) => item.room)).join(' / ')
      const startsAt = withTime(date, startTime)
      const endsAt = withTime(date, endTime)
      const description = [
        activeArrangements[0]?.activityType ? `课程类型：${activeArrangements[0].activityType}` : '',
        activeArrangements[0]?.projectName ? `授课项目：${activeArrangements[0].projectName}` : '',
        effectiveTeachers.length > 0 ? `教师：${effectiveTeachers.join('、')}` : '',
        entry.teachingClass ? `教学班：${entry.teachingClass}` : '',
        entry.code ? `课程代码：${entry.code}` : '',
        `第 ${week} 周 · 第 ${entry.start}–${endSection} 节`,
      ]
        .filter(Boolean)
        .join('\n')

      events.push({
        uid: `${stableHash(`${semester.ID}\u0000${entry.id}\u0000${formatDate(date)}\u0000${entry.start}\u0000${endSection}`)}@fanxiaogao05.dpdns.org`,
        title: entry.name,
        location: location === '地点待定' ? '' : location,
        description,
        startsAt,
        endsAt,
      })
    }
  }

  if (events.length === 0) throw new Error('当前学期没有可以导入的上课日期')

  const calendarName = `成信友友 · ${semester.SchoolYear} 第${semester.Term}学期`
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Chengxin Youyou//Schedule Calendar//ZH-CN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:${escapeIcsText(calendarName)}`,
    'X-WR-TIMEZONE:Asia/Shanghai',
    'BEGIN:VTIMEZONE',
    'TZID:Asia/Shanghai',
    'X-LIC-LOCATION:Asia/Shanghai',
    'BEGIN:STANDARD',
    'TZOFFSETFROM:+0800',
    'TZOFFSETTO:+0800',
    'TZNAME:CST',
    'DTSTART:19700101T000000',
    'END:STANDARD',
    'END:VTIMEZONE',
    ...events.flatMap((event) => serializeEvent(event, generatedAt, reminderMinutes)),
    'END:VCALENDAR',
  ]

  return {
    content: `${lines.map(foldIcsLine).join('\r\n')}\r\n`,
    courseCount: new Set(entries.map((entry) => entry.colorKey || entry.id)).size,
    eventCount: events.length,
    fileName: `成信友友课表-${semester.SchoolYear}-第${semester.Term}学期.ics`,
    calendarName,
  }
}

function serializeEvent(event: CalendarEvent, generatedAt: Date, reminderMinutes: number) {
  const lines = [
    'BEGIN:VEVENT',
    `UID:${event.uid}`,
    `DTSTAMP:${formatUtcDateTime(generatedAt)}`,
    `DTSTART;TZID=Asia/Shanghai:${formatLocalDateTime(event.startsAt)}`,
    `DTEND;TZID=Asia/Shanghai:${formatLocalDateTime(event.endsAt)}`,
    `SUMMARY:${escapeIcsText(event.title)}`,
    `DESCRIPTION:${escapeIcsText(event.description)}`,
  ]
  if (event.location) lines.push(`LOCATION:${escapeIcsText(event.location)}`)
  if (Number.isInteger(reminderMinutes) && reminderMinutes > 0) {
    lines.push(
      'BEGIN:VALARM',
      `TRIGGER:-PT${reminderMinutes}M`,
      'ACTION:DISPLAY',
      `DESCRIPTION:${escapeIcsText(`${event.title}即将开始`)}`,
      'END:VALARM',
    )
  }
  lines.push('END:VEVENT')
  return lines
}

function withTime(date: Date, time: string) {
  const [hours, minutes] = time.split(':').map(Number)
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours, minutes)
}

function formatDate(date: Date) {
  return `${date.getFullYear()}${twoDigits(date.getMonth() + 1)}${twoDigits(date.getDate())}`
}

function formatLocalDateTime(date: Date) {
  return `${formatDate(date)}T${twoDigits(date.getHours())}${twoDigits(date.getMinutes())}00`
}

function formatUtcDateTime(date: Date) {
  return `${date.getUTCFullYear()}${twoDigits(date.getUTCMonth() + 1)}${twoDigits(date.getUTCDate())}T${twoDigits(date.getUTCHours())}${twoDigits(date.getUTCMinutes())}${twoDigits(date.getUTCSeconds())}Z`
}

function twoDigits(value: number) {
  return String(value).padStart(2, '0')
}

function escapeIcsText(value: string) {
  return value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\r', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
}

function foldIcsLine(line: string) {
  const encoder = new TextEncoder()
  const output: string[] = []
  let current = ''
  let limit = 75

  for (const character of line) {
    if (encoder.encode(current + character).byteLength > limit) {
      output.push(current)
      current = ` ${character}`
      limit = 75
    } else {
      current += character
    }
  }
  output.push(current)
  return output.join('\r\n')
}

function stableHash(value: string) {
  let left = 0x811c9dc5
  let right = 0x9e3779b9
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    left = Math.imul(left ^ code, 0x01000193)
    right = Math.imul(right ^ code, 0x85ebca6b)
  }
  return `${(left >>> 0).toString(16).padStart(8, '0')}${(right >>> 0).toString(16).padStart(8, '0')}`
}

function uniqueStrings(values: string[]) {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))]
}
