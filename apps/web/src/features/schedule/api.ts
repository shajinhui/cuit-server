import { request } from '@/shared/api/client'
export { getCurrentWeek } from '@/shared/api/currentWeek'
export type { CurrentWeek } from '@/shared/api/currentWeek'

export interface CourseActivity {
  TeacherIDs: string[] | null
  Teachers: string[] | null
  RoomID: string
  RoomName: string
  Weekday: number
  StartSection: number
  EndSection: number
  Weeks: number[] | null
  StartTime?: string
  EndTime?: string
  ActivityType?: string
  ProjectName?: string
}

export interface Course {
  LessonID: string
  Code: string
  Name: string
  Credits: string
  Sequence: string
  TeachingClass: string
  Teachers: string[] | null
  Activities: CourseActivity[] | null
}

export interface CourseTable {
  SemesterID: string
  WeekCount: number
  SectionsPerDay: number
  Courses: Course[] | null
}

export function getCourseTable(semesterID: string, refresh = false) {
  const query = new URLSearchParams({ semester_id: semesterID })
  if (refresh) query.set('refresh', '1')
  return request<CourseTable>(`/api/v1/jwxt/course-table?${query}`)
}
