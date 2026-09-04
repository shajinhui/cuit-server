<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { QQ_GROUP_NUMBER, QQ_GROUP_URL } from '@/shared/config/community'

import { ACTIVE_ANNOUNCEMENT, isAnnouncementUnread } from '../model'

defineOptions({ name: 'AppAnnouncement' })

const props = defineProps<{
  allowPresentation: boolean
}>()

const storageKey = 'app-announcement-seen-id'
const visible = ref(false)
const dialog = ref<HTMLElement | null>(null)
let closedForSession = false
let previouslyFocused: HTMLElement | null = null

watch(
  () => props.allowPresentation,
  (allowed) => {
    if (!allowed) {
      visible.value = false
      return
    }
    if (closedForSession || !isAnnouncementUnread(readSeenAnnouncementID(), ACTIVE_ANNOUNCEMENT.id)) {
      return
    }
    visible.value = true
  },
  { immediate: true },
)

watch(visible, async (shown) => {
  if (shown) {
    previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null
    await nextTick()
    dialog.value?.focus()
    return
  }

  previouslyFocused?.focus()
  previouslyFocused = null
})

onMounted(() => document.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', handleKeydown))

function readSeenAnnouncementID(): string | null {
  try {
    return window.localStorage.getItem(storageKey)
  } catch {
    return null
  }
}

function markAsSeen() {
  closedForSession = true
  visible.value = false
  try {
    window.localStorage.setItem(storageKey, ACTIVE_ANNOUNCEMENT.id)
  } catch {
    // 存储受限时至少在当前应用会话中不再重复展示。
  }
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape' && visible.value) markAsSeen()
}
</script>

<template>
  <Teleport to="body">
    <Transition name="app-announcement" appear>
      <div v-if="visible" class="app-announcement-backdrop" @click.self="markAsSeen">
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
          <h2 id="app-announcement-title">{{ ACTIVE_ANNOUNCEMENT.title }}</h2>
          <p id="app-announcement-description" class="app-announcement-dialog__description">
            {{ ACTIVE_ANNOUNCEMENT.description }}
          </p>
          <p class="app-announcement-dialog__group">QQ群 {{ QQ_GROUP_NUMBER }}</p>

          <div class="app-announcement-dialog__actions">
            <button type="button" @click="markAsSeen">我知道了</button>
            <a :href="QQ_GROUP_URL" target="_blank" rel="noopener noreferrer" @click="markAsSeen">
              立即入群
            </a>
          </div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
