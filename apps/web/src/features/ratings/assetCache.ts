import {
  clearStoredRatingAssets,
  readStoredRatingAsset,
  writeStoredRatingAsset,
} from './assetStorage'

interface RatingAssetCacheEntry {
  promise: Promise<string>
  source: string
  bytes: number
  references: number
}

export interface RatingAssetHandle {
  source: string
  release: () => void
}

const maxCachedAssets = 128
const maxCachedBytes = 64 * 1024 * 1024
const entries = new Map<string, RatingAssetCacheEntry>()
let cachedBytes = 0
let cacheGeneration = 0
let storageWrites: Promise<void> = Promise.resolve()

function cacheKey(scope: string, assetID: string) {
  return JSON.stringify([scope, assetID])
}

export async function cachedRatingAssetSource(
  scope: string,
  assetID: string,
  load: () => Promise<Blob>,
): Promise<RatingAssetHandle> {
  const key = cacheKey(scope, assetID)
  const cached = entries.get(key)
  if (cached) {
    entries.delete(key)
    entries.set(key, cached)
    return acquire(cached)
  }

  const generation = cacheGeneration
  const entry: RatingAssetCacheEntry = {
    promise: Promise.resolve(''),
    source: '',
    bytes: 0,
    references: 0,
  }
  entry.promise = Promise.resolve()
    .then(async () => {
      const stored = await readStoredRatingAsset(scope, assetID).catch(() => null)
      if (generation !== cacheGeneration || entries.get(key) !== entry) throw new Error('图片加载已取消')
      if (stored) return stored
      const blob = await load()
      if (generation !== cacheGeneration || entries.get(key) !== entry) throw new Error('图片加载已取消')
      storageWrites = storageWrites
        .then(() => generation === cacheGeneration ? writeStoredRatingAsset(scope, assetID, blob) : undefined)
        .catch(() => undefined)
      return blob
    })
    .then((blob) => {
      if (generation !== cacheGeneration || entries.get(key) !== entry) throw new Error('图片加载已取消')
      entry.source = URL.createObjectURL(blob)
      entry.bytes = blob.size
      cachedBytes += blob.size
      trimRatingAssetCache(key)
      return entry.source
    })
    .catch((error) => {
      if (entries.get(key) === entry) entries.delete(key)
      throw error
    })
  entries.set(key, entry)
  return acquire(entry)
}

async function acquire(entry: RatingAssetCacheEntry): Promise<RatingAssetHandle> {
  const source = await entry.promise
  entry.references += 1
  let released = false
  return {
    source,
    release: () => {
      if (released) return
      released = true
      entry.references = Math.max(0, entry.references - 1)
      trimRatingAssetCache('')
    },
  }
}

export function clearRatingAssetCache(): Promise<void> {
  cacheGeneration += 1
  for (const entry of entries.values()) {
    if (entry.source) URL.revokeObjectURL(entry.source)
  }
  entries.clear()
  cachedBytes = 0
  storageWrites = storageWrites.then(clearStoredRatingAssets).catch(() => undefined)
  return storageWrites
}

function trimRatingAssetCache(preserveKey: string) {
  while (entries.size > maxCachedAssets || cachedBytes > maxCachedBytes) {
    const candidate = Array.from(entries).find(
      ([key, entry]) => key !== preserveKey && entry.references === 0 && Boolean(entry.source),
    )
    if (!candidate) return
    const [key, entry] = candidate
    entries.delete(key)
    cachedBytes = Math.max(0, cachedBytes - entry.bytes)
    URL.revokeObjectURL(entry.source)
  }
}
