import { request } from './client'

export interface Semester {
  ID: string
  SchoolYear: string
  Term: string
}

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

export function listSemesters() {
  return request<Semester[]>('/api/v1/jwxt/semesters')
}

export function getGrades(semesterID: string) {
  const query = new URLSearchParams({ semester_id: semesterID })
  return request<Grade[]>(`/api/v1/jwxt/grades?${query}`)
}
