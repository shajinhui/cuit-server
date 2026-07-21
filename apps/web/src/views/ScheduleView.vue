<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import AppShell from '@/layouts/AppShell.vue'

interface CourseBlock {
  name: string
  room: string
  day: number
  start: number
  span: number
  tone: string
  muted?: boolean
}

const selectedDate = ref(new Date())
const scheduleBackground = '#c9d5e7'
const weekdays = ['一', '二', '三', '四', '五', '六', '日']
const timeSlots = [
  ['08:20', '09:05'],
  ['09:00', '09:45'],
  ['10:10', '10:55'],
  ['11:10', '11:55'],
  ['14:00', '14:45'],
  ['14:30', '15:15'],
  ['15:40', '16:25'],
  ['16:40', '17:25'],
  ['18:30', '19:15'],
  ['19:30', '20:15'],
  ['20:30', '21:15'],
]
const courses: CourseBlock[] = [
  { name: '数字电路与逻辑设计B', room: 'H2101', day: 1, start: 3, span: 2, tone: 'coral' },
  { name: '应用密码学', room: 'H1503', day: 2, start: 3, span: 2, tone: 'blue' },
  { name: '数字电路与逻辑设计B', room: 'H2101', day: 3, start: 3, span: 2, tone: 'coral' },
  { name: '应用密码学', room: 'H1503', day: 4, start: 3, span: 2, tone: 'blue' },
  { name: '毛泽东思想和中国特色社会主义理论体系概论', room: 'H2107', day: 3, start: 5, span: 2, tone: 'amber' },
  { name: '科技英语', room: 'H4208', day: 5, start: 1, span: 2, tone: 'mint' },
  { name: '毛泽东思想和中国特色社会主义理论体系概论', room: 'H2107', day: 5, start: 5, span: 2, tone: 'amber' },
  { name: '应用密码学', room: 'H1503', day: 5, start: 3, span: 2, tone: 'blue' },
  { name: '体育4', room: '排球场1', day: 1, start: 7, span: 2, tone: 'lime' },
  { name: '概率论与数理统计C', room: 'H2301', day: 1, start: 1, span: 2, tone: 'muted', muted: true },
  { name: '汇编语言', room: 'H1309', day: 2, start: 1, span: 2, tone: 'muted', muted: true },
  { name: 'Web应用开发技术', room: 'H1503', day: 2, start: 5, span: 2, tone: 'muted', muted: true },
  { name: '形势与政策Ⅳ', room: 'H2204', day: 5, start: 7, span: 2, tone: 'muted', muted: true },
]

let previousThemeColor = ''
let previousHtmlBackground = ''
let previousBodyBackground = ''

onMounted(() => {
  const theme = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
  previousThemeColor = theme?.content ?? ''
  previousHtmlBackground = document.documentElement.style.backgroundColor
  previousBodyBackground = document.body.style.backgroundColor
  theme?.setAttribute('content', scheduleBackground)
  document.documentElement.style.backgroundColor = scheduleBackground
  document.body.style.backgroundColor = scheduleBackground
})

onBeforeUnmount(() => {
  document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')?.setAttribute('content', previousThemeColor || '#fbfcf9')
  document.documentElement.style.backgroundColor = previousHtmlBackground
  document.body.style.backgroundColor = previousBodyBackground
})

const dateTitle = computed(() => {
  const date = selectedDate.value
  return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
})

const weekDates = computed(() => {
  const selected = selectedDate.value
  const currentDay = selected.getDay() || 7
  const monday = new Date(selected)
  monday.setDate(selected.getDate() - currentDay + 1)
  return weekdays.map((label, index) => {
    const date = new Date(monday)
    date.setDate(monday.getDate() + index)
    return { label, date: date.getDate(), active: date.toDateString() === selected.toDateString() }
  })
})

function chooseDay(index: number) {
  const currentDay = selectedDate.value.getDay() || 7
  const date = new Date(selectedDate.value)
  date.setDate(date.getDate() - currentDay + index + 1)
  selectedDate.value = date
}
</script>

<template>
  <AppShell variant="schedule">
    <section class="schedule-page page-padding">
      <header class="schedule-header">
        <div>
          <h1>{{ dateTitle }}</h1>
          <p><strong>第 3 周</strong><span>非本周</span></p>
        </div>
        <div class="schedule-header__actions" aria-label="课表操作">
          <button type="button" aria-label="添加课程">＋</button>
          <button type="button" class="round-action" aria-label="导入课表">
            <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 4v11m-4-4 4 4 4-4M5 19h14" /></svg>
          </button>
          <button type="button" class="share-action" aria-label="分享课表">
            <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 15V3m-4 4 4-4 4 4M7 10H5v10h14V10h-2" /></svg>
          </button>
          <button type="button" class="more-button" aria-label="更多操作">•••</button>
        </div>
      </header>

      <div class="week-strip" aria-label="本周日期">
        <div class="week-strip__month">
          <strong>{{ selectedDate.getMonth() + 1 }}</strong>
          <span>月</span>
        </div>
        <button
          v-for="(item, index) in weekDates"
          :key="`${item.label}-${item.date}`"
          type="button"
          :class="{ 'is-active': item.active }"
          @click="chooseDay(index)"
        >
          <span>{{ item.label }}</span>
          <strong>{{ item.date }}</strong>
        </button>
      </div>

      <div class="schedule-board">
        <div class="schedule-grid" aria-label="示例课表，暂未连接后端">
          <template v-for="(slot, index) in timeSlots" :key="slot[0]">
            <div class="schedule-grid__time" :style="{ gridRow: index + 1 }">
              <strong>{{ index + 1 }}</strong>
              <span>{{ slot[0] }}</span>
              <span>{{ slot[1] }}</span>
            </div>
            <div
              v-for="day in 7"
              :key="`${index}-${day}`"
              class="schedule-grid__cell"
              :style="{ gridColumn: day + 1, gridRow: index + 1 }"
            />
          </template>

          <article
            v-for="course in courses"
            :key="`${course.name}-${course.day}`"
            class="course-block"
            :class="[`course-block--${course.tone}`, { 'is-muted': course.muted }]"
            :style="{
              gridColumn: course.day + 1,
              gridRow: `${course.start} / span ${course.span}`,
            }"
          >
            <strong>{{ course.name }}</strong>
            <span>@{{ course.room }}</span>
          </article>
        </div>
      </div>
    </section>
  </AppShell>
</template>
