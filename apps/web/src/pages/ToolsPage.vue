<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import calendarIcon from '@/assets/icons/tool-calendar.png'
import classroomIcon from '@/assets/icons/tool-classroom.png'
import examRoomIcon from '@/assets/icons/tool-exam-room.png'
import gradesIcon from '@/assets/icons/tool-grades.png'
import libraryIcon from '@/assets/icons/tool-library.png'
import mapIcon from '@/assets/icons/tool-campus-map.png'
import newStudentIcon from '@/assets/icons/tool-new-student.png'
import pastExamsIcon from '@/assets/icons/tool-past-exams.png'
import {
  ACTIVE_ANNOUNCEMENT,
  activeAnnouncementHasBeenViewed,
  APP_ANNOUNCEMENT_VIEW_STATE_EVENT,
  openActiveAnnouncement,
} from '@/features/announcements'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppShell from '@/shared/ui/AppShell.vue'

defineOptions({ name: 'ToolsPage' })

const router = useRouter()
const query = ref('')
const notice = ref('')
const announcementViewed = ref(false)
let noticeTimer: number | undefined

interface ToolItem {
  label: string
  icon: string
  route?: string
  comingSoon?: boolean
}

const tools: ToolItem[] = [
  { label: '查空教室', icon: classroomIcon, route: 'classrooms' },
  { label: '查成绩', icon: gradesIcon, route: 'grades' },
  { label: '校历', icon: calendarIcon, route: 'calendar' },
  { label: '考场查询', icon: examRoomIcon, route: 'exams' },
  { label: '校园地图', icon: mapIcon, route: 'campus-map' },
  { label: '历年试卷', icon: pastExamsIcon, comingSoon: true },
  { label: '新生指引', icon: newStudentIcon, comingSoon: true },
  { label: '图书馆', icon: libraryIcon, comingSoon: true },
]

const filteredTools = computed(() => {
  const keyword = query.value.trim()
  return keyword ? tools.filter((tool) => tool.label.includes(keyword)) : tools
})

usePageTheme('#f2f2f7')

onMounted(() => {
  syncAnnouncementViewState()
  window.addEventListener(APP_ANNOUNCEMENT_VIEW_STATE_EVENT, syncAnnouncementViewState)
})

onBeforeUnmount(() => {
  window.clearTimeout(noticeTimer)
  window.removeEventListener(APP_ANNOUNCEMENT_VIEW_STATE_EVENT, syncAnnouncementViewState)
})

function syncAnnouncementViewState(event?: Event) {
  announcementViewed.value =
    (event instanceof CustomEvent && event.detail?.viewed === true) ||
    activeAnnouncementHasBeenViewed()
}

function openTool(tool: ToolItem) {
  if (tool.comingSoon) return
  if (tool.route) {
    void router.push({ name: tool.route })
    return
  }
  notice.value = `${tool.label}暂未接入`
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 1800)
}
</script>

<template>
  <AppShell variant="tools">
    <section class="tools-page page-padding">
      <button
        type="button"
        class="tools-announcement-card"
        :class="{ 'is-viewed': announcementViewed }"
        aria-label="查看最新公告"
        @click="openActiveAnnouncement"
      >
        <span class="tools-announcement-card__icon" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <path d="M4 5.5h11.5v8H9l-3.8 3v-3H4v-8Z" />
            <path d="M10 15.5h5l3.8 3v-3H20v-8h-2" />
          </svg>
        </span>
        <span class="tools-announcement-card__copy">
          <small v-if="!announcementViewed">最新公告</small>
          <strong>{{ ACTIVE_ANNOUNCEMENT.title }}</strong>
          <span v-if="!announcementViewed">{{ ACTIVE_ANNOUNCEMENT.description }}</span>
        </span>
        <span class="tools-announcement-card__chevron" aria-hidden="true">›</span>
      </button>

      <label class="tool-search">
        <span aria-hidden="true" />
        <input v-model="query" type="search" placeholder="搜索校园服务" aria-label="搜索校园服务" />
      </label>

      <div class="tools-grid">
        <button
          v-for="tool in filteredTools"
          :key="tool.label"
          type="button"
          :disabled="tool.comingSoon"
          :class="{ 'is-coming-soon': tool.comingSoon }"
          @click="openTool(tool)"
        >
          <img :src="tool.icon" alt="" />
          <span class="tool-copy">
            <span class="tool-label">{{ tool.label }}</span>
            <small v-if="tool.comingSoon">敬请期待</small>
          </span>
        </button>
      </div>
      <p v-if="filteredTools.length === 0" class="empty-message">没有找到相关工具</p>

      <Transition name="toast">
        <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
      </Transition>
    </section>
  </AppShell>
</template>
