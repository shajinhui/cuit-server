export const DEFAULT_AUTORUN_API_BASE_URL = 'https://autorun-ts.fanxiaogao05.workers.dev'

interface AutoRunApiEnvelope<T> {
  code: number
  msg: string
  response: T
}

export interface AutoRunApiResult<T> {
  data: T
  message: string
}

export interface AutoRunSession {
  userId: number
  studentId: number
  schoolId: number
  tokenSrc: string
  sessionKey: string
}

export interface AutoRunRunInfo {
  runCount?: number | string
  runValidCount?: number | string
  runDistance?: number | string
  runValidDistance?: number | string
  [key: string]: unknown
}

export interface AutoRunRunData {
  runStandard: Record<string, unknown>
  runInfo: AutoRunRunInfo
  tokenSrc?: string
  sessionKey?: string
}

export interface AutoRunClubActivity {
  clubActivityId: number
  activityName: string
  signInStudent: number
  maxStudent: number
  cancelSign: string
  startTime: string
  endTime: string
  addressDetail?: string
  clubIntroduction?: string
  teacherName?: string
  optionStatus?: string
  fullActivity?: string
  signStatus?: string
  [key: string]: unknown
}

export interface AutoRunClubSignTask {
  activityId?: number
  clubActivityId?: number
  activityName?: string
  startTime?: string
  endTime?: string
  address?: string
  addressDetail?: string
  latitude?: string | number
  longitude?: string | number
  signStatus?: string | number
  signInStatus?: string | number
  signBackStatus?: string | number
  signInTime?: string
  signBackLimitTime?: number | string
  [key: string]: unknown
}

export interface AutoRunClubSchedule {
  enabled: boolean
  studentId?: number
  lastProbeAt?: string
  lastActionAt?: string
  lastMessage?: string
  updatedAt?: string
}

export interface AutoRunClubData {
  queryDate: string
  signTask: AutoRunClubSignTask | null
  activities: AutoRunClubActivity[]
  joinProgress: {
    totalNum?: number | string
    joinNum?: number | string
    runTotalNum?: number | string
    runJoinNum?: number | string
  }
  topThree: AutoRunClubActivity[]
  schedule: AutoRunClubSchedule
  tokenSrc?: string
  sessionKey?: string
}

export interface AutoRunActionResult {
  success?: boolean
  rawResponse?: string
  sessionKey?: string
  schedule?: AutoRunClubSchedule
  signTask?: AutoRunClubSignTask | null
  nextSignType?: string
  [key: string]: unknown
}

export class AutoRunApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: number,
  ) {
    super(message)
  }
}

const apiBaseURL = (
  import.meta.env.VITE_AUTORUN_API_BASE_URL || DEFAULT_AUTORUN_API_BASE_URL
).replace(/\/+$/, '')

async function callAutoRunApi<T>(
  action: string,
  body: Record<string, unknown> = {},
  sessionKey?: string,
): Promise<AutoRunApiResult<T>> {
  const response = await fetch(`${apiBaseURL}/api/${action}`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(sessionKey ? { Authorization: `Bearer ${sessionKey}` } : {}),
    },
    body: JSON.stringify(body),
  })

  let payload: AutoRunApiEnvelope<T>
  try {
    payload = (await response.json()) as AutoRunApiEnvelope<T>
  } catch {
    throw new AutoRunApiError('服务响应格式异常', response.status, 50000)
  }

  if (!response.ok || payload.code !== 10000) {
    throw new AutoRunApiError(payload.msg || '请求失败', response.status, payload.code)
  }

  return { data: payload.response, message: payload.msg }
}

export function loginToAutoRun(phone: string, password: string) {
  return callAutoRunApi<AutoRunSession>('login', { phone, password })
}

export function restoreAutoRunSession(sessionKey: string) {
  return callAutoRunApi<AutoRunSession>('session_bootstrap', {}, sessionKey)
}

export function getAutoRunInfo(sessionKey: string) {
  return callAutoRunApi<AutoRunRunData>('run_info', {}, sessionKey)
}

export function submitAutoRun(sessionKey: string) {
  return callAutoRunApi<AutoRunActionResult>('run', {}, sessionKey)
}

export function getAutoRunClubData(sessionKey: string, queryDate: string) {
  return callAutoRunApi<AutoRunClubData>('club_data', { queryDate }, sessionKey)
}

export function signAutoRunClub(sessionKey: string, signType: '1' | '2') {
  return callAutoRunApi<AutoRunActionResult>('club_sign', { signType }, sessionKey)
}

export function joinAutoRunClub(sessionKey: string, activityId: number) {
  return callAutoRunApi<AutoRunActionResult>('club_join', { activityId }, sessionKey)
}

export function cancelAutoRunClub(sessionKey: string, activityId: number) {
  return callAutoRunApi<AutoRunActionResult>('club_cancel', { activityId }, sessionKey)
}

export function setAutoRunClubSchedule(sessionKey: string, enabled: boolean) {
  return callAutoRunApi<AutoRunActionResult>('club_schedule_set', { enabled }, sessionKey)
}
