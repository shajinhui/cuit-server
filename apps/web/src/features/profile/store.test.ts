import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'

import { getStudentProfile, type StudentProfile } from './api'
import { readProfileCache, writeProfileCache } from './cache'
import { useProfileStore } from './store'

vi.mock('./api', () => ({
  getStudentProfile: vi.fn(),
}))

vi.mock('./cache', () => ({
  readProfileCache: vi.fn(),
  writeProfileCache: vi.fn(),
}))

const getStudentProfileMock = vi.mocked(getStudentProfile)
const readProfileCacheMock = vi.mocked(readProfileCache)
const writeProfileCacheMock = vi.mocked(writeProfileCache)

const cachedProfile = {
  StudentNo: '20240001',
  Name: '缓存同学',
  Campus: '龙泉校区',
} as StudentProfile

const freshProfile = {
  StudentNo: '20240001',
  Name: '最新同学',
} as StudentProfile

describe('profile store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    readProfileCacheMock.mockResolvedValue(null)
    writeProfileCacheMock.mockResolvedValue()
  })

  it('keeps cached profile available when the remote service is unavailable', async () => {
    readProfileCacheMock.mockResolvedValue({
      version: 1,
      profile: cachedProfile,
      cachedAt: Date.now(),
    })
    getStudentProfileMock.mockRejectedValue(new Error('network unavailable'))

    const store = useProfileStore()
    await store.load()

    expect(store.profile).toEqual(cachedProfile)
    expect(store.error).toBe('network unavailable')
  })

  it('replaces and persists cached profile after a successful refresh', async () => {
    getStudentProfileMock.mockResolvedValue(freshProfile)

    const store = useProfileStore()
    await store.load()

    expect(store.profile).toEqual(freshProfile)
    expect(writeProfileCacheMock).toHaveBeenCalledWith(freshProfile)
  })

  it('restores the campus without a remote request for cache-first schedule access', async () => {
    readProfileCacheMock.mockResolvedValue({ version: 1, profile: cachedProfile, cachedAt: 1 })
    const store = useProfileStore()
    await store.load(false, { preferCache: true })
    expect(store.profile?.Campus).toBe('龙泉校区')
    expect(getStudentProfileMock).not.toHaveBeenCalled()
    expect(store.loading).toBe(false)
    expect(store.error).toBe('')
  })

  it('refreshes an older cached profile that does not contain a campus', async () => {
    readProfileCacheMock.mockResolvedValue({ version: 1, profile: freshProfile, cachedAt: 1 })
    getStudentProfileMock.mockResolvedValue({ ...freshProfile, Campus: '龙泉校区' })

    const store = useProfileStore()
    await store.load(false, { preferCache: true })

    expect(getStudentProfileMock).toHaveBeenCalledOnce()
    expect(store.profile?.Campus).toBe('龙泉校区')
  })

  it('refreshes an in-memory profile when the schedule still needs its campus', async () => {
    getStudentProfileMock.mockResolvedValue({ ...freshProfile, Campus: '航空港校区' })
    const store = useProfileStore()
    store.profile = freshProfile

    await store.load(false, { preferCache: true })

    expect(getStudentProfileMock).toHaveBeenCalledOnce()
    expect(store.profile?.Campus).toBe('航空港校区')
  })

  it('does not attempt a profile request offline even if no cache exists', async () => {
    useSessionStore().status = 'offline'
    const store = useProfileStore()
    await store.load(false, { preferCache: true })
    expect(getStudentProfileMock).not.toHaveBeenCalled()
    expect(store.loading).toBe(false)
  })

  it('loads and saves the campus once when the local profile is missing', async () => {
    getStudentProfileMock.mockResolvedValue({ ...freshProfile, Campus: '航空港校区' })
    const store = useProfileStore()
    await store.load(false, { preferCache: true })
    await store.load(false, { preferCache: true })
    expect(getStudentProfileMock).toHaveBeenCalledOnce()
    expect(store.profile?.Campus).toBe('航空港校区')
    expect(writeProfileCacheMock).toHaveBeenCalledOnce()
  })

  it('does not expose cached profile after the session expires', async () => {
    readProfileCacheMock.mockResolvedValue({
      version: 1,
      profile: cachedProfile,
      cachedAt: Date.now(),
    })
    getStudentProfileMock.mockRejectedValue(new ApiError('登录已失效', 401, 40101))

    const store = useProfileStore()
    await store.load()

    expect(store.profile).toBeNull()
    expect(useSessionStore().status).toBe('anonymous')
  })
})
