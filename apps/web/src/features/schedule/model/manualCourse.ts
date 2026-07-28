export type ManualCourseRepeat = 'weekly' | 'odd' | 'even'

export interface ManualCourseInput {
  name: string
  room: string
  weekday: number
  startSection: number
  endSection: number
  startWeek: number
  endWeek: number
  repeat: ManualCourseRepeat
  weeks?: number[]
}

export interface ManualCourse {
  id: string
  semesterID: string
  name: string
  room: string
  weekday: number
  startSection: number
  endSection: number
  weeks: number[]
}

export interface CourseEditTarget {
  id: string
  source: 'jwxt' | 'manual'
  name: string
  room: string
  weekday: number
  startSection: number
  endSection: number
  weeks: number[]
}

export function createManualCourse(input: ManualCourseInput, semesterID: string, id: string): ManualCourse {
  const name = input.name.trim()
  if (!name) throw new Error('请输入课程名称')
  if (!semesterID) throw new Error('请先选择学期')
  if (!Number.isInteger(input.weekday) || input.weekday < 1 || input.weekday > 7) {
    throw new Error('请选择正确的上课日期')
  }
  if (
    !Number.isInteger(input.startSection) ||
    !Number.isInteger(input.endSection) ||
    input.startSection < 1 ||
    input.endSection < input.startSection
  ) {
    throw new Error('请选择正确的上课节次')
  }
  if (
    !Number.isInteger(input.startWeek) ||
    !Number.isInteger(input.endWeek) ||
    input.startWeek < 1 ||
    input.endWeek < input.startWeek
  ) {
    throw new Error('请选择正确的上课周次')
  }

  const weeks =
    input.weeks === undefined
      ? buildManualCourseWeeks(input.startWeek, input.endWeek, input.repeat)
      : normalizeExplicitWeeks(input.weeks)
  if (weeks.length === 0) throw new Error('当前周次范围没有符合条件的教学周')

  return {
    id,
    semesterID,
    name,
    room: input.room.trim(),
    weekday: input.weekday,
    startSection: input.startSection,
    endSection: input.endSection,
    weeks,
  }
}

function normalizeExplicitWeeks(weeks: number[]) {
  if (weeks.some((week) => !Number.isInteger(week) || week < 1)) {
    throw new Error('请选择正确的上课周次')
  }
  return [...new Set(weeks)].sort((left, right) => left - right)
}

export function buildManualCourseWeeks(startWeek: number, endWeek: number, repeat: ManualCourseRepeat) {
  return Array.from({ length: endWeek - startWeek + 1 }, (_, index) => startWeek + index).filter((week) => {
    if (repeat === 'odd') return week % 2 === 1
    if (repeat === 'even') return week % 2 === 0
    return true
  })
}

export function isManualCourse(value: unknown): value is ManualCourse {
  if (!value || typeof value !== 'object') return false

  const course = value as Partial<ManualCourse>
  return (
    typeof course.id === 'string' &&
    typeof course.semesterID === 'string' &&
    typeof course.name === 'string' &&
    typeof course.room === 'string' &&
    Number.isInteger(course.weekday) &&
    Number(course.weekday) >= 1 &&
    Number(course.weekday) <= 7 &&
    Number.isInteger(course.startSection) &&
    Number(course.startSection) >= 1 &&
    Number.isInteger(course.endSection) &&
    Number(course.endSection) >= Number(course.startSection) &&
    Array.isArray(course.weeks) &&
    course.weeks.length > 0 &&
    course.weeks.every((week) => Number.isInteger(week) && week > 0)
  )
}
