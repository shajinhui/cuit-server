import { offlineStoreName, openOfflineDatabase } from '@/shared/storage/offlineDatabase'
import type { Semester } from '@/shared/models/academic'

import type { Classroom, ClassroomOccupancy, ClassroomSchedule } from './api'

const classroomScheduleKeyPrefix = 'classroom-schedule:'
const classroomInitializationKey = 'classroom-initialization'
const classroomScheduleCacheVersion = 2

export interface CachedClassroomSchedule {
  version: 2
  semesterID: string
  campusID: string
  schedule: ClassroomSchedule
  cachedAt: number
}

export interface CachedClassroomInitialization {
  version: 1
  semesters: Semester[]
  selectedSemesterID: string
  currentWeek: number
  selectedCampusID: string
  cachedAt: number
}

interface ClassroomScheduleRecord {
  key: string
  value: unknown
}

export async function readClassroomScheduleCache(
  semesterID: string,
  campusID: string,
): Promise<CachedClassroomSchedule | null> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readonly')
    const request = transaction
      .objectStore(offlineStoreName)
      .get(classroomScheduleKey(semesterID, campusID))

    request.onsuccess = () => {
      const record = request.result as ClassroomScheduleRecord | undefined
      resolve(
        isCachedClassroomSchedule(record?.value, semesterID, campusID) ? record.value : null,
      )
    }
    request.onerror = () => reject(request.error ?? new Error('读取本地教室课表失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取本地教室课表事务失败'))
    }
  })
}

export async function writeClassroomScheduleCache(
  schedule: ClassroomSchedule,
  cachedAt = Date.now(),
): Promise<CachedClassroomSchedule> {
  const database = await openOfflineDatabase()
  const value: CachedClassroomSchedule = {
    version: classroomScheduleCacheVersion,
    semesterID: schedule.SemesterID,
    campusID: schedule.CampusID,
    // Pinia 数据是响应式代理，先转成普通 JSON，确保 IndexedDB 可以结构化克隆。
    schedule: JSON.parse(JSON.stringify(schedule)) as ClassroomSchedule,
    cachedAt,
  }
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readwrite')
    transaction.objectStore(offlineStoreName).put({
      key: classroomScheduleKey(schedule.SemesterID, schedule.CampusID),
      value,
    } satisfies ClassroomScheduleRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve(value)
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地教室课表失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地教室课表事务失败'))
    }
  })
}

export async function readClassroomInitializationCache(): Promise<CachedClassroomInitialization | null> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readonly')
    const request = transaction.objectStore(offlineStoreName).get(classroomInitializationKey)

    request.onsuccess = () => {
      const record = request.result as ClassroomScheduleRecord | undefined
      resolve(isCachedClassroomInitialization(record?.value) ? record.value : null)
    }
    request.onerror = () => reject(request.error ?? new Error('读取本地空教室查询条件失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取本地空教室查询条件事务失败'))
    }
  })
}

export async function writeClassroomInitializationCache(
  value: Omit<CachedClassroomInitialization, 'version' | 'cachedAt'>,
): Promise<void> {
  const database = await openOfflineDatabase()
  const cached: CachedClassroomInitialization = {
    version: 1,
    semesters: JSON.parse(JSON.stringify(value.semesters)) as Semester[],
    selectedSemesterID: value.selectedSemesterID,
    currentWeek: value.currentWeek,
    selectedCampusID: value.selectedCampusID,
    cachedAt: Date.now(),
  }
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readwrite')
    transaction.objectStore(offlineStoreName).put({
      key: classroomInitializationKey,
      value: cached,
    } satisfies ClassroomScheduleRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地空教室查询条件失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地空教室查询条件事务失败'))
    }
  })
}

export async function clearClassroomScheduleCache(): Promise<void> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readwrite')
    const request = transaction.objectStore(offlineStoreName).openCursor()

    request.onsuccess = () => {
      const cursor = request.result
      if (!cursor) return
      if (
        typeof cursor.key === 'string' &&
        (cursor.key.startsWith(classroomScheduleKeyPrefix) ||
          cursor.key === classroomInitializationKey)
      ) {
        cursor.delete()
      }
      cursor.continue()
    }
    request.onerror = () => reject(request.error ?? new Error('清除本地教室课表失败'))
    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('清除本地教室课表事务失败'))
    }
  })
}

export async function hasClassroomScheduleCache(): Promise<boolean> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readonly')
    const request = transaction.objectStore(offlineStoreName).openKeyCursor()
    let found = false

    request.onsuccess = () => {
      const cursor = request.result
      if (!cursor) return
      if (
        typeof cursor.key === 'string' &&
        cursor.key.startsWith(classroomScheduleKeyPrefix)
      ) {
        found = true
        return
      }
      cursor.continue()
    }
    request.onerror = () => reject(request.error ?? new Error('检查本地教室课表失败'))
    transaction.oncomplete = () => {
      database.close()
      resolve(found)
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('检查本地教室课表事务失败'))
    }
  })
}

function isCachedClassroomInitialization(
  value: unknown,
): value is CachedClassroomInitialization {
  if (!value || typeof value !== 'object') return false

  const cached = value as Partial<CachedClassroomInitialization>
  return (
    cached.version === 1 &&
    Array.isArray(cached.semesters) &&
    cached.semesters.length > 0 &&
    cached.semesters.every(isSemester) &&
    typeof cached.selectedSemesterID === 'string' &&
    cached.semesters.some((semester) => semester.ID === cached.selectedSemesterID) &&
    Number.isInteger(cached.currentWeek) &&
    Number(cached.currentWeek) >= 1 &&
    typeof cached.selectedCampusID === 'string' &&
    typeof cached.cachedAt === 'number'
  )
}

function isSemester(value: unknown): value is Semester {
  if (!value || typeof value !== 'object') return false

  const semester = value as Partial<Semester>
  return (
    typeof semester.ID === 'string' &&
    typeof semester.SchoolYear === 'string' &&
    typeof semester.Term === 'string' &&
    (semester.Current === undefined || typeof semester.Current === 'boolean')
  )
}

function classroomScheduleKey(semesterID: string, campusID: string) {
  return `${classroomScheduleKeyPrefix}${semesterID}:${campusID}`
}

function isCachedClassroomSchedule(
  value: unknown,
  semesterID: string,
  campusID: string,
): value is CachedClassroomSchedule {
  if (!value || typeof value !== 'object') return false

  const cached = value as Partial<CachedClassroomSchedule>
  return (
    cached.version === classroomScheduleCacheVersion &&
    cached.semesterID === semesterID &&
    cached.campusID === campusID &&
    typeof cached.cachedAt === 'number' &&
    isClassroomSchedule(cached.schedule, semesterID, campusID)
  )
}

function isClassroomSchedule(
  value: unknown,
  semesterID: string,
  campusID: string,
): value is ClassroomSchedule {
  if (!value || typeof value !== 'object') return false

  const schedule = value as Partial<ClassroomSchedule>
  return (
    schedule.SemesterID === semesterID &&
    schedule.CampusID === campusID &&
    Array.isArray(schedule.Rooms) &&
    schedule.Rooms.every(
      (entry) =>
        Boolean(entry) &&
        isClassroom(entry.Classroom) &&
        Array.isArray(entry.Occupancies) &&
        entry.Occupancies.every(isClassroomOccupancy),
    )
  )
}

function isClassroom(value: unknown): value is Classroom {
  if (!value || typeof value !== 'object') return false

  const room = value as Partial<Classroom>
  return (
    typeof room.ID === 'string' &&
    typeof room.Code === 'string' &&
    typeof room.Name === 'string' &&
    typeof room.Building === 'string' &&
    typeof room.Campus === 'string' &&
    typeof room.Type === 'string' &&
    typeof room.Capacity === 'number'
  )
}

function isClassroomOccupancy(value: unknown): value is ClassroomOccupancy {
  if (!value || typeof value !== 'object') return false

  const occupancy = value as Partial<ClassroomOccupancy>
  return (
    Number.isInteger(occupancy.Weekday) &&
    Number.isInteger(occupancy.StartSection) &&
    Number.isInteger(occupancy.EndSection) &&
    Array.isArray(occupancy.Weeks) &&
    occupancy.Weeks.every(Number.isInteger)
  )
}
