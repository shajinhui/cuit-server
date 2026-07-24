import type { Course } from '../api'
import type { ManualCourse } from './manualCourse'

export type CourseTone =
  | 'haze-blue'
  | 'sage'
  | 'terracotta'
  | 'mustard'
  | 'dusty-purple'
  | 'blue-gray'
  | 'rose-brown'
  | 'caramel'
export type TimeSlot = readonly [string, string]

export interface WeekDate {
  label: string
  date: number
  active: boolean
}

export interface CourseBlock {
  id: string
  name: string
  room: string
  day: number
  start: number
  span: number
  tone: CourseTone
  muted: boolean
}

const weekdays = ['一', '二', '三', '四', '五', '六', '日']
const courseTones = [
  'haze-blue',
  'sage',
  'terracotta',
  'mustard',
  'dusty-purple',
  'blue-gray',
  'rose-brown',
  'caramel',
] as const
const baseTimeSlots: TimeSlot[] = [
  ['08:20', '09:05'],
  ['09:00', '09:45'],
  ['10:10', '10:55'],
  ['11:10', '11:55'],
  ['14:00', '14:45'],
  ['14:30', '15:15'],
  ['15:40', '16:25'],
  ['16:40', '17:25'],
  ['18:30', '19:15'],
  ['19:30', '20:15'],
  ['20:30', '21:15'],
]

export function formatDateTitle(date: Date) {
  return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
}

export function buildWeekDates(selected: Date): WeekDate[] {
  const currentDay = selected.getDay() || 7
  const monday = new Date(selected)
  monday.setDate(selected.getDate() - currentDay + 1)

  return weekdays.map((label, index) => {
    const date = new Date(monday)
    date.setDate(monday.getDate() + index)
    return { label, date: date.getDate(), active: date.toDateString() === selected.toDateString() }
  })
}

export function dateForWeekday(selected: Date, weekdayIndex: number) {
  const currentDay = selected.getDay() || 7
  const date = new Date(selected)
  date.setDate(date.getDate() - currentDay + weekdayIndex + 1)
  return date
}

export function buildCourseBlocks(
  courses: Course[] | null | undefined,
  selectedWeek: number,
  manualCourses: ManualCourse[] = [],
): CourseBlock[] {
  const blocks: CourseBlock[] = []
  for (const course of courses ?? []) {
    for (const [activityIndex, activity] of (course.Activities ?? []).entries()) {
      if (
        activity.Weekday < 1 ||
        activity.Weekday > 7 ||
        activity.StartSection < 1 ||
        activity.EndSection < activity.StartSection
      ) {
        continue
      }

      const activityWeeks = activity.Weeks ?? []
      const muted = selectedWeek > 0 && activityWeeks.length > 0 && !activityWeeks.includes(selectedWeek)
      blocks.push({
        id: `${course.LessonID || course.Code}-${activityIndex}-${activity.Weekday}-${activity.StartSection}`,
        name: course.Name || '未命名课程',
        room: activity.RoomName || '地点待定',
        day: activity.Weekday,
        start: activity.StartSection,
        span: activity.EndSection - activity.StartSection + 1,
        tone: toneForCourse(course.Code || course.LessonID || course.Name),
        muted,
      })
    }
  }
  for (const course of manualCourses) {
    const muted = selectedWeek > 0 && !course.weeks.includes(selectedWeek)
    blocks.push({
      id: course.id,
      name: course.name,
      room: course.room || '地点待定',
      day: course.weekday,
      start: course.startSection,
      span: course.endSection - course.startSection + 1,
      tone: toneForCourse(course.id),
      muted,
    })
  }
  return blocks.sort((left, right) => Number(left.muted) - Number(right.muted))
}

export function buildTimeSlots(courses: CourseBlock[]): TimeSlot[] {
  const lastScheduledSection = courses.reduce(
    (maximum, course) => Math.max(maximum, course.start + course.span - 1),
    0,
  )
  const rowCount = Math.max(baseTimeSlots.length, lastScheduledSection)
  return Array.from({ length: rowCount }, (_, index) => baseTimeSlots[index] ?? ['', ''])
}

export function buildWeekOptions(weekCount: number, currentWeek: number, selectedWeek: number) {
  const count = Math.max(weekCount, currentWeek, selectedWeek, 1)
  return Array.from({ length: count }, (_, index) => index + 1)
}

function toneForCourse(identity: string): CourseTone {
  let hash = 0
  for (const character of identity) hash = (hash * 31 + character.charCodeAt(0)) >>> 0
  return courseTones[hash % courseTones.length]
}
