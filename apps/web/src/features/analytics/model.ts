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

export interface DeviceGroup {
  name: string
  count: number
}

export interface DeviceStats {
  tracked_users: number
  untracked_users: number
  platforms: DeviceGroup[]
  brands: DeviceGroup[]
}

export interface ServiceStats {
  period_days: number
  generated_at: string
  summary: StatsSummary
  cache: CacheStats
  daily: DailyStats[]
  top_routes: RouteStats[]
  devices: DeviceStats
  feedback: FeedbackItem[]
}

export interface ChartSeries {
  label: string
  color: string
  values: number[]
}

export interface DeviceDistributionItem {
  platform: 'android' | 'ios'
  label: string
  count: number
  share: number
}

export function platformDeviceDistribution(devices?: DeviceStats): DeviceDistributionItem[] {
  const total = devices?.tracked_users ?? 0
  const count = (platform: DeviceDistributionItem['platform']) =>
    devices?.platforms.find((item) => item.name === platform)?.count ?? 0
  const ios = count('ios')
  const android = count('android')

  return [
    { platform: 'ios', label: 'iOS', count: ios, share: percentage(ios, total) },
    {
      platform: 'android',
      label: 'Android',
      count: android,
      share: percentage(android, total),
    },
  ]
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
