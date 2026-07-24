<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { useRouter } from 'vue-router'

import calendarIcon from '@/assets/icons/tool-calendar.png'
import classroomIcon from '@/assets/icons/tool-classroom.png'
import examRoomIcon from '@/assets/icons/tool-exam-room.png'
import gradesIcon from '@/assets/icons/tool-grades.png'
import libraryIcon from '@/assets/icons/tool-library.png'
import mapIcon from '@/assets/icons/tool-campus-map.png'
import newStudentIcon from '@/assets/icons/tool-new-student.png'
import pastExamsIcon from '@/assets/icons/tool-past-exams.png'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppShell from '@/shared/ui/AppShell.vue'

defineOptions({ name: 'ToolsPage' })

const router = useRouter()
const query = ref('')
const notice = ref('')
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

onBeforeUnmount(() => {
  window.clearTimeout(noticeTimer)
})

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
