import type { Semester } from '@/shared/models/academic'
import {
  offlineStoreName as storeName,
  openOfflineDatabase as openDatabase,
} from '@/shared/storage/offlineDatabase'

import type { CourseTable } from './api'
import {
  isCourseColorPreference,
  type CourseColorPreference,
} from './model/courseColor'
import { isCourseOverride, type CourseOverride } from './model/courseOverride'
import { isManualCourse, type ManualCourse } from './model/manualCourse'

const scheduleRecordKey = 'latest-schedule'
const scheduleLaunchSnapshotKey = 'schedule-launch-snapshot-v3'
const manualCoursesRecordKey = 'manual-courses'
const courseOverridesRecordKey = 'course-overrides'
const courseColorPreferencesRecordKey = 'course-color-preferences'

export interface CachedSchedule {
  version: 3
  semesters: Semester[]
  selectedSemesterID: string
  table: CourseTable
  currentWeek: number
  cachedAt: number
}

interface ScheduleRecord {
  key: string
  value: unknown
}

export async function readScheduleCache(): Promise<CachedSchedule | null> {
  const launchSnapshot = readScheduleLaunchSnapshot()
  if (launchSnapshot) return launchSnapshot

  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readonly')
    const request = transaction.objectStore(storeName).get(scheduleRecordKey)

    request.onsuccess = () => {
      const record = request.result as ScheduleRecord | undefined
      const cachedSchedule = isCachedSchedule(record?.value) ? record.value : null
      if (cachedSchedule) writeScheduleLaunchSnapshot(cachedSchedule)
      resolve(cachedSchedule)
    }
    request.onerror = () => reject(request.error ?? new Error('读取离线课表失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取离线课表事务失败'))
    }
  })
}

export async function writeScheduleCache(value: CachedSchedule): Promise<void> {
  const plainValue = JSON.parse(JSON.stringify(value)) as CachedSchedule
  writeScheduleLaunchSnapshot(plainValue)

  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readwrite')
    // Pinia state 是响应式代理，IndexedDB 无法直接结构化克隆；课表模型只含 JSON 字段，先转为普通对象再持久化。
    transaction.objectStore(storeName).put({ key: scheduleRecordKey, value: plainValue } satisfies ScheduleRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存离线课表失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存离线课表事务失败'))
    }
  })
}

export async function readManualCourses(): Promise<ManualCourse[]> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readonly')
    const request = transaction.objectStore(storeName).get(manualCoursesRecordKey)

    request.onsuccess = () => {
      const record = request.result as ScheduleRecord | undefined
      const courses = record?.value
      resolve(Array.isArray(courses) && courses.every(isManualCourse) ? courses : [])
    }
    request.onerror = () => reject(request.error ?? new Error('读取手动课程失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取手动课程事务失败'))
    }
  })
}

export async function writeManualCourses(courses: ManualCourse[]): Promise<void> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readwrite')
    const plainCourses = JSON.parse(JSON.stringify(courses)) as ManualCourse[]
    transaction
      .objectStore(storeName)
      .put({ key: manualCoursesRecordKey, value: plainCourses } satisfies ScheduleRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存手动课程失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存手动课程事务失败'))
    }
  })
}

export async function readCourseOverrides(): Promise<CourseOverride[]> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readonly')
    const request = transaction.objectStore(storeName).get(courseOverridesRecordKey)

    request.onsuccess = () => {
      const record = request.result as ScheduleRecord | undefined
      const courseOverrides = record?.value
      resolve(
        Array.isArray(courseOverrides) && courseOverrides.every(isCourseOverride)
          ? courseOverrides
          : [],
      )
    }
    request.onerror = () => reject(request.error ?? new Error('读取课程修改失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取课程修改事务失败'))
    }
  })
}

export async function writeCourseOverrides(courseOverrides: CourseOverride[]): Promise<void> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readwrite')
    const plainCourseOverrides = JSON.parse(JSON.stringify(courseOverrides)) as CourseOverride[]
    transaction
      .objectStore(storeName)
      .put({ key: courseOverridesRecordKey, value: plainCourseOverrides } satisfies ScheduleRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存课程修改失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存课程修改事务失败'))
    }
  })
}

export async function readCourseColorPreferences(): Promise<CourseColorPreference[]> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readonly')
    const request = transaction.objectStore(storeName).get(courseColorPreferencesRecordKey)

    request.onsuccess = () => {
      const record = request.result as ScheduleRecord | undefined
      const preferences = record?.value
      resolve(
        Array.isArray(preferences) && preferences.every(isCourseColorPreference)
          ? preferences
          : [],
      )
    }
    request.onerror = () => reject(request.error ?? new Error('读取课程颜色失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取课程颜色事务失败'))
    }
  })
}

export async function writeCourseColorPreferences(
  preferences: CourseColorPreference[],
): Promise<void> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readwrite')
    const plainPreferences = JSON.parse(JSON.stringify(preferences)) as CourseColorPreference[]
    transaction.objectStore(storeName).put({
      key: courseColorPreferencesRecordKey,
      value: plainPreferences,
    } satisfies ScheduleRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存课程颜色失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存课程颜色事务失败'))
    }
  })
}

export async function clearScheduleCache(): Promise<void> {
  removeScheduleLaunchSnapshot()

  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readwrite')
    const objectStore = transaction.objectStore(storeName)
    objectStore.delete(scheduleRecordKey)
    objectStore.delete(manualCoursesRecordKey)
    objectStore.delete(courseOverridesRecordKey)
    objectStore.delete(courseColorPreferencesRecordKey)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('清除离线课表失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('清除离线课表事务失败'))
    }
  })
}

function readScheduleLaunchSnapshot(): CachedSchedule | null {
  try {
    const value = window.localStorage.getItem(scheduleLaunchSnapshotKey)
    if (!value) return null

    const parsed: unknown = JSON.parse(value)
    if (isCachedSchedule(parsed)) return parsed
  } catch {
    // localStorage 不可用或快照损坏时继续读取 IndexedDB。
  }
  removeScheduleLaunchSnapshot()
  return null
}

function writeScheduleLaunchSnapshot(value: CachedSchedule) {
  try {
    window.localStorage.setItem(scheduleLaunchSnapshotKey, JSON.stringify(value))
  } catch {
    // 快照只是冷启动加速层，存储失败不影响 IndexedDB 主缓存。
  }
}

function removeScheduleLaunchSnapshot() {
  try {
    window.localStorage.removeItem(scheduleLaunchSnapshotKey)
  } catch {
    // localStorage 不可用时无需额外处理。
  }
}

export async function hasScheduleCache(): Promise<boolean> {
  return (await readScheduleCache()) !== null
}

function isCachedSchedule(value: unknown): value is CachedSchedule {
  if (!value || typeof value !== 'object') return false

  const cache = value as Partial<CachedSchedule>
  return (
    cache.version === 3 &&
    Array.isArray(cache.semesters) &&
    typeof cache.selectedSemesterID === 'string' &&
    Boolean(cache.table) &&
    typeof cache.currentWeek === 'number' &&
    typeof cache.cachedAt === 'number'
  )
}
