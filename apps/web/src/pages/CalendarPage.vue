<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'

import { academicCalendarURL, academicYearForDate } from '@/features/calendar'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'CalendarPage' })

const router = useRouter()
const today = new Date()
const academicYear = academicYearForDate(today)
const calendarURL = academicCalendarURL(today)
const loading = ref(true)
const loadFailed = ref(false)
const zoomed = ref(false)
const imageKey = ref(0)

usePageTheme('#e9ebee')

function imageLoaded() {
  loading.value = false
  loadFailed.value = false
}

function imageFailed() {
  loading.value = false
  loadFailed.value = true
}

function retry() {
  loading.value = true
  loadFailed.value = false
  imageKey.value += 1
}
</script>

<template>
  <main class="calendar-page page-padding">
    <header class="calendar-topbar">
      <button type="button" class="calendar-icon-button" aria-label="返回工具页" @click="router.push({ name: 'tools' })">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <div>
        <h1>校历</h1>
        <p>{{ academicYear.startYear }}—{{ academicYear.endYear }} 学年</p>
      </div>
      <a
        class="calendar-icon-button"
        :href="calendarURL"
        target="_blank"
        rel="noopener noreferrer"
        aria-label="打开校历原图"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M14 5h5v5M19 5l-8 8M18 13v5a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5" />
        </svg>
      </a>
    </header>

    <section
      class="calendar-viewer"
      :class="{ 'is-zoomed': zoomed }"
      :aria-busy="loading"
      aria-label="学校校历"
    >
      <div v-if="loading" class="calendar-state" aria-live="polite">
        <span class="calendar-spinner" aria-hidden="true" />
        <p>正在读取校历…</p>
      </div>

      <div v-if="loadFailed" class="calendar-state calendar-state--error" role="alert">
        <strong>校历暂未发布或加载失败</strong>
        <p>教务处可能尚未上传本学年校历，请稍后再试。</p>
        <button type="button" @click="retry">重新加载</button>
      </div>

      <div v-show="!loadFailed" class="calendar-image-stage">
        <img
          :key="imageKey"
          :src="calendarURL"
          :alt="`${academicYear.startYear}—${academicYear.endYear} 学年校历`"
          @load="imageLoaded"
          @error="imageFailed"
        />
      </div>
    </section>

    <div class="calendar-toolbar" aria-label="校历查看选项">
      <button type="button" :aria-pressed="zoomed" @click="zoomed = !zoomed">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <circle cx="10.5" cy="10.5" r="5.5" />
          <path d="m15 15 4 4M8 10.5h5M10.5 8v5" />
        </svg>
        <span>{{ zoomed ? '适应屏幕' : '放大查看' }}</span>
      </button>
      <a :href="calendarURL" target="_blank" rel="noopener noreferrer">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M12 4v11m-4-4 4 4 4-4M5 19h14" />
        </svg>
        <span>打开原图</span>
      </a>
    </div>

    <p class="calendar-source">图片来源：成都信息工程大学教务处</p>
  </main>
</template>
