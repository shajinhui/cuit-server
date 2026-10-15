import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { fetchAnnouncements, parseOnlineAnnouncement, type OnlineAnnouncement } from './api'
import { useAnnouncementsStore } from './store'

vi.mock('./api', async importOriginal => ({ ...await importOriginal<typeof import('./api')>(), fetchAnnouncements: vi.fn() }))
vi.mock('@/features/ratings', () => ({ ratingsPublicCacheScope: () => 'https://example.invalid', publicRatingsRequest: vi.fn(), ratingsRequest: vi.fn() }))
const message: OnlineAnnouncement = { id: 'offline-test', revision: 1, title: '测试公告', body: '虚构测试正文', auto_show: true, action: null, starts_at: null, expires_at: null }
const saved = new Map<string, string>()
afterEach(() => vi.useRealTimers())
beforeEach(() => {
  saved.clear()
  setActivePinia(createPinia())
  vi.stubGlobal('localStorage', { getItem: (key: string) => saved.get(key) ?? null, setItem: (key: string, value: string) => saved.set(key, value) })
  vi.mocked(fetchAnnouncements).mockReset().mockResolvedValue([message])
})
describe('在线公告状态', () => {
  it('再次获取新列表期间不自动弹出尚未确认有效的旧消息', async () => {
    const store = useAnnouncementsStore()
    await store.refresh()
    let resolve: (items: OnlineAnnouncement[]) => void = () => undefined
    vi.mocked(fetchAnnouncements).mockReturnValue(new Promise(done => { resolve = done }))
    const pending = store.refresh(true)
    expect(store.autoCandidate).toBeUndefined()
    resolve([])
    await pending
    expect(store.latest).toBeUndefined()
  })
  it('手动查看与延迟弹出前重新检查缓存过期时间', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'))
    vi.mocked(fetchAnnouncements).mockResolvedValue([{ ...message, expires_at: '2026-10-14T00:01:00Z' }])
    const store = useAnnouncementsStore()
    await store.refresh()
    expect(store.latest).toBeDefined()
    vi.setSystemTime(new Date('2026-10-14T00:02:00Z'))
    store.syncTime()
    expect(store.latest).toBeUndefined()
    expect(store.autoCandidate).toBeUndefined()
  })
  it('跨启动累计两次，更新内容版本重置提醒，阅读次数不无限增长', async () => {
    for (let i = 0; i < 2; i++) {
      setActivePinia(createPinia())
      const store = useAnnouncementsStore()
      await store.refresh()
      expect(store.autoCandidate?.id).toBe(message.id)
      store.markViewed(message)
    }
    setActivePinia(createPinia())
    const store = useAnnouncementsStore()
    await store.refresh()
    expect(store.autoCandidate).toBeUndefined()
    store.markViewed(message)
    expect(store.viewCount(message)).toBe(2)
    vi.mocked(fetchAnnouncements).mockResolvedValue([{ ...message, revision: 2 }])
    await store.refresh(true)
    expect(store.autoCandidate?.revision).toBe(2)
  })
  it('断网保留手动可读缓存，不自动弹出；空列表清除下架内容', async () => {
    await useAnnouncementsStore().refresh()
    setActivePinia(createPinia())
    vi.mocked(fetchAnnouncements).mockRejectedValue(new Error('offline'))
    const store = useAnnouncementsStore()
    await store.refresh()
    expect(store.latest?.id).toBe(message.id)
    expect(store.error).toBeTruthy()
    expect(store.autoCandidate).toBeUndefined()
    vi.mocked(fetchAnnouncements).mockResolvedValue([])
    await store.refresh(true)
    expect(store.items).toEqual([])
  })
  it('同会话关闭后不再补弹；后台设置为不自动弹出仍可手动查看', async () => {
    const store = useAnnouncementsStore()
    await store.refresh()
    store.autoPresented = true
    expect(store.autoCandidate).toBeUndefined()
    vi.mocked(fetchAnnouncements).mockResolvedValue([{ ...message, auto_show: false }])
    await store.refresh(true)
    store.autoPresented = false
    expect(store.latest).toBeDefined()
    expect(store.autoCandidate).toBeUndefined()
  })
  it('重复刷新合并请求，首次成功后自动刷新节流', async () => {
    const store = useAnnouncementsStore()
    const first = store.refresh()
    await Promise.all([first, store.refresh(true)])
    await store.refresh()
    expect(fetchAnnouncements).toHaveBeenCalledTimes(1)
    await store.refresh(true)
    expect(fetchAnnouncements).toHaveBeenCalledTimes(2)
  })
})
describe('公告响应校验', () => {
  it.each(['http://example.invalid', 'javascript:alert(1)', 'https://user:pass@example.invalid'])('拒绝危险链接 %s', url => {
    expect(() => parseOnlineAnnouncement({ ...message, action: { label: '查看', url } })).toThrow()
  })
  it('拒绝无效版本、缺失正文和无时区日期', () => {
    for (const input of [{ revision: 0 }, { body: '' }, { starts_at: '2026-10-14' }]) expect(() => parseOnlineAnnouncement({ ...message, ...input })).toThrow()
    expect(parseOnlineAnnouncement({ ...message, action: { label: '查看', url: 'https://example.invalid' } }).action?.url).toBe('https://example.invalid')
  })
})
