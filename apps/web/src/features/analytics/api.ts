import { request } from '@/shared/api/client'

import type { ServiceStats } from './model'

export function fetchServiceStats(token: string, days: number): Promise<ServiceStats> {
  return request<ServiceStats>(`/api/v1/admin/stats?days=${days}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })
}
