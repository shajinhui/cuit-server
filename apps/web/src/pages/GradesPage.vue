<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  countFailedGrades,
  countPublishedGrades,
  displayGradeScore,
  gradeScoreTone,
  useGradesStore,
} from '@/features/grades'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppSelect from '@/shared/ui/AppSelect.vue'

defineOptions({ name: 'GradesPage' })

const router = useRouter()
const store = useGradesStore()

usePageTheme('#f6f6f8')

const publishedCount = computed(() => countPublishedGrades(store.grades))
const failedCount = computed(() => countFailedGrades(store.grades))
const semesterOptions = computed(() =>
  store.semesters.map((semester) => ({
    value: semester.ID,
    label: `${semester.SchoolYear}学年 第${semester.Term}学期`,
  })),
)
const updateStatus = computed(() => {
  if (store.loading) return '更新中…'
  if (store.error) return '更新失败'
  return '已更新'
})

onMounted(() => {
  void store.initialize()
})

watch(
  () => store.authState,
  (state) => {
    if (state === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/grades' } })
    }
  },
)

function chooseSemester(value: string | number) {
  store.selectedSemesterID = String(value)
  void store.loadGrades()
}

</script>

<template>
  <main class="grade-page">
    <section
      v-if="store.authState === 'checking' || store.authState === 'anonymous'"
      class="grade-loading page-padding"
      aria-live="polite"
    >
      <div class="loading-spinner" />
      <p>正在加载成绩…</p>
    </section>

    <section v-else-if="store.authState === 'unavailable'" class="grade-loading grade-unavailable page-padding" role="status">
      <strong>成绩暂时无法读取</strong>
      <p>{{ store.error }}</p>
      <button type="button" @click="router.push({ name: 'schedule' })">查看离线课表</button>
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
        </div>
      </header>

      <div class="semester-select">
        <span>当前学期</span>
        <AppSelect
          :model-value="store.selectedSemesterID"
          :options="semesterOptions"
          title="选择成绩学期"
          aria-label="选择成绩学期"
          :disabled="store.loading"
          @change="chooseSemester"
        />
      </div>

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
        <span>{{ updateStatus }}</span>
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
          :class="{ 'is-failed': gradeScoreTone(grade) === 'failed' }"
        >
          <div class="grade-row__main">
            <span>{{ grade.CourseCategory || '课程' }} · {{ grade.CourseCode }}</span>
            <h3>{{ grade.CourseName }}</h3>
            <div class="grade-row__details">
              <span>{{ grade.Credits || '—' }} 学分</span>
              <span>平时 {{ grade.UsualScore || '—' }}</span>
              <span>期末 {{ grade.FinalExamScore || '—' }}</span>
              <span v-if="grade.MakeupScore">补考 {{ grade.MakeupScore }}</span>
              <span>绩点 {{ grade.GradePoint || '—' }}</span>
            </div>
          </div>
          <strong :class="`score--${gradeScoreTone(grade)}`">{{ displayGradeScore(grade) || '—' }}</strong>
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
