import { afterEach, describe, expect, it } from 'vitest'

import {
  AUTO_RUN_SESSION_STORAGE_KEY,
  clearAutoRunCredentials,
  clearAutoRunSessionKey,
  loadAutoRunCredentials,
  loadAutoRunSessionKey,
  saveAutoRunCredentials,
  saveAutoRunSessionKey,
} from './session-storage'

afterEach(() => clearAutoRunCredentials())

function createStorage(initial: Record<string, string> = {}) {
  const values = new Map(Object.entries(initial))
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    removeItem: (key: string) => values.delete(key),
  }
}

describe('校园跑登录态存储', () => {
  it('优先读取设备持久化的会话并清理旧会话副本', () => {
    const persistent = createStorage({ [AUTO_RUN_SESSION_STORAGE_KEY]: 'persistent-key' })
    const legacy = createStorage({ [AUTO_RUN_SESSION_STORAGE_KEY]: 'legacy-key' })

    expect(loadAutoRunSessionKey(persistent, legacy)).toBe('persistent-key')
    expect(legacy.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBeNull()
  })

  it('把 sessionStorage 中的旧会话自动迁移到 localStorage', () => {
    const persistent = createStorage()
    const legacy = createStorage({ [AUTO_RUN_SESSION_STORAGE_KEY]: 'legacy-key' })

    expect(loadAutoRunSessionKey(persistent, legacy)).toBe('legacy-key')
    expect(persistent.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBe('legacy-key')
    expect(legacy.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBeNull()
  })

  it('保存时使用持久化存储，退出时同时清理两处', () => {
    const persistent = createStorage()
    const legacy = createStorage({ [AUTO_RUN_SESSION_STORAGE_KEY]: 'stale-key' })

    saveAutoRunSessionKey(' new-key ', persistent, legacy)
    expect(persistent.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBe('new-key')
    expect(legacy.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBeNull()

    clearAutoRunSessionKey(persistent, legacy)
    expect(persistent.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBeNull()
    expect(legacy.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBeNull()
  })

  it('localStorage 不可写时回退到 sessionStorage', () => {
    const persistent = {
      getItem: () => null,
      setItem: () => {
        throw new Error('storage blocked')
      },
      removeItem: () => undefined,
    }
    const fallback = createStorage()

    saveAutoRunSessionKey('fallback-key', persistent, fallback)
    expect(fallback.getItem(AUTO_RUN_SESSION_STORAGE_KEY)).toBe('fallback-key')
  })

  it('账号凭据只保留在当前内存中并可主动清除', () => {
    saveAutoRunCredentials(' 13800000000 ', 'example-password')

    expect(loadAutoRunCredentials()).toEqual({
      phone: '13800000000',
      password: 'example-password',
    })

    clearAutoRunCredentials()
    expect(loadAutoRunCredentials()).toBeUndefined()
  })
})
