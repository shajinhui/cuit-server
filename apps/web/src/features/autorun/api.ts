import type { AutoRunRecordBody } from './run'

export const DEFAULT_AUTORUN_API_BASE_URL = 'https://autorun-api.fanxiaogao05.dpdns.org'

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

export interface AutoRunRunPreparation {
  userId: number
  schoolId: number
  runStandard: Record<string, unknown>
  bounds: Array<{ siteBound?: string }>
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

export function isAutoRunAuthExpiredError(error: unknown) {
  if (!(error instanceof AutoRunApiError)) return false
  if (error.status === 401 || error.code === 40100) return true
  return /登录态.*(?:失效|过期)|登录过期|请重新登录|unauthorized|token/i.test(error.message)
}

export const AUTORUN_LOGIN_TIMEOUT_MS = 20_000
const AUTORUN_REQUEST_TIMEOUT_MS = 60_000

const apiBaseURL = (
  import.meta.env.VITE_AUTORUN_API_BASE_URL || DEFAULT_AUTORUN_API_BASE_URL
).replace(/\/+$/, '')

async function callAutoRunApi<T>(
  action: string,
  body: Record<string, unknown> = {},
  sessionKey?: string,
  timeoutMs = AUTORUN_REQUEST_TIMEOUT_MS,
): Promise<AutoRunApiResult<T>> {
  const controller = new AbortController()
  const timeout = globalThis.setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await fetch(`${apiBaseURL}/api/${action}`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(sessionKey ? { Authorization: `Bearer ${sessionKey}` } : {}),
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    })

    let payload: AutoRunApiEnvelope<T>
    try {
      payload = (await response.json()) as AutoRunApiEnvelope<T>
    } catch {
      if (controller.signal.aborted) {
        throw new AutoRunApiError('请求超时，请检查网络后重试', 0, 40800)
      }
      throw new AutoRunApiError('服务响应格式异常', response.status, 50000)
    }

    if (!response.ok || payload.code !== 10000) {
      throw new AutoRunApiError(payload.msg || '请求失败', response.status, payload.code)
    }

    return { data: payload.response, message: payload.msg }
  } catch (error) {
    if (error instanceof AutoRunApiError) throw error
    if (controller.signal.aborted) {
      throw new AutoRunApiError('请求超时，请检查网络后重试', 0, 40800)
    }
    throw new AutoRunApiError('无法连接校园跑服务，请检查网络后重试', 0, 50300)
  } finally {
    globalThis.clearTimeout(timeout)
  }
}

export function loginToAutoRun(phone: string, password: string) {
  return callAutoRunApi<AutoRunSession>(
    'login',
    { phone, password },
    undefined,
    AUTORUN_LOGIN_TIMEOUT_MS,
  )
}

export function restoreAutoRunSession(sessionKey: string) {
  return callAutoRunApi<AutoRunSession>('session_bootstrap', {}, sessionKey)
}

export function getAutoRunInfo(sessionKey: string) {
  return callAutoRunApi<AutoRunRunData>('run_info', {}, sessionKey)
}

export function prepareAutoRun(sessionKey: string) {
  return callAutoRunApi<AutoRunRunPreparation>('run_prepare', {}, sessionKey)
}

export function submitAutoRun(sessionKey: string, record: AutoRunRecordBody) {
  return callAutoRunApi<AutoRunActionResult>('run', { record }, sessionKey)
}

export function getAutoRunClubData(sessionKey: string, queryDate: string) {
  return callAutoRunApi<AutoRunClubData>('club_data', { queryDate }, sessionKey)
}

export function signAutoRunClub(
  sessionKey: string,
  request: {
    activityId: number
    latitude: string
    longitude: string
    signType: '1' | '2'
  },
) {
  return callAutoRunApi<AutoRunActionResult>('club_sign', request, sessionKey)
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
