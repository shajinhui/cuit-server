import { request } from '@/shared/api/client'

export interface CurrentWeek {
  CurrentWeek: number
}

export function getCurrentWeek() {
  return request<CurrentWeek>('/api/v1/schedule/current-week')
}
