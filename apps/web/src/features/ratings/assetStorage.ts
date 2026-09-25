interface StoredRatingAsset {
  key: string
  blob: Blob
  bytes: number
  cachedAt: number
}

const databaseName = 'chengxin-youyou-rating-assets'
const storeName = 'assets'
const maxStoredAssets = 128
const maxStoredBytes = 64 * 1024 * 1024

function assetKey(scope: string, assetID: string) {
  return JSON.stringify([scope, assetID])
}

function openDatabase(): Promise<IDBDatabase> {
  if (typeof indexedDB === 'undefined') return Promise.reject(new Error('不支持本地图片缓存'))
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(databaseName, 1)
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(storeName)) request.result.createObjectStore(storeName, { keyPath: 'key' })
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error ?? new Error('无法打开本地图片缓存'))
    request.onblocked = () => reject(new Error('本地图片缓存正在被其他页面使用'))
  })
}

export async function readStoredRatingAsset(scope: string, assetID: string): Promise<Blob | null> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readonly')
    const request = transaction.objectStore(storeName).get(assetKey(scope, assetID))
    request.onsuccess = () => {
      const value = request.result as StoredRatingAsset | undefined
      resolve(value?.blob instanceof Blob ? value.blob : null)
    }
    request.onerror = () => reject(request.error ?? new Error('读取本地图片失败'))
    transaction.oncomplete = () => database.close()
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('读取本地图片失败'))
    }
  })
}

export async function writeStoredRatingAsset(scope: string, assetID: string, blob: Blob): Promise<void> {
  if (!blob.size || blob.size > maxStoredBytes) return
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readwrite')
    const store = transaction.objectStore(storeName)
    const key = assetKey(scope, assetID)
    const request = store.getAll()
    request.onsuccess = () => {
      const existing = request.result as StoredRatingAsset[]
      const kept = existing.filter((item) => item.key !== key).sort((a, b) => b.cachedAt - a.cachedAt)
      let bytes = blob.size
      let count = 1
      for (const item of kept) {
        if (count < maxStoredAssets && bytes + item.bytes <= maxStoredBytes) {
          bytes += item.bytes
          count += 1
        } else {
          store.delete(item.key)
        }
      }
      store.put({ key, blob, bytes: blob.size, cachedAt: Date.now() } satisfies StoredRatingAsset)
    }
    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地图片失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('保存本地图片失败'))
    }
  })
}

export async function clearStoredRatingAssets(): Promise<void> {
  const database = await openDatabase()
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, 'readwrite')
    transaction.objectStore(storeName).clear()
    transaction.oncomplete = () => {
      database.close()
      resolve()
    }
    transaction.onerror = () => {
      database.close()
      reject(transaction.error ?? new Error('清除本地图片失败'))
    }
    transaction.onabort = () => {
      database.close()
      reject(transaction.error ?? new Error('清除本地图片失败'))
    }
  })
}
