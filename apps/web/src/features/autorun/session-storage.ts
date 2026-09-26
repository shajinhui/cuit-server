export const AUTO_RUN_SESSION_STORAGE_KEY = 'autorun.sessionKey'

interface SessionStorageLike {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
  removeItem(key: string): void
}

function read(storage: SessionStorageLike, key: string) {
  try {
    return storage.getItem(key)?.trim() ?? ''
  } catch {
    return ''
  }
}

function write(storage: SessionStorageLike, key: string, value: string) {
  try {
    storage.setItem(key, value)
    return true
  } catch {
    return false
  }
}

function remove(storage: SessionStorageLike, key: string) {
  try {
    storage.removeItem(key)
  } catch {
    // Storage may be unavailable in a restrictive browser mode.
  }
}

export function loadAutoRunSessionKey(
  persistentStorage: SessionStorageLike,
  legacySessionStorage: SessionStorageLike,
) {
  const persistentSessionKey = read(persistentStorage, AUTO_RUN_SESSION_STORAGE_KEY)
  if (persistentSessionKey) {
    remove(legacySessionStorage, AUTO_RUN_SESSION_STORAGE_KEY)
    return persistentSessionKey
  }

  const legacySessionKey = read(legacySessionStorage, AUTO_RUN_SESSION_STORAGE_KEY)
  if (!legacySessionKey) return ''

  if (write(persistentStorage, AUTO_RUN_SESSION_STORAGE_KEY, legacySessionKey)) {
    remove(legacySessionStorage, AUTO_RUN_SESSION_STORAGE_KEY)
  }
  return legacySessionKey
}

export function saveAutoRunSessionKey(
  sessionKey: string,
  persistentStorage: SessionStorageLike,
  fallbackSessionStorage: SessionStorageLike,
) {
  const normalized = sessionKey.trim()
  if (!normalized) return

  if (write(persistentStorage, AUTO_RUN_SESSION_STORAGE_KEY, normalized)) {
    remove(fallbackSessionStorage, AUTO_RUN_SESSION_STORAGE_KEY)
    return
  }

  write(fallbackSessionStorage, AUTO_RUN_SESSION_STORAGE_KEY, normalized)
}

export function clearAutoRunSessionKey(
  persistentStorage: SessionStorageLike,
  legacySessionStorage: SessionStorageLike,
) {
  remove(persistentStorage, AUTO_RUN_SESSION_STORAGE_KEY)
  remove(legacySessionStorage, AUTO_RUN_SESSION_STORAGE_KEY)
}
