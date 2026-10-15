import { Capacitor } from '@capacitor/core'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { ratingsPublicCacheScope } from '@/features/ratings'
import { fetchAnnouncements, parseOnlineAnnouncement, type OnlineAnnouncement } from './api'
import { getAnnouncementViewCount, recordAnnouncementPresentation, ANNOUNCEMENT_AUTO_PRESENTATION_LIMIT } from './model'

export function announcementKey(item: OnlineAnnouncement) { return `${item.id}:${item.revision}` }
export const useAnnouncementsStore = defineStore('announcements', () => {
  const platform = Capacitor.isNativePlatform() ? Capacitor.getPlatform() : 'web'
  const cacheKey = `announcements:v1:${ratingsPublicCacheScope()}:${platform}`
  const feed = ref<OnlineAnnouncement[]>([])
  const views = ref<Record<string, number>>({})
  const loading = ref(false), initialized = ref(false), fresh = ref(false)
  const error = ref('')
  const autoPresented = ref(false)
  const now = ref(Date.now())
  let inFlight: Promise<void> | undefined
  let lastCheck = 0
  const items = computed(() => feed.value.filter(item => (!item.starts_at || Date.parse(item.starts_at) <= now.value) && (!item.expires_at || Date.parse(item.expires_at) > now.value)))
  const latest = computed(() => items.value[0])
  const autoCandidate = computed(() => {
    const item = latest.value
    return initialized.value && !loading.value && fresh.value && !autoPresented.value && item?.auto_show && viewCount(item) < ANNOUNCEMENT_AUTO_PRESENTATION_LIMIT ? item : undefined
  })
  function syncTime() { now.value = Date.now() }
  function viewCount(item: OnlineAnnouncement) {
    const id = announcementKey(item)
    return getAnnouncementViewCount({ id, viewCount: views.value[id] ?? 0 }, id)
  }
  function saveCache() {
    try {
      const entries = Object.entries(views.value).slice(-100)
      views.value = Object.fromEntries(entries)
      localStorage.setItem(cacheKey, JSON.stringify({ items: feed.value, views: views.value }))
    } catch { /* 本机会话仍保留阅读记录，存储受限不会阻止查看。 */ }
  }
  function readCache() {
    try {
      const saved = JSON.parse(localStorage.getItem(cacheKey) || 'null') as { items?: unknown; views?: unknown } | null
      if (!saved || !Array.isArray(saved.items) || saved.items.length > 20) return
      feed.value = saved.items.map(parseOnlineAnnouncement)
      if (saved.views && typeof saved.views === 'object') {
        views.value = Object.fromEntries(Object.entries(saved.views).slice(-100).filter(([, count]) => typeof count === 'number' && Number.isSafeInteger(count) && count >= 0 && count <= 2))
      }
    } catch { /* 缓存损坏不妨碍在线拉取。 */ }
  }
  function refresh(force = false): Promise<void> {
    if (inFlight) return inFlight
    if (!force && Date.now() - lastCheck < 300000) return Promise.resolve()
    inFlight = (async () => {
      loading.value = true
      syncTime()
      error.value = ''
      if (!initialized.value) readCache()
      try { feed.value = await fetchAnnouncements(platform); fresh.value = true; saveCache() }
      catch { fresh.value = false; error.value = '公告更新失败，请检查网络后重试' }
      finally { syncTime(); loading.value = false; initialized.value = true; lastCheck = Date.now() }
    })().finally(() => { inFlight = undefined })
    return inFlight
  }
  function markViewed(item: OnlineAnnouncement) {
    const id = announcementKey(item)
    views.value[id] = recordAnnouncementPresentation({ id, viewCount: viewCount(item) }, id).viewCount
    saveCache()
  }
  return { items, latest, loading, initialized, fresh, error, autoCandidate, autoPresented, viewCount, refresh, markViewed, syncTime }
})
