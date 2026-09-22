interface RatingAssetCacheEntry {
  promise: Promise<string>
  source: string
  bytes: number
}

const maxCachedAssets = 48
const maxCachedBytes = 64 * 1024 * 1024
const entries = new Map<string, RatingAssetCacheEntry>()
let cachedBytes = 0

export function cachedRatingAssetSource(assetID: string, load: () => Promise<Blob>) {
  const cached = entries.get(assetID)
  if (cached) {
    // Map insertion order doubles as a small LRU list.
    entries.delete(assetID)
    entries.set(assetID, cached)
    return cached.promise
  }

  const entry: RatingAssetCacheEntry = {
    promise: Promise.resolve(''),
    source: '',
    bytes: 0,
  }
  entry.promise = Promise.resolve()
    .then(load)
    .then((blob) => {
      if (entries.get(assetID) !== entry) throw new Error('图片加载已取消')
      entry.source = URL.createObjectURL(blob)
      entry.bytes = blob.size
      cachedBytes += blob.size
      trimRatingAssetCache(assetID)
      return entry.source
    })
    .catch((error) => {
      if (entries.get(assetID) === entry) entries.delete(assetID)
      throw error
    })
  entries.set(assetID, entry)
  return entry.promise
}

export function clearRatingAssetCache() {
  for (const entry of entries.values()) {
    if (entry.source) URL.revokeObjectURL(entry.source)
  }
  entries.clear()
  cachedBytes = 0
}

function trimRatingAssetCache(preserveAssetID: string) {
  while (entries.size > maxCachedAssets || cachedBytes > maxCachedBytes) {
    const candidate = Array.from(entries).find(
      ([assetID, entry]) => assetID !== preserveAssetID && Boolean(entry.source),
    )
    if (!candidate) return
    const [assetID, entry] = candidate
    entries.delete(assetID)
    cachedBytes = Math.max(0, cachedBytes - entry.bytes)
    URL.revokeObjectURL(entry.source)
  }
}
