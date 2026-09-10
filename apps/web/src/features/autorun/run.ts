import { businessDate } from './club'
import {
  AUTORUN_APP_VERSION,
  AUTORUN_DEVICE_BRAND,
  AUTORUN_MOBILE_TYPE,
  AUTORUN_SYS_VERSION,
} from './request'
import { calculateDistance, generateTrack, loadTrackMap, type RandomSource, type TrackLocation } from './track'

export interface AutoRunRunIdentity {
  userId: number
  schoolId: number
}

export interface AutoRunRunStandard extends Record<string, unknown> {
  semesterYear?: string | number
}

export interface AutoRunSchoolBound {
  siteBound?: string
}

export interface AutoRunRecordBody {
  againRunStatus: string
  againRunTime: number
  appVersions: string
  brand: string
  mobileType: string
  sysVersions: string
  trackPoints: string
  distanceTimeStatus: string
  innerSchool: string
  runDistance: number
  runTime: number
  userId: number
  vocalStatus: string
  yearSemester: string
  recordDate: string
  realityTrackPoints: string
}

export interface BuildAutoRunRecordBodyOptions {
  identity: AutoRunRunIdentity
  standard: AutoRunRunStandard
  bounds: readonly AutoRunSchoolBound[]
  now?: Date
  random?: RandomSource
  locations?: readonly TrackLocation[]
  runDistance?: number
  runTime?: number
}

function secureRandom(): number {
  const value = new Uint32Array(1)
  globalThis.crypto.getRandomValues(value)
  return (value[0] ?? 0) / 0x1_0000_0000
}

/** Inclusive random integer range used by the original run preparation flow. */
export function randomRange(min: number, max: number, random: RandomSource = secureRandom): number {
  return min + Math.floor(random() * (max - min + 1))
}

/**
 * Build the complete run mutation body from already-fetched read-only data.
 * The browser owns random values, date conversion and track serialization;
 * the backend only needs to forward this body and add its private signature.
 */
export function buildAutoRunRecordBody({
  identity,
  standard,
  bounds,
  now = new Date(),
  random = secureRandom,
  locations = loadTrackMap(),
  runDistance = randomRange(4_675, 5_174, random),
  runTime = randomRange(31, 35, random),
}: BuildAutoRunRecordBodyOptions): AutoRunRecordBody {
  const yearSemester = readString(standard.semesterYear)
  if (yearSemester === '') throw new Error('跑步标准缺少学期')

  const bound = bounds[0]?.siteBound
  const realityTrackPoints = readString(bound) !== '' ? `${readString(bound)}--` : '00.000,00.000--'

  return {
    againRunStatus: '0',
    againRunTime: 0,
    appVersions: AUTORUN_APP_VERSION,
    brand: AUTORUN_DEVICE_BRAND,
    mobileType: AUTORUN_MOBILE_TYPE,
    sysVersions: AUTORUN_SYS_VERSION,
    trackPoints: generateTrack(runDistance, locations, random, now),
    distanceTimeStatus: '1',
    innerSchool: '1',
    runDistance,
    runTime,
    userId: identity.userId,
    vocalStatus: '1',
    yearSemester,
    recordDate: businessDate(now),
    realityTrackPoints,
  }
}

/** Alias matching the source domain terminology. */
export const prepareRunRequest = buildAutoRunRecordBody

export { calculateDistance }

function readString(value: unknown): string {
  return value === null || value === undefined ? '' : String(value).trim()
}
