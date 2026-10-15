<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { QQ_GROUP_NUMBER, QQ_GROUP_URL } from '@/shared/config/community'
import { APP_ANNOUNCEMENT_OPEN_EVENT } from '../presentation'
import { useAnnouncementsStore } from '../store'
import type { OnlineAnnouncement } from '../api'

defineOptions({ name: 'AppAnnouncement' })
const props = defineProps<{ allowPresentation: boolean }>()
const store = useAnnouncementsStore()
const current = ref<OnlineAnnouncement>()
const visible = ref(false)
const dialog = ref<HTMLElement | null>(null)
const promotion = computed(() => current.value?.action)
let previouslyFocused: HTMLElement | null = null
let timer: ReturnType<typeof setTimeout> | undefined

function checkAuto() {
  clearTimeout(timer)
  if (!props.allowPresentation || !store.autoCandidate || visible.value || document.hidden) return
  timer = setTimeout(() => {
    store.syncTime()
    const item = store.autoCandidate
    if (!item || !props.allowPresentation || visible.value || document.hidden) return
    if (document.querySelector('[role="dialog"], [aria-modal="true"]') || document.activeElement?.matches('input, textarea, [contenteditable="true"]')) {
      checkAuto(); return
    }
    store.autoPresented = true
    current.value = item
    visible.value = true
  }, 400)
}
watch([() => props.allowPresentation, () => store.autoCandidate], checkAuto, { immediate: true })
watch(() => props.allowPresentation, allowed => {
  if (!allowed && visible.value) closeAnnouncement()
})
watch(visible, async shown => {
  if (shown) {
    previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null
    await nextTick()
    dialog.value?.focus()
  } else { previouslyFocused?.focus(); previouslyFocused = null }
})
onMounted(() => {
  void store.refresh()
  document.addEventListener('keydown', handleKeydown)
  document.addEventListener('visibilitychange', foreground)
  window.addEventListener(APP_ANNOUNCEMENT_OPEN_EVENT, openManually)
})
onBeforeUnmount(() => {
  clearTimeout(timer)
  document.removeEventListener('keydown', handleKeydown)
  document.removeEventListener('visibilitychange', foreground)
  window.removeEventListener(APP_ANNOUNCEMENT_OPEN_EVENT, openManually)
})
function foreground() { if (!document.hidden) { void store.refresh(); checkAuto() } else clearTimeout(timer) }
function closeAnnouncement() {
  if (!visible.value) return
  visible.value = false
  if (current.value) store.markViewed(current.value)
}
function openManually() {
  store.syncTime()
  if (visible.value || !store.latest) return
  store.autoPresented = true
  current.value = store.latest
  visible.value = true
}
function selectAnnouncement(item: OnlineAnnouncement) {
  store.syncTime()
  if (!store.items.some(entry => entry.id === item.id)) return
  if (current.value) store.markViewed(current.value)
  current.value = item
}
function handleKeydown(event: KeyboardEvent) { if (event.key === 'Escape' && visible.value) closeAnnouncement() }
</script>

<template>
  <Teleport to="body">
    <Transition name="app-announcement" appear>
      <div v-if="visible && current" class="app-announcement-backdrop" @click.self="closeAnnouncement">
        <section
          ref="dialog"
          class="app-announcement-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="app-announcement-title"
          aria-describedby="app-announcement-description"
          tabindex="-1"
        >
          <span class="app-announcement-dialog__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path d="M4 5.5h11.5v8H9l-3.8 3v-3H4v-8Z" />
              <path d="M10 15.5h5l3.8 3v-3H20v-8h-2" />
            </svg>
          </span>
          <p class="app-announcement-dialog__eyebrow">新消息</p>
          <h2 id="app-announcement-title">{{ current.title }}</h2>
          <p id="app-announcement-description" class="app-announcement-dialog__description">
            {{ current.body }}
          </p>

          <a
            v-if="promotion"
            class="app-announcement-dialog__promotion"
            :href="promotion.url"
            target="_blank"
            rel="noopener noreferrer"
            @click="closeAnnouncement"
          >
            <span class="app-announcement-dialog__promotion-tag">查看详情</span>
            <strong class="app-announcement-dialog__promotion-headline">
              {{ promotion.label }}
            </strong>
            <span class="app-announcement-dialog__promotion-url">
              {{ promotion.url }}
              <span aria-hidden="true">›</span>
            </span>
          </a>

          <p v-if="store.error" role="status">当前为离线缓存，联网后可更新公告。</p>
          <details v-if="store.items.length > 1" class="app-announcement-history">
            <summary>其他公告</summary>
            <button v-for="item in store.items" :key="item.id" type="button" @click="selectAnnouncement(item)">{{ item.title }}</button>
          </details>
          <p class="app-announcement-dialog__group">QQ群 {{ QQ_GROUP_NUMBER }}</p>

          <div class="app-announcement-dialog__actions">
            <button type="button" @click="closeAnnouncement">我知道了</button>
            <a
              v-if="promotion"
              :href="promotion.url"
              target="_blank"
              rel="noopener noreferrer"
              @click="closeAnnouncement"
            >
              {{ promotion.label }}
            </a>
            <a
              v-else
              :href="QQ_GROUP_URL"
              target="_blank"
              rel="noopener noreferrer"
              @click="closeAnnouncement"
            >
              立即入群
            </a>
          </div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
