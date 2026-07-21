<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import type { Grade } from '@/api/grades'
import { useGradesStore } from '@/stores/grades'

const router = useRouter()
const store = useGradesStore()
const showActions = ref(false)
const gradeBackground = '#f6f6f8'
let previousThemeColor = ''
let previousHtmlBackground = ''
let previousBodyBackground = ''

const publishedCount = computed(() => store.grades.filter((grade) => displayScore(grade)).length)
const failedCount = computed(() =>
  store.grades.filter((grade) => {
    const score = Number.parseFloat(displayScore(grade))
    return !Number.isNaN(score) && score < 60
  }).length,
)

onMounted(() => {
  const theme = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
  previousThemeColor = theme?.content ?? ''
  previousHtmlBackground = document.documentElement.style.backgroundColor
  previousBodyBackground = document.body.style.backgroundColor
  theme?.setAttribute('content', gradeBackground)
  document.documentElement.style.backgroundColor = gradeBackground
  document.body.style.backgroundColor = gradeBackground
  void store.initialize()
})

onBeforeUnmount(() => {
  document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')?.setAttribute('content', previousThemeColor || '#fbfcf9')
  document.documentElement.style.backgroundColor = previousHtmlBackground
  document.body.style.backgroundColor = previousBodyBackground
})

watch(
  () => store.authState,
  (state) => {
    if (state === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/grades' } })
    }
  },
)

function displayScore(grade: Grade) {
  return grade.FinalScore || grade.OverallScore || ''
}

function scoreTone(grade: Grade) {
  const score = Number.parseFloat(displayScore(grade))
  return !Number.isNaN(score) && score < 60 ? 'failed' : 'normal'
}

async function logout() {
  showActions.value = false
  await store.logout()
}
</script>

<template>
  <main class="grade-page">
    <section v-if="store.authState !== 'authenticated'" class="grade-loading page-padding" aria-live="polite">
      <div class="loading-spinner" />
      <p>正在读取教务登录状态…</p>
    </section>

    <section v-else class="grade-results page-padding">
      <header class="grade-topbar">
        <button type="button" class="grade-icon-button" aria-label="返回工具页" @click="router.push({ name: 'tools' })">
          <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
        </button>

        <div class="grade-topbar__actions">
          <button
            type="button"
            class="grade-icon-button"
            aria-label="刷新成绩"
            :disabled="store.loading"
            @click="store.loadGrades"
          >
            <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M20 6v5h-5M19 11a7 7 0 1 0 .2 5" /></svg>
          </button>
          <div class="grade-more">
            <button
              type="button"
              class="grade-icon-button"
              aria-label="更多操作"
              :aria-expanded="showActions"
              @click="showActions = !showActions"
            >
              <span aria-hidden="true">•••</span>
            </button>
            <div v-if="showActions" class="grade-action-menu">
              <button type="button" @click="logout">退出教务</button>
            </div>
          </div>
        </div>
      </header>

      <label class="semester-select">
        <span>当前学期</span>
        <select v-model="store.selectedSemesterID" :disabled="store.loading" @change="store.loadGrades">
          <option v-for="semester in store.semesters" :key="semester.ID" :value="semester.ID">
            {{ semester.SchoolYear }}学年 第{{ semester.Term }}学期
          </option>
        </select>
      </label>

      <section class="grade-summary" aria-label="成绩统计">
        <article>
          <span>已出成绩</span>
          <p><strong>{{ publishedCount }}</strong><small>门</small></p>
        </article>
        <article :class="{ 'has-failed': failedCount > 0 }">
          <span>挂科</span>
          <p><strong>{{ failedCount }}</strong><small>门</small></p>
        </article>
      </section>

      <p v-if="store.error" class="result-error" role="alert">{{ store.error }}</p>

      <div class="grade-section-heading">
        <h2>成绩明细</h2>
        <span>{{ store.loading ? '更新中…' : '已更新' }}</span>
      </div>

      <div v-if="store.loading && store.grades.length === 0" class="grade-loading grade-loading--inline" aria-live="polite">
        <div class="loading-spinner" />
        <p>正在读取成绩…</p>
      </div>

      <div v-else-if="store.grades.length" class="grade-list">
        <article
          v-for="grade in store.grades"
          :key="grade.CourseSequence"
          class="grade-row"
          :class="{ 'is-failed': scoreTone(grade) === 'failed' }"
        >
          <div class="grade-row__main">
            <span>{{ grade.CourseCategory || '课程' }} · {{ grade.CourseCode }}</span>
            <h3>{{ grade.CourseName }}</h3>
            <div class="grade-row__details">
              <span>{{ grade.Credits || '—' }} 学分</span>
              <span>平时 {{ grade.UsualScore || '—' }}</span>
              <span>期末 {{ grade.FinalExamScore || '—' }}</span>
              <span>绩点 {{ grade.GradePoint || '—' }}</span>
            </div>
          </div>
          <strong :class="`score--${scoreTone(grade)}`">{{ displayScore(grade) || '—' }}</strong>
        </article>
      </div>

      <div v-else-if="!store.loading" class="empty-grade">
        <span aria-hidden="true">—</span>
        <h2>本学期暂无成绩</h2>
        <p>教务系统发布后会显示在这里。</p>
      </div>
    </section>
  </main>
</template>
