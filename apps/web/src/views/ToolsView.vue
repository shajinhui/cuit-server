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
import AppShell from '@/layouts/AppShell.vue'

const router = useRouter()
const query = ref('')
const notice = ref('')
const toolsBackground = '#e9ebee'
let noticeTimer: number | undefined
let previousThemeColor = ''
let previousHtmlBackground = ''
let previousBodyBackground = ''

const tools = [
  { label: '查空教室', icon: classroomIcon },
  { label: '历年试卷', icon: pastExamsIcon },
  { label: '查成绩', icon: gradesIcon, route: 'grades' },
  { label: '校历', icon: calendarIcon },
  { label: '考场查询', icon: examRoomIcon },
  { label: '新生指引', icon: newStudentIcon },
  { label: '校园地图', icon: mapIcon },
  { label: '图书馆', icon: libraryIcon },
]

const filteredTools = computed(() => {
  const keyword = query.value.trim()
  return keyword ? tools.filter((tool) => tool.label.includes(keyword)) : tools
})

onMounted(() => {
  const theme = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
  previousThemeColor = theme?.content ?? ''
  previousHtmlBackground = document.documentElement.style.backgroundColor
  previousBodyBackground = document.body.style.backgroundColor
  theme?.setAttribute('content', toolsBackground)
  document.documentElement.style.backgroundColor = toolsBackground
  document.body.style.backgroundColor = toolsBackground
})

onBeforeUnmount(() => {
  document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')?.setAttribute('content', previousThemeColor || '#fbfcf9')
  document.documentElement.style.backgroundColor = previousHtmlBackground
  document.body.style.backgroundColor = previousBodyBackground
})

function openTool(tool: (typeof tools)[number]) {
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
        <button v-for="tool in filteredTools" :key="tool.label" type="button" @click="openTool(tool)">
          <img :src="tool.icon" alt="" />
          <span>{{ tool.label }}</span>
        </button>
      </div>
      <p v-if="filteredTools.length === 0" class="empty-message">没有找到相关工具</p>

      <Transition name="toast">
        <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
      </Transition>
    </section>
  </AppShell>
</template>
