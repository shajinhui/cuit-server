import { md5Password } from './md5'

export const AUTORUN_APP_VERSION = '1.8.5'
export const AUTORUN_DEVICE_BRAND = 'Xiaomi'
export const AUTORUN_DEVICE_TYPE = '1'
export const AUTORUN_MOBILE_TYPE = 'Mi 11'
export const AUTORUN_SYS_VERSION = 'Android 11'
export const AUTORUN_USER_AGENT = 'okhttp/4.12.0'

export const AUTORUN_UPSTREAM_PATHS = {
  login: '/v1/auth/login/password',
  schoolBound: '/v1/unirun/querySchoolBound',
  runStandard: '/v1/unirun/query/runStandard',
  runInfo: '/v1/unirun/query/runInfo',
  recordNew: '/v1/unirun/save/run/record/new',
  signInTask: '/v1/clubactivity/getSignInTf',
  signInOrSignBack: '/v1/clubactivity/signInOrSignBack',
  clubActivityList: '/v1/clubactivity/queryActivityList',
  clubJoin: '/v1/clubactivity/joinClubActivity',
  clubCancel: '/v1/clubactivity/cancelActivity',
  clubJoinNum: '/v1/clubactivity/getJoinNum',
  clubTopThree: '/v1/clubactivity/querySchoolActivityTopThree',
} as const

export type AutoRunUpstreamMethod = 'GET' | 'POST'

export interface AutoRunUpstreamRequest<TBody = unknown> {
  method: AutoRunUpstreamMethod
  path: string
  query?: Readonly<Record<string, string>>
  body?: TBody
}

export interface AutoRunLoginPayload {
  appVersion: string
  brand: string
  deviceToken: string
  deviceType: string
  mobileType: string
  password: string
  sysVersion: string
  userPhone: string
}

/**
 * Build the login JSON consumed by tanmasports. The password is only hashed
 * while preparing the request; this module never persists or logs it.
 */
export function buildAutoRunLoginPayload(
  phone: string,
  password: string,
  deviceToken = '',
): AutoRunLoginPayload {
  return {
    appVersion: AUTORUN_APP_VERSION,
    brand: AUTORUN_DEVICE_BRAND,
    deviceToken,
    deviceType: AUTORUN_DEVICE_TYPE,
    mobileType: AUTORUN_MOBILE_TYPE,
    password: md5Password(password),
    sysVersion: AUTORUN_SYS_VERSION,
    userPhone: phone,
  }
}

export function buildSchoolBoundQuery(schoolId: number): Record<string, string> {
  return { schoolId: String(schoolId) }
}

export function buildRunStandardQuery(schoolId: number): Record<string, string> {
  return { schoolId: String(schoolId) }
}

export function buildRunInfoQuery(userId: number, yearSemester: string): Record<string, string> {
  return { userId: String(userId), yearSemester }
}

export function buildSignInTaskQuery(studentId: number): Record<string, string> {
  return { studentId: String(studentId) }
}

export function buildClubActivityQuery(
  studentId: number,
  date: string,
  schoolId: number,
): Record<string, string> {
  return {
    queryTime: date,
    studentId: String(studentId),
    schoolId: String(schoolId),
    pageNo: '1',
    pageSize: '15',
  }
}

export function buildClubJoinNumQuery(schoolId: number, studentId: number): Record<string, string> {
  return { schoolId: String(schoolId), studentId: String(studentId) }
}

export function buildClubActivityMutationQuery(
  studentId: number,
  activityId: number,
): Record<string, string> {
  return { studentId: String(studentId), activityId: String(activityId) }
}

export interface AutoRunSignRequestPayload {
  activityId: number
  latitude: string
  longitude: string
  signType: '1' | '2'
  studentId: number
}

export interface AutoRunSignRequestInput {
  activityId: number
  latitude: string | number
  longitude: string | number
  signType: string
  studentId: number
}

/** Validate and normalize the one-shot club sign mutation body. */
export function buildClubSignPayload(input: AutoRunSignRequestInput): AutoRunSignRequestPayload {
  const signType = input.signType.trim()
  if (signType !== '1' && signType !== '2') throw new Error('signType 只能是 1 或 2')
  if (!Number.isSafeInteger(input.activityId) || input.activityId <= 0) {
    throw new Error('缺少 activityId')
  }

  const latitude = validCoordinate(input.latitude, -90, 90)
  const longitude = validCoordinate(input.longitude, -180, 180)
  if (latitude === undefined || longitude === undefined) throw new Error('签到坐标格式无效')

  return {
    activityId: input.activityId,
    latitude,
    longitude,
    signType,
    studentId: input.studentId,
  }
}

/** Keep JSON serialization separate so the backend can sign the exact bytes. */
export function serializeAutoRunBody(value: unknown): string {
  const serialized = JSON.stringify(value)
  if (serialized === undefined) throw new Error('请求体无法序列化')
  return serialized
}

function validCoordinate(value: string | number, min: number, max: number): string | undefined {
  const normalized = String(value).trim()
  if (normalized === '') return undefined
  const numeric = Number(normalized)
  return Number.isFinite(numeric) && numeric >= min && numeric <= max ? normalized : undefined
}
