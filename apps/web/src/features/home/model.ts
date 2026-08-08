import type { CourseBlock } from '@/features/schedule'

const sectionTimes = [
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
] as const

export type HomeCourseStatus = 'past' | 'ongoing' | 'upcoming'

export function greetingForHour(hour: number) {
  if (hour < 6) return '夜深了'
  if (hour < 11) return '早上好'
  if (hour < 14) return '中午好'
  if (hour < 18) return '下午好'
  return '晚上好'
}

export function formatHomeDate(date: Date) {
  const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
  return `${date.getMonth() + 1} 月 ${date.getDate()} 日 · ${weekdays[date.getDay()]}`
}

export function courseStartTimeLabel(course: Pick<CourseBlock, 'start'>) {
  return sectionTimes[course.start - 1]?.[0] ?? `第 ${course.start} 节`
}

export function courseTimeLabel(course: Pick<CourseBlock, 'start' | 'span'>) {
  const start = sectionTimes[course.start - 1]?.[0]
  const end = sectionTimes[course.start + course.span - 2]?.[1]
  return start && end ? `${start}–${end}` : `第 ${course.start}–${course.start + course.span - 1} 节`
}

export function courseCountdownLabel(
  course: Pick<CourseBlock, 'start' | 'span'>,
  date: Date,
) {
  const status = courseStatus(course, date)
  if (status === 'ongoing') return '进行中'
  if (status === 'past') return '已结束'

  const start = timeInMinutes(sectionTimes[course.start - 1]?.[0])
  if (start === null) return `第 ${course.start} 节`
  const now = date.getHours() * 60 + date.getMinutes()
  const minutes = Math.max(0, start - now)
  if (minutes < 60) return `还有 ${minutes} 分钟`

  const hours = Math.floor(minutes / 60)
  const remainder = minutes % 60
  return remainder ? `还有 ${hours} 小时 ${remainder} 分` : `还有 ${hours} 小时`
}

export function courseStatus(
  course: Pick<CourseBlock, 'start' | 'span'>,
  date: Date,
): HomeCourseStatus {
  const start = timeInMinutes(sectionTimes[course.start - 1]?.[0])
  const end = timeInMinutes(sectionTimes[course.start + course.span - 2]?.[1])
  if (start === null || end === null) return 'upcoming'

  const now = date.getHours() * 60 + date.getMinutes()
  if (now < start) return 'upcoming'
  if (now <= end) return 'ongoing'
  return 'past'
}

function timeInMinutes(value: string | undefined) {
  if (!value) return null
  const [hour, minute] = value.split(':').map(Number)
  return hour * 60 + minute
}
