import { request } from '@/shared/api/client'

export type ExamType = 'final' | 'makeup'

export interface ExamBatch {
  ID: ExamType
  Name: string
}

export interface Exam {
  CourseSequence: string
  CourseName: string
  ExamType: string
  ExamDate: string
  ExamTime: string
  Location: string
  ExamRoomID: string
  Credits: string
  Status: string
  Remark: string
}

export function listExams(semesterID: string, examType: ExamType) {
  const parameters = new URLSearchParams({
    semester_id: semesterID,
    exam_type: examType,
  })
  return request<Exam[]>(`/api/v1/jwxt/exams?${parameters}`)
}
