import { request } from '@/shared/api/client'

export interface StudentProfile {
  StudentNo: string
  Name: string
  EnglishName: string
  Gender: string
  Grade: string
  StudyDuration: string
  Project: string
  EducationLevel: string
  StudentCategory: string
  College: string
  Major: string
  Direction: string
  EnrollmentDate: string
  ExpectedGraduationDate: string
  AdministrativeCollege: string
  StudyMode: string
  Campus: string
  ClassName: string
  TrainingLevel: string
  Counselor: string
  StatusEffectiveDate: string
  StudentStatus: string
  Remark: string
}

export function getStudentProfile() {
  return request<StudentProfile>('/api/v1/jwxt/profile')
}
