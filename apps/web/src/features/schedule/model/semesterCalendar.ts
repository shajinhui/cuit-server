import publishedCalendars from '../../../../../../shared/academiccalendar/calendars.json'

import type { Semester } from '@/shared/models/academic'

// 只采用已核实的校历日期；春季受春节等安排影响，不能按固定月份猜开学日。
export function calendarForSemester(semester: Semester | undefined) {
  return publishedCalendars.find(
    (calendar) => calendar.schoolYear === semester?.SchoolYear && calendar.term === semester.Term,
  )
}

export function firstWeekMondayForSemester(semester: Semester | undefined): Date | null {
  const calendar = calendarForSemester(semester)
  if (!calendar) return null
  const [year, month, day] = calendar.firstWeekMonday.split('-').map(Number)
  // date-only 不通过 UTC 字符串解析，避免浏览器时区让日期偏移一天。
  return new Date(year, month - 1, day)
}

export function semesterWeekForDate(semester: Semester | undefined, date: Date): number | null {
  const monday = firstWeekMondayForSemester(semester)
  const calendar = calendarForSemester(semester)
  if (!monday || !calendar) return null
  const days = Math.round(
    (Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) -
      Date.UTC(monday.getFullYear(), monday.getMonth(), monday.getDate())) / 86_400_000,
  )
  const week = Math.floor(days / 7) + 1
  return week >= 1 && week <= calendar.weekCount ? week : 0
}

export function currentSchoolWeek(date: Date): number | null {
  return semesterWeekForDate(schoolSemesterForDate(date), date)
}

export function schoolSemesterForDate(date: Date): Semester {
  const year = date.getFullYear()
  const startYear = date.getMonth() >= 8 ? year : year - 1
  return {
    ID: '',
    SchoolYear: `${startYear}-${startYear + 1}`,
    Term: date.getMonth() === 0 || date.getMonth() >= 8 ? '1' : '2',
  }
}
