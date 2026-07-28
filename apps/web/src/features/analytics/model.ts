export interface StatsSummary {
  total_users: number
  new_users_today: number
  new_users_period: number
  dau_today: number
  wau: number
  mau: number
  requests_period: number
  errors_period: number
  average_latency_ms: number
}

export interface DailyStats {
  date: string
  new_users: number
  active_users: number
  request_count: number
  error_count: number
  average_latency_ms: number
}

export interface RouteStats {
  method: string
  route: string
  request_count: number
  error_count: number
  average_latency_ms: number
  max_latency_ms: number
}

export interface CacheStats {
  enabled: boolean
  reachable: boolean
  started_at: string
  requests: number
  hits: number
  source_loads: number
  coalesced_requests: number
  read_errors: number
  write_errors: number
  keys: number
  memory_bytes: number
  evicted_keys: number
  expired_keys: number
}

export interface FeedbackItem {
  id: number
  type: 'suggestion' | 'bug'
  platform: 'android' | 'ios'
  content: string
  created_at: string
}

export interface ServiceStats {
  period_days: number
  generated_at: string
  summary: StatsSummary
  cache: CacheStats
  daily: DailyStats[]
  top_routes: RouteStats[]
  feedback: FeedbackItem[]
}

export interface ChartSeries {
  label: string
  color: string
  values: number[]
}

export function percentage(part: number, total: number): number {
  if (total <= 0) return 0
  return (part / total) * 100
}

export function chartPoints(
  values: number[],
  maximum: number,
  width: number,
  height: number,
  horizontalPadding = 12,
  verticalPadding = 12,
): string {
  if (values.length === 0) return ''

  const plotWidth = width - horizontalPadding * 2
  const plotHeight = height - verticalPadding * 2
  const safeMaximum = Math.max(maximum, 1)
  return values
    .map((value, index) => {
      const progress = values.length === 1 ? 0.5 : index / (values.length - 1)
      const x = horizontalPadding + plotWidth * progress
      const y = verticalPadding + plotHeight * (1 - value / safeMaximum)
      return `${x.toFixed(1)},${y.toFixed(1)}`
    })
    .join(' ')
}

export function compactDate(value: string): string {
  const parts = value.split('-')
  return parts.length === 3 ? `${Number(parts[1])}/${Number(parts[2])}` : value
}
