import { request } from '@/shared/api/client'

import type { ServiceStats, StatsPeriod } from './model'

export function fetchServiceStats(token: string, period: StatsPeriod): Promise<ServiceStats> {
  return request<ServiceStats>(`/api/v1/admin/stats?range=${period}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })
}
