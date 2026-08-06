import { offlineStoreName, openOfflineDatabase } from '@/shared/storage/offlineDatabase'

const avatarRecordKey = 'user-avatar'

export type AvatarKind = 'preset' | 'custom'

export interface CachedAvatar {
  version: 1
  kind: AvatarKind
  presetId: number | null
  blob: Blob | null
  updatedAt: number
}

interface AvatarRecord {
  key: string
  value: unknown
}

export async function readAvatarCache(): Promise<CachedAvatar | null> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readonly')
    const request = transaction.objectStore(offlineStoreName).get(avatarRecordKey)

    request.onsuccess = () => {
      const record = request.result as AvatarRecord | undefined
      resolve(isCachedAvatar(record?.value) ? record.value : null)
    }
    request.onerror = () => reject(request.error ?? new Error('读取本地头像失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取本地头像事务失败'))
    }
  })
}

export async function writeAvatarCache(avatar: CachedAvatar): Promise<void> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readwrite')
    transaction.objectStore(offlineStoreName).put({
      key: avatarRecordKey,
      value: avatar,
    } satisfies AvatarRecord)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地头像失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地头像事务失败'))
    }
  })
}

export async function clearAvatarCache(): Promise<void> {
  const database = await openOfflineDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(offlineStoreName, 'readwrite')
    transaction.objectStore(offlineStoreName).delete(avatarRecordKey)

    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('清除本地头像失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('清除本地头像事务失败'))
    }
  })
}

function isCachedAvatar(value: unknown): value is CachedAvatar {
  if (!value || typeof value !== 'object') return false

  const cached = value as Partial<CachedAvatar>
  return (
    cached.version === 1 &&
    (cached.kind === 'preset' || cached.kind === 'custom') &&
    typeof cached.updatedAt === 'number' &&
    (cached.kind === 'custom' ? cached.blob instanceof Blob : typeof cached.presetId === 'number')
  )
}
