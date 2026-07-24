import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/shared/api/client'

import { getSessionStatus, loginJWXT, logoutJWXT } from './api'
import { useSessionStore } from './store'

vi.mock('./api', () => ({
  getSessionStatus: vi.fn(),
  loginJWXT: vi.fn(),
  logoutJWXT: vi.fn(),
}))

const getSessionStatusMock = vi.mocked(getSessionStatus)
const loginJWXTMock = vi.mocked(loginJWXT)
const logoutJWXTMock = vi.mocked(logoutJWXT)

describe('session store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('marks a valid remote session as authenticated', async () => {
    getSessionStatusMock.mockResolvedValue({ authenticated: true })
    const store = useSessionStore()

    await expect(store.check()).resolves.toBe(true)
    expect(store.status).toBe('authenticated')
  })

  it('uses offline state only when remote status is unavailable and local data exists', async () => {
    getSessionStatusMock.mockRejectedValue(new Error('network unavailable'))
    const hasOfflineData = vi.fn().mockResolvedValue(true)
    const store = useSessionStore()

    await expect(store.check(hasOfflineData)).resolves.toBe(false)
    expect(hasOfflineData).toHaveBeenCalledOnce()
    expect(store.status).toBe('offline')
  })

  it('treats a remote 401 as anonymous without checking offline data', async () => {
    getSessionStatusMock.mockRejectedValue(new ApiError('会话已失效', 401, 40100))
    const hasOfflineData = vi.fn().mockResolvedValue(true)
    const store = useSessionStore()

    await expect(store.check(hasOfflineData)).resolves.toBe(false)
    expect(hasOfflineData).not.toHaveBeenCalled()
    expect(store.status).toBe('anonymous')
  })

  it('finishes login and logout transitions even when a request fails', async () => {
    loginJWXTMock.mockRejectedValue(new Error('登录失败'))
    const store = useSessionStore()

    await expect(store.login('student', 'password')).rejects.toThrow('登录失败')
    expect(store.loading).toBe(false)
    expect(store.status).toBe('anonymous')
    expect(store.error).toBe('登录失败')

    store.markAuthenticated()
    logoutJWXTMock.mockRejectedValue(new Error('退出失败'))
    await expect(store.logout()).rejects.toThrow('退出失败')
    expect(store.status).toBe('anonymous')
  })
})
