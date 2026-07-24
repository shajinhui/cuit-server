import { request } from '@/shared/api/client'

export interface Grade {
  SchoolYearTerm: string
  CourseCode: string
  CourseSequence: string
  CourseName: string
  CourseCategory: string
  Credits: string
  UsualScore: string
  FinalExamScore: string
  OverallScore: string
  FinalScore: string
  GradePoint: string
}

export function getGrades(semesterID: string) {
  const parameters = new URLSearchParams({ semester_id: semesterID })
  return request<Grade[]>(`/api/v1/jwxt/grades?${parameters}`)
}
