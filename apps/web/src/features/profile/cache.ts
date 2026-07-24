import { offlineStoreName, openOfflineDatabase } from '@/shared/storage/offlineDatabase'

import type { StudentProfile } from './api'

const profileRecordKey = 'student-profile'

interface CachedProfile {
  version: 1
  profile: StudentProfile
  cachedAt: number
}

interface ProfileRecord {
  key: string
  value: unknown
}

export async function readProfileCache(): Promise<CachedProfile | null> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readonly')
    const request = transaction.objectStore(offlineStoreName).get(profileRecordKey)

    request.onsuccess = () => {
      const record = request.result as ProfileRecord | undefined
      resolve(isCachedProfile(record?.value) ? record.value : null)
    }
    request.onerror = () => reject(request.error ?? new Error('读取本地个人信息失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取本地个人信息事务失败'))
    }
  })
}

export async function writeProfileCache(profile: StudentProfile): Promise<void> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readwrite')
    const value: CachedProfile = {
      version: 1,
      profile: JSON.parse(JSON.stringify(profile)) as StudentProfile,
      cachedAt: Date.now(),
    }
    transaction.objectStore(offlineStoreName).put({ key: profileRecordKey, value } satisfies ProfileRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地个人信息失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地个人信息事务失败'))
    }
  })
}

export async function clearProfileCache(): Promise<void> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readwrite')
    transaction.objectStore(offlineStoreName).delete(profileRecordKey)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('清除本地个人信息失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('清除本地个人信息事务失败'))
    }
  })
}

export async function hasProfileCache(): Promise<boolean> {
  return (await readProfileCache()) !== null
}

function isCachedProfile(value: unknown): value is CachedProfile {
  if (!value || typeof value !== 'object') return false

  const cached = value as Partial<CachedProfile>
  const profile = cached.profile as Partial<StudentProfile> | undefined
  return (
    cached.version === 1 &&
    typeof cached.cachedAt === 'number' &&
    Boolean(profile) &&
    typeof profile?.StudentNo === 'string' &&
    typeof profile?.Name === 'string'
  )
}
