export const offlineStoreName = 'offline-data'

const databaseName = 'chengxin-youyou'
const databaseVersion = 1

export function openOfflineDatabase(): Promise<IDBDatabase> {
  if (typeof indexedDB === 'undefined') {
    return Promise.reject(new Error('当前浏览器不支持离线数据存储'))
  }

  return new Promise((resolve, reject) => {
    const request = indexedDB.open(databaseName, databaseVersion)
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(offlineStoreName)) {
        request.result.createObjectStore(offlineStoreName, { keyPath: 'key' })
      }
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error ?? new Error('打开离线数据存储失败'))
    request.onblocked = () => reject(new Error('离线数据存储正在被其他页面占用'))
  })
}
