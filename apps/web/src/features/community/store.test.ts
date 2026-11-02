import { createPinia, disposePinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { clearRatingAccessToken } from '@/features/ratings/auth'
import { RatingsApiError } from '@/features/ratings/client'
import { getCommunityProfile, updateCommunityProfile, type CommunityProfile } from './api'
import { useCommunityStore } from './store'

vi.mock('./api', () => ({ getCommunityProfile: vi.fn(), updateCommunityProfile: vi.fn() }))
const profile: CommunityProfile = { id: 'public-id', display_name: '公开昵称', avatar_preset: 2, avatar_asset_id: null, profile_version: 1 }
let pinia: ReturnType<typeof createPinia>
beforeEach(() => { pinia = createPinia(); setActivePinia(pinia); vi.clearAllMocks(); vi.mocked(getCommunityProfile).mockResolvedValue(profile) })
afterEach(() => disposePinia(pinia))

describe('community account isolation', () => {
  it('shares a pending profile request and does not retry on every render', async () => {
    const store = useCommunityStore()
    await Promise.all([store.load(), store.load()])
    await store.load()
    expect(getCommunityProfile).toHaveBeenCalledTimes(1)
    expect(store.profile).toEqual(profile)
  })
  it('clears private state immediately when the campus session is cleared', async () => {
    const store = useCommunityStore()
    await store.load()
    clearRatingAccessToken()
    expect(store.profile).toBeNull()
    expect(store.error).toBe('')
  })
  it('ignores a response that arrives after logout', async () => {
    let complete!: (profile: CommunityProfile) => void
    vi.mocked(getCommunityProfile).mockReturnValue(new Promise(resolve => { complete = resolve }))
    const store = useCommunityStore()
    const pending = store.load()
    store.clear()
    complete(profile)
    await pending
    expect(store.profile).toBeNull()
    expect(store.loading).toBe(false)
  })
  it('uses the expected profile version and publishes no academic fields', async () => {
    const store = useCommunityStore()
    await store.load()
    vi.mocked(updateCommunityProfile).mockResolvedValue({ ...profile, display_name: '新昵称', profile_version: 2 })
    await store.save({ display_name: '新昵称', avatar_preset: 3, avatar_asset_id: null })
    expect(updateCommunityProfile).toHaveBeenCalledWith({ display_name: '新昵称', avatar_preset: 3, avatar_asset_id: null, expected_version: 1 })
    expect(store.profile?.display_name).toBe('新昵称')
  })
  it('does not install a late save into the next account', async () => {
    const store = useCommunityStore()
    await store.load()
    let complete!: (value: CommunityProfile) => void
    vi.mocked(updateCommunityProfile).mockReturnValue(new Promise(resolve => { complete = resolve }))
    const saving = store.save({ display_name: '新昵称', avatar_preset: 2, avatar_asset_id: null })
    const assertion = expect(saving).rejects.toThrow('登录状态已变化')
    store.clear()
    complete({ ...profile, profile_version: 2 })
    await assertion
    expect(store.profile).toBeNull()
  })
  it('fails softly on old servers and can recover by explicit refresh', async () => {
    vi.mocked(getCommunityProfile).mockRejectedValueOnce(new RatingsApiError('not found', 404, 40401))
    const store = useCommunityStore()
    await store.load()
    await store.load()
    expect(store.supported).toBe(false)
    expect(getCommunityProfile).toHaveBeenCalledTimes(1)
    await store.load(true)
    expect(store.supported).toBe(true)
  })
})
