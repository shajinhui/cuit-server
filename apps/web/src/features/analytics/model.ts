export interface StatsSummary {
  total_users: number
  new_users_today: number
  new_users_period: number
  dau_today: number
  wau: number
  mau: number
  requests_period: number
  errors_period: number
  client_errors_period: number
  server_errors_period: number
  average_latency_ms: number
  max_latency_ms: number
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
  client_error_count: number
  server_error_count: number
  average_latency_ms: number
  max_latency_ms: number
}

export interface RequestStats {
  time: string
  request_count: number
  client_error_count: number
  server_error_count: number
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
  period: StatsPeriod
  granularity: StatsGranularity
  generated_at: string
  summary: StatsSummary
  cache: CacheStats
  daily: DailyStats[]
  timeline: RequestStats[]
  top_routes: RouteStats[]
  devices: DeviceStats
  feedback: FeedbackItem[]
}

export type StatsPeriod = '1h' | '6h' | '24h' | '7d' | '30d' | '90d'
export type StatsGranularity = '5_minutes' | '30_minutes' | 'hour' | '6_hours' | 'day'

export interface ChartSeries {
  label: string
  color: string
  values: number[]
}

export interface ChartPoint {
  x: number
  y: number
  value: number
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
  return chartCoordinates(
    values,
    maximum,
    width,
    height,
    horizontalPadding,
    verticalPadding,
  )
    .map((point) => `${point.x.toFixed(1)},${point.y.toFixed(1)}`)
    .join(' ')
}

export function chartCoordinates(
  values: number[],
  maximum: number,
  width: number,
  height: number,
  horizontalPadding = 12,
  verticalPadding = 12,
): ChartPoint[] {
  if (values.length === 0) return []

  const plotWidth = width - horizontalPadding * 2
  const plotHeight = height - verticalPadding * 2
  const safeMaximum = Math.max(maximum, 1)
  return values.map((value, index) => {
    const progress = values.length === 1 ? 0.5 : index / (values.length - 1)
    return {
      x: horizontalPadding + plotWidth * progress,
      y: verticalPadding + plotHeight * (1 - value / safeMaximum),
      value,
    }
  })
}

export function compactDate(value: string): string {
  const parts = value.split('-')
  return parts.length === 3 ? `${Number(parts[1])}/${Number(parts[2])}` : value
}

export function timelineLabel(value: string, granularity: StatsGranularity): string {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  const parts = new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date)
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((item) => item.type === type)?.value ?? ''
  const month = Number(part('month'))
  const day = Number(part('day'))
  if (granularity === 'day') return `${month}/${day}`
  const hour = part('hour').padStart(2, '0')
  const minute = part('minute').padStart(2, '0')
  if (granularity === '5_minutes' || granularity === '30_minutes') return `${hour}:${minute}`
  return granularity === 'hour' ? `${hour}:00` : `${month}/${day} ${hour}:00`
}
