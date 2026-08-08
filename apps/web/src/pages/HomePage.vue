<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import profileIcon from '@/assets/icons/nav-profile.png'
import {
  courseCountdownLabel,
  courseStartTimeLabel,
  courseStatus,
  courseTimeLabel,
  formatHomeDate,
  greetingForHour,
} from '@/features/home/model'
import { useProfileStore } from '@/features/profile'
import { useScheduleStore } from '@/features/schedule'
import { buildCourseBlocks } from '@/features/schedule/model/calendar'
import { useSessionStore } from '@/features/session'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppShell from '@/shared/ui/AppShell.vue'

defineOptions({ name: 'HomePage' })

const router = useRouter()
const schedule = useScheduleStore()
const profile = useProfileStore()
const session = useSessionStore()
const now = ref(new Date())
const feedFilter = ref<'campus' | 'qa' | 'latest'>('campus')
const likedPostIDs = ref<number[]>([])
const savedPostIDs = ref<number[]>([])
const notice = ref('')
let clockTimer: number | undefined
let noticeTimer: number | undefined

const weekday = computed(() => now.value.getDay() || 7)
const dateLabel = computed(() => formatHomeDate(now.value))
const greeting = computed(() => greetingForHour(now.value.getHours()))
const avatarSrc = computed(() => profile.avatar?.src || profileIcon)
const weekLabel = computed(() => schedule.currentWeek > 0 ? `第 ${schedule.currentWeek} 周` : '本学期')
const allCourses = computed(() =>
  buildCourseBlocks(
    schedule.table?.Courses,
    schedule.currentWeek || 1,
    schedule.manualCourses.filter((course) => course.semesterID === schedule.selectedSemesterID),
    schedule.courseOverrides.filter((course) => course.semesterID === schedule.selectedSemesterID),
    schedule.courseColorPreferences.filter(
      (preference) => preference.semesterID === schedule.selectedSemesterID,
    ),
  ),
)
const todayCourses = computed(() =>
  allCourses.value
    .filter((course) => course.day === weekday.value && !course.muted)
    .sort((left, right) => left.start - right.start),
)
const activeCourses = computed(() =>
  todayCourses.value.filter((course) => courseStatus(course, now.value) !== 'past'),
)
const featuredCourse = computed(() =>
  activeCourses.value.find((course) => courseStatus(course, now.value) === 'ongoing') ??
  activeCourses.value[0] ??
  null,
)
const emptyCourseTitle = computed(() => {
  if (schedule.loading && !schedule.table) return '正在整理今天的安排'
  if (todayCourses.value.length === 0) return '今天没有课程安排'
  return '今天的课程已全部结束'
})
const syncLabel = computed(() => {
  if (session.status === 'offline' || schedule.usingCachedData) return '离线课表'
  if (schedule.syncError) return '使用上次课表'
  return '教务课表已同步'
})
const featuredMeta = computed(() => {
  const course = featuredCourse.value
  if (!course) return ''
  const teachers = course.teachers.join('、')
  return [course.room, teachers].filter(Boolean).join(' · ')
})

const shortcuts = [
  { label: '空教室', icon: 'door', tone: 'blue', route: 'classrooms' },
  { label: '查成绩', icon: 'chart', tone: 'green', route: 'grades' },
  { label: '查考场', icon: 'exam', tone: 'amber', route: 'exams' },
  { label: '全部', icon: 'grid', tone: 'blue', route: 'tools' },
] as const

const feedTabs = [
  { value: 'campus', label: '校园' },
  { value: 'qa', label: '问答' },
  { value: 'latest', label: '最新' },
] as const

const samplePosts = [
  {
    id: 1,
    kind: 'qa',
    author: '晴川',
    avatar: '晴',
    avatarTone: 'orange',
    meta: '软件工程 · 12 分钟前',
    tag: '校园求助',
    content: '有同学捡到一张校园卡吗？大概落在一食堂二楼，卡套是蓝色的。',
    comments: 8,
    likes: 16,
  },
  {
    id: 2,
    kind: 'campus',
    author: '山风',
    avatar: '山',
    avatarTone: 'green',
    meta: '计算机学院 · 35 分钟前',
    tag: '校园生活',
    content: '今天的晚霞很好看，分享给还在教学楼自习的同学。',
    comments: 3,
    likes: 24,
  },
  {
    id: 3,
    kind: 'qa',
    author: '小满',
    avatar: '满',
    avatarTone: 'blue',
    meta: '自动化学院 · 1 小时前',
    tag: '学习问答',
    content: '想找一起准备期末复习的同学，主要复习高数和大学物理。',
    comments: 11,
    likes: 9,
  },
] as const

const visiblePosts = computed(() => {
  if (feedFilter.value === 'qa') return samplePosts.filter((post) => post.kind === 'qa')
  if (feedFilter.value === 'latest') return [...samplePosts].reverse()
  return samplePosts
})

usePageTheme('#edf3f6')

onMounted(() => {
  clockTimer = window.setInterval(() => (now.value = new Date()), 60_000)
  void loadHome()
})

onBeforeUnmount(() => {
  window.clearInterval(clockTimer)
  window.clearTimeout(noticeTimer)
})

watch(
  () => session.status,
  (status) => {
    if (status === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/home' } })
    }
  },
)

async function loadHome() {
  await Promise.all([schedule.load(), profile.load(), profile.loadAvatar()])
}

function toggleLike(postID: number) {
  likedPostIDs.value = toggleID(likedPostIDs.value, postID)
}

function toggleSave(postID: number) {
  savedPostIDs.value = toggleID(savedPostIDs.value, postID)
}

function toggleID(ids: number[], target: number) {
  return ids.includes(target) ? ids.filter((id) => id !== target) : [...ids, target]
}

function showNotice(message: string) {
  notice.value = message
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 1800)
}
</script>

<template>
  <AppShell variant="home">
    <section class="home-page page-padding">
      <header class="home-header">
        <div class="home-header__copy">
          <p>{{ dateLabel }} · {{ weekLabel }}</p>
          <h1>{{ greeting }}</h1>
        </div>
        <button
          type="button"
          class="home-avatar"
          aria-label="打开个人中心"
          @click="router.push({ name: 'profile' })"
        >
          <img :src="avatarSrc" alt="" />
        </button>
      </header>

      <button
        type="button"
        class="home-focus-card"
        :class="{ 'has-course': featuredCourse }"
        @click="router.push({ name: 'schedule' })"
      >
        <span class="home-focus-card__orb" aria-hidden="true" />
        <template v-if="featuredCourse">
          <span class="home-focus-card__topline">
            <span>
              {{ courseStatus(featuredCourse, now) === 'ongoing' ? '正在上课' : '下一节' }}
              · {{ courseStartTimeLabel(featuredCourse) }}
            </span>
            <span class="home-focus-card__countdown">
              {{ courseCountdownLabel(featuredCourse, now) }}
            </span>
          </span>
          <strong>{{ featuredCourse.name }}</strong>
          <small>{{ featuredMeta || courseTimeLabel(featuredCourse) }}</small>
        </template>
        <template v-else>
          <span class="home-focus-card__topline">
            <span>今日安排</span>
            <span class="home-focus-card__countdown">{{ syncLabel }}</span>
          </span>
          <strong>{{ emptyCourseTitle }}</strong>
          <small>轻点查看完整课表</small>
        </template>
      </button>

      <section class="home-section" aria-labelledby="home-shortcuts-title">
        <div class="home-section__heading">
          <h2 id="home-shortcuts-title">常用服务</h2>
          <button type="button" @click="router.push({ name: 'tools' })">全部</button>
        </div>
        <div class="home-shortcuts">
          <button
            v-for="shortcut in shortcuts"
            :key="shortcut.route"
            type="button"
            @click="router.push({ name: shortcut.route })"
          >
            <span class="home-shortcut-icon" :class="`home-shortcut-icon--${shortcut.tone}`">
              <svg v-if="shortcut.icon === 'door'" aria-hidden="true" viewBox="0 0 24 24">
                <path d="M5 20h14M7 20V5.5L16 3v17M16 6h2v14M12.5 12h.01" />
              </svg>
              <svg v-else-if="shortcut.icon === 'chart'" aria-hidden="true" viewBox="0 0 24 24">
                <path d="M5 19V9M12 19V5M19 19v-7M3 19h18" />
              </svg>
              <svg v-else-if="shortcut.icon === 'exam'" aria-hidden="true" viewBox="0 0 24 24">
                <path d="M7 3v3M17 3v3M4 9h16M5 5h14a1 1 0 0 1 1 1v14H4V6a1 1 0 0 1 1-1ZM8 14l2 2 4-4" />
              </svg>
              <svg v-else aria-hidden="true" viewBox="0 0 24 24">
                <rect x="4" y="4" width="6" height="6" rx="1" />
                <rect x="14" y="4" width="6" height="6" rx="1" />
                <rect x="4" y="14" width="6" height="6" rx="1" />
                <rect x="14" y="14" width="6" height="6" rx="1" />
              </svg>
            </span>
            {{ shortcut.label }}
          </button>
        </div>
      </section>

      <section class="home-feed" aria-labelledby="home-feed-title">
        <header class="home-feed__header">
          <div class="home-feed__tabs" role="tablist" aria-label="校园信息流筛选">
            <button
              v-for="tab in feedTabs"
              :key="tab.value"
              type="button"
              role="tab"
              :aria-selected="feedFilter === tab.value"
              :class="{ 'is-active': feedFilter === tab.value }"
              @click="feedFilter = tab.value"
            >
              {{ tab.label }}
            </button>
          </div>
          <button type="button" class="home-feed__publish" @click="showNotice('发布功能正在准备中')">
            发布
          </button>
        </header>
        <h2 id="home-feed-title" class="home-feed__title">校园信息流</h2>

        <TransitionGroup name="feed-post" tag="div" class="home-feed__list">
          <article v-for="post in visiblePosts" :key="post.id" class="home-feed-card">
            <header class="home-feed-card__author">
              <span class="home-feed-card__avatar" :class="`is-${post.avatarTone}`" aria-hidden="true">
                {{ post.avatar }}
              </span>
              <span class="home-feed-card__identity">
                <strong>{{ post.author }}</strong>
                <small>{{ post.meta }}</small>
              </span>
              <span class="home-feed-card__tag"># {{ post.tag }}</span>
            </header>
            <p>{{ post.content }}</p>
            <footer class="home-feed-card__actions">
              <button type="button" :aria-label="`${post.comments} 条回复`" @click="showNotice('回复功能正在准备中')">
                <svg aria-hidden="true" viewBox="0 0 24 24">
                  <path d="M20 11.5a8 8 0 0 1-8.4 8A9 9 0 0 1 7 18.1L3 20l1.5-4A8 8 0 1 1 20 11.5Z" />
                </svg>
                {{ post.comments }}
              </button>
              <button
                type="button"
                :class="{ 'is-active': likedPostIDs.includes(post.id) }"
                :aria-label="likedPostIDs.includes(post.id) ? '取消点赞' : '点赞'"
                :aria-pressed="likedPostIDs.includes(post.id)"
                @click="toggleLike(post.id)"
              >
                <svg aria-hidden="true" viewBox="0 0 24 24">
                  <path d="M20.8 4.7a5.5 5.5 0 0 0-7.8 0L12 5.8l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.5a5.5 5.5 0 0 0 0-7.8Z" />
                </svg>
                {{ post.likes + (likedPostIDs.includes(post.id) ? 1 : 0) }}
              </button>
              <button
                type="button"
                :class="{ 'is-active': savedPostIDs.includes(post.id) }"
                :aria-label="savedPostIDs.includes(post.id) ? '取消收藏' : '收藏'"
                :aria-pressed="savedPostIDs.includes(post.id)"
                @click="toggleSave(post.id)"
              >
                <svg aria-hidden="true" viewBox="0 0 24 24">
                  <path d="M6 3.5h12v17L12 17l-6 3.5v-17Z" />
                </svg>
                {{ savedPostIDs.includes(post.id) ? '已收藏' : '收藏' }}
              </button>
            </footer>
          </article>
        </TransitionGroup>
      </section>
    </section>

    <Transition name="toast">
      <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
    </Transition>
  </AppShell>
</template>
