import { request } from '@/shared/api/client'
import type { Semester } from '@/shared/models/academic'

export function listSemesters() {
  return request<Semester[]>('/api/v1/jwxt/semesters')
}
