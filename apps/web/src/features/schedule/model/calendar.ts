import type { Course } from '../api'
import type { CourseOverride } from './courseOverride'
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

export interface CourseSlotCourse {
  id: string
  name: string
  room: string
  code: string
  credits: string
  teachingClass: string
  teachers: string[]
  weeks: number[]
  arrangements: CourseArrangement[]
  source: 'jwxt' | 'manual'
  tone: CourseTone
  muted: boolean
}

export interface CourseBlock extends CourseSlotCourse {
  day: number
  start: number
  span: number
  courses: CourseSlotCourse[]
  conflict: boolean
}

export interface CourseArrangement {
  room: string
  teachers: string[]
  weeks: number[]
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
  courseOverrides: CourseOverride[] = [],
): CourseBlock[] {
  const blocks: CourseBlock[] = []
  const overridesByTarget = new Map(
    courseOverrides.map((courseOverride) => [courseOverride.targetID, courseOverride]),
  )
  for (const course of courses ?? []) {
    const identity = course.LessonID || course.Code || course.Name
    const groupedActivities = new Map<string, NonNullable<Course['Activities']>>()
    for (const activity of course.Activities ?? []) {
      if (
        activity.Weekday < 1 ||
        activity.Weekday > 7 ||
        activity.StartSection < 1 ||
        activity.EndSection < activity.StartSection
      ) {
        continue
      }

      const key = `${activity.Weekday}-${activity.StartSection}-${activity.EndSection}`
      const activities = groupedActivities.get(key) ?? []
      activities.push(activity)
      groupedActivities.set(key, activities)
    }

    const courseBlocks: CourseBlock[] = []
    for (const activities of groupedActivities.values()) {
      const firstActivity = activities[0]
      const arrangements = buildArrangements(activities)
      const activeArrangements = arrangements.filter((arrangement) =>
        isArrangementActive(arrangement, selectedWeek),
      )
      const visibleArrangements =
        activeArrangements.length > 0
          ? activeArrangements
          : [nearestArrangement(arrangements, selectedWeek)]
      const activityWeeks = uniqueNumbers(arrangements.flatMap((arrangement) => arrangement.weeks))
      const muted = selectedWeek > 0 && activeArrangements.length === 0
      courseBlocks.push({
        id: `${identity}-${firstActivity.Weekday}-${firstActivity.StartSection}-${firstActivity.EndSection}`,
        name: course.Name || '未命名课程',
        room: uniqueStrings(visibleArrangements.map((arrangement) => arrangement.room)).join(' / '),
        code: course.Code,
        credits: course.Credits,
        teachingClass: course.TeachingClass,
        teachers: uniqueStrings([
          ...(course.Teachers ?? []),
          ...arrangements.flatMap((arrangement) => arrangement.teachers),
        ]),
        weeks: [...activityWeeks],
        arrangements,
        source: 'jwxt',
        day: firstActivity.Weekday,
        start: firstActivity.StartSection,
        span: firstActivity.EndSection - firstActivity.StartSection + 1,
        tone: toneForCourse(course.Code || identity),
        muted,
        courses: [],
        conflict: false,
      })
    }
    blocks.push(
      ...mergeContinuousCourseBlocks(courseBlocks, identity).map((block) =>
        applyCourseOverride(block, overridesByTarget.get(block.id), selectedWeek),
      ),
    )
  }
  for (const course of manualCourses) {
    const muted = selectedWeek > 0 && !course.weeks.includes(selectedWeek)
    blocks.push({
      id: course.id,
      name: course.name,
      room: course.room || '地点待定',
      code: '',
      credits: '',
      teachingClass: '',
      teachers: [],
      weeks: [...course.weeks],
      arrangements: [
        {
          room: course.room || '地点待定',
          teachers: [],
          weeks: [...course.weeks],
        },
      ],
      source: 'manual',
      day: course.weekday,
      start: course.startSection,
      span: course.endSection - course.startSection + 1,
      tone: toneForCourse(course.id),
      muted,
      courses: [],
      conflict: false,
    })
  }
  return groupCourseSlots(blocks, selectedWeek).sort(
    (left, right) => Number(left.muted) - Number(right.muted),
  )
}

function applyCourseOverride(
  block: CourseBlock,
  courseOverride: CourseOverride | undefined,
  selectedWeek: number,
): CourseBlock {
  if (!courseOverride) return block

  const room = courseOverride.room || '地点待定'
  const muted = selectedWeek > 0 && !courseOverride.weeks.includes(selectedWeek)
  return {
    ...block,
    name: courseOverride.name,
    room,
    day: courseOverride.weekday,
    start: courseOverride.startSection,
    span: courseOverride.endSection - courseOverride.startSection + 1,
    weeks: [...courseOverride.weeks],
    arrangements: [
      {
        room,
        teachers: [...block.teachers],
        weeks: [...courseOverride.weeks],
      },
    ],
    muted,
  }
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

function uniqueStrings(values: string[]) {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))]
}

function uniqueNumbers(values: number[]) {
  return [...new Set(values)].sort((left, right) => left - right)
}

function buildArrangements(activities: NonNullable<Course['Activities']>): CourseArrangement[] {
  const arrangements = new Map<string, CourseArrangement>()

  for (const activity of activities) {
    const room = activity.RoomName || '地点待定'
    const teachers = uniqueStrings(activity.Teachers ?? [])
    const key = `${room}\u0000${teachers.join('\u0000')}`
    const existing = arrangements.get(key)
    if (existing) {
      existing.weeks = mergeWeeks(existing.weeks, activity.Weeks ?? [])
      continue
    }
    arrangements.set(key, {
      room,
      teachers,
      weeks: uniqueNumbers(activity.Weeks ?? []),
    })
  }

  return [...arrangements.values()].sort((left, right) => {
    const weekDifference = (left.weeks[0] ?? 0) - (right.weeks[0] ?? 0)
    if (weekDifference !== 0) return weekDifference
    const roomDifference = left.room.localeCompare(right.room)
    if (roomDifference !== 0) return roomDifference
    return left.teachers.join('\u0000').localeCompare(right.teachers.join('\u0000'))
  })
}

function mergeWeeks(left: number[], right: number[]) {
  if (left.length === 0 || right.length === 0) return []
  return uniqueNumbers([...left, ...right])
}

function isArrangementActive(arrangement: CourseArrangement, selectedWeek: number) {
  return selectedWeek <= 0 || arrangement.weeks.length === 0 || arrangement.weeks.includes(selectedWeek)
}

function nearestArrangement(arrangements: CourseArrangement[], selectedWeek: number) {
  return arrangements.reduce((nearest, arrangement) => {
    const nearestDistance = distanceToWeeks(nearest.weeks, selectedWeek)
    const arrangementDistance = distanceToWeeks(arrangement.weeks, selectedWeek)
    return arrangementDistance < nearestDistance ? arrangement : nearest
  })
}

function distanceToWeeks(weeks: number[], selectedWeek: number) {
  if (selectedWeek <= 0 || weeks.length === 0) return 0
  return Math.min(...weeks.map((week) => Math.abs(week - selectedWeek)))
}

function mergeContinuousCourseBlocks(courseBlocks: CourseBlock[], identity: string) {
  const merged: CourseBlock[] = []
  const sortedBlocks = [...courseBlocks].sort(
    (left, right) => left.day - right.day || left.start - right.start,
  )

  for (const block of sortedBlocks) {
    const previous = merged[merged.length - 1]
    if (!previous || !canMergeCourseBlocks(previous, block)) {
      merged.push(block)
      continue
    }

    const previousEnd = previous.start + previous.span - 1
    const blockEnd = block.start + block.span - 1
    previous.span = Math.max(previousEnd, blockEnd) - previous.start + 1
    previous.id = `${identity}-${previous.day}-${previous.start}-${previous.start + previous.span - 1}`
  }

  return merged
}

function canMergeCourseBlocks(left: CourseBlock, right: CourseBlock) {
  const leftEnd = left.start + left.span - 1
  return (
    left.day === right.day &&
    right.start <= leftEnd + 1 &&
    arrangementSignature(left.arrangements) === arrangementSignature(right.arrangements)
  )
}

function arrangementSignature(arrangements: CourseArrangement[]) {
  return arrangements
    .map(
      (arrangement) =>
        `${arrangement.room}\u0000${arrangement.teachers.join('\u0000')}\u0000${arrangement.weeks.join(',')}`,
    )
    .join('\u0001')
}

function groupCourseSlots(blocks: CourseBlock[], selectedWeek: number) {
  const slots = new Map<string, CourseBlock[]>()
  for (const block of blocks) {
    const key = `${block.day}-${block.start}-${block.span}`
    const courses = slots.get(key) ?? []
    courses.push(block)
    slots.set(key, courses)
  }

  return [...slots.values()].map((slotBlocks) => {
    if (slotBlocks.length === 1) {
      const onlyBlock = slotBlocks[0]
      return {
        ...onlyBlock,
        courses: [toSlotCourse(onlyBlock)],
        conflict: false,
      }
    }

    const activeBlocks = slotBlocks.filter((block) => !block.muted)
    const primary =
      activeBlocks[0] ??
      slotBlocks.reduce((nearest, block) =>
        distanceToWeeks(block.weeks, selectedWeek) < distanceToWeeks(nearest.weeks, selectedWeek)
          ? block
          : nearest,
      )
    const courses = slotBlocks.map(toSlotCourse).sort((left, right) => {
      const mutedDifference = Number(left.muted) - Number(right.muted)
      if (mutedDifference !== 0) return mutedDifference
      return (left.weeks[0] ?? 0) - (right.weeks[0] ?? 0) || left.name.localeCompare(right.name)
    })

    return {
      ...primary,
      id: `slot-${primary.day}-${primary.start}-${primary.span}-${courses
        .map((course) => course.id)
        .sort()
        .join('|')}`,
      courses,
      conflict: selectedWeek > 0 && activeBlocks.length > 1,
    }
  })
}

function toSlotCourse(block: CourseBlock): CourseSlotCourse {
  return {
    id: block.id,
    name: block.name,
    room: block.room,
    code: block.code,
    credits: block.credits,
    teachingClass: block.teachingClass,
    teachers: [...block.teachers],
    weeks: [...block.weeks],
    arrangements: block.arrangements.map((arrangement) => ({
      room: arrangement.room,
      teachers: [...arrangement.teachers],
      weeks: [...arrangement.weeks],
    })),
    source: block.source,
    tone: block.tone,
    muted: block.muted,
  }
}
