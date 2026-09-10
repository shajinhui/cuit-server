import type { AutoRunClubActivity, AutoRunClubSignTask } from './api'

export const AUTORUN_BUSINESS_TIME_ZONE = 'Asia/Shanghai'

export interface AutoRunDueClubProbe {
  activityId: number
  signType: '1' | '2'
  key: string
}

export interface AutoRunClubScheduleEventDraft {
  studentId: number
  actionKey: string
  activityId: number
  signType: '1' | '2'
  eventAt: number
  windowStart: number
  windowEnd: number
}

export interface AutoRunClubScheduleMarkers {
  lastSignInKey?: string
  lastSignBackKey?: string
}

export class InvalidAutoRunBusinessDateError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'InvalidAutoRunBusinessDateError'
  }
}

export function businessDate(value: Date): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: AUTORUN_BUSINESS_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value)
  const year = parts.find((part) => part.type === 'year')?.value ?? '0000'
  const month = parts.find((part) => part.type === 'month')?.value ?? '00'
  const day = parts.find((part) => part.type === 'day')?.value ?? '00'
  return `${year}-${month}-${day}`
}

export function normalizeBusinessDate(input: string | undefined, now: Date): string {
  const value = input?.trim() ?? ''
  if (value === '') return businessDate(now)
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new InvalidAutoRunBusinessDateError('queryDate 必须是 YYYY-MM-DD')
  }
  const parsed = parseLocalDateTime(value, '00:00')
  if (parsed === null || businessDate(parsed) !== value) {
    throw new InvalidAutoRunBusinessDateError('queryDate 日期无效')
  }
  return value
}

/** Parse activity times as Asia/Shanghai when the upstream omits a timezone. */
export function parseClubEventTime(queryDate: string, raw: string | undefined): Date | null {
  const value = raw?.trim() ?? ''
  if (value === '' || value === '--:--') return null

  if (
    /^\d{4}-\d{2}-\d{2}T/.test(value) ||
    /Z$/.test(value) ||
    /[+-]\d{2}:?\d{2}$/.test(value)
  ) {
    const parsed = new Date(value)
    return Number.isNaN(parsed.getTime()) ? null : parsed
  }

  const full = value.match(/^(\d{4})[-/](\d{2})[-/](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/)
  if (full !== null) {
    return parseLocalDateTime(
      `${full[1]}-${full[2]}-${full[3]}`,
      `${full[4]}:${full[5]}:${full[6] ?? '00'}`,
    )
  }

  if (/^\d{2}:\d{2}(?::\d{2})?$/.test(value)) {
    return parseLocalDateTime(queryDate, value.length === 5 ? `${value}:00` : value)
  }
  return null
}

/** ±10 minutes around an activity boundary, matching the scheduler. */
export function inClubProbeWindow(now: Date, eventAt: Date): boolean {
  return Math.abs(now.getTime() - eventAt.getTime()) <= 10 * 60 * 1000
}

export function clubProbeKey(queryDate: string, activityId: number, signType: '1' | '2'): string {
  return `${queryDate}:${activityId}:${signType}`
}

export function dueClubProbes(
  now: Date,
  queryDate: string,
  activities: readonly AutoRunClubActivity[],
  schedule: AutoRunClubScheduleMarkers,
): AutoRunDueClubProbe[] {
  const probes: AutoRunDueClubProbe[] = []
  for (const activity of activities) {
    const activityId = safeActivityId(activity.clubActivityId)
    if (activityId === null) continue

    const signInKey = clubProbeKey(queryDate, activityId, '1')
    const startAt = parseClubEventTime(queryDate, activity.startTime)
    if (schedule.lastSignInKey !== signInKey && startAt !== null && inClubProbeWindow(now, startAt)) {
      probes.push({ activityId, signType: '1', key: signInKey })
    }

    const signBackKey = clubProbeKey(queryDate, activityId, '2')
    const endAt = parseClubEventTime(queryDate, activity.endTime)
    if (
      schedule.lastSignBackKey !== signBackKey &&
      endAt !== null &&
      inClubProbeWindow(now, endAt)
    ) {
      probes.push({ activityId, signType: '2', key: signBackKey })
    }
  }
  return probes
}

/** Build events only for activities the student has actually joined. */
export function buildClubScheduleEvents(
  queryDate: string,
  studentId: number,
  activities: readonly AutoRunClubActivity[],
): AutoRunClubScheduleEventDraft[] {
  const events: AutoRunClubScheduleEventDraft[] = []
  for (const activity of activities) {
    if (readString(activity.optionStatus) !== '1') continue
    const activityId = safeActivityId(activity.clubActivityId)
    if (activityId === null) continue
    addScheduleEvent(events, queryDate, studentId, activityId, '1', activity.startTime)
    addScheduleEvent(events, queryDate, studentId, activityId, '2', activity.endTime)
  }
  return events
}

export function resolveClubSignType(task: AutoRunClubSignTask | null): '1' | '2' | '' {
  if (task === null) return ''
  if (readString(task.signStatus) === '1') return '1'
  if (readString(task.signInStatus) === '1' && readString(task.signStatus) === '2') return '2'
  return ''
}

export function isEmptySignInTask(task: AutoRunClubSignTask | null): boolean {
  if (task === null) return true
  const isZeroStatus = (value: unknown) => {
    const normalized = readString(value)
    return normalized === '' || normalized === '0'
  }
  return (
    (firstNumber(task, ['activityId', 'clubActivityId']) ?? 0) === 0 &&
    readString(task.activityName) === '' &&
    readString(task.startTime) === '' &&
    readString(task.endTime) === '' &&
    readString(task.latitude) === '' &&
    readString(task.longitude) === '' &&
    isZeroStatus(task.signStatus) &&
    isZeroStatus(task.signInStatus) &&
    isZeroStatus(task.signBackStatus)
  )
}

export function clubSignTypeName(signType: '1' | '2'): string {
  return signType === '2' ? '签退' : '签到'
}

function parseLocalDateTime(date: string, time: string): Date | null {
  const dateMatch = date.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  const timeMatch = time.match(/^(\d{2}):(\d{2})(?::(\d{2}))?$/)
  if (dateMatch === null || timeMatch === null) return null

  const year = Number(dateMatch[1])
  const month = Number(dateMatch[2])
  const day = Number(dateMatch[3])
  const hour = Number(timeMatch[1])
  const minute = Number(timeMatch[2])
  const second = Number(timeMatch[3] ?? '0')
  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    return null
  }

  // Asia/Shanghai has used a fixed UTC+08:00 offset for the supported dates.
  const parsed = new Date(Date.UTC(year, month - 1, day, hour, minute, second) - 8 * 60 * 60 * 1000)
  const check = new Date(Date.UTC(year, month - 1, day, hour, minute, second))
  if (
    check.getUTCFullYear() !== year ||
    check.getUTCMonth() !== month - 1 ||
    check.getUTCDate() !== day ||
    check.getUTCHours() !== hour ||
    check.getUTCMinutes() !== minute ||
    check.getUTCSeconds() !== second
  ) {
    return null
  }
  return parsed
}

function addScheduleEvent(
  events: AutoRunClubScheduleEventDraft[],
  queryDate: string,
  studentId: number,
  activityId: number,
  signType: '1' | '2',
  rawTime: string | undefined,
): void {
  const event = parseClubEventTime(queryDate, rawTime)
  if (event === null) return
  const eventAt = event.getTime()
  const windowMs = 10 * 60 * 1000
  events.push({
    studentId,
    actionKey: clubProbeKey(queryDate, activityId, signType),
    activityId,
    signType,
    eventAt,
    windowStart: eventAt - windowMs,
    windowEnd: eventAt + windowMs,
  })
}

function firstNumber(value: unknown, keys: readonly string[]): number | null {
  if (!value || typeof value !== 'object') return null
  const record = value as Record<string, unknown>
  for (const key of keys) {
    const number = asNumber(record[key])
    if (number !== null) return number
  }
  return null
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value)
    if (Number.isFinite(parsed)) return parsed
  }
  return null
}

function safeActivityId(value: unknown): number | null {
  const parsed = asNumber(value)
  return parsed !== null && Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null
}

function readString(value: unknown): string {
  return value === null || value === undefined ? '' : String(value).trim()
}
