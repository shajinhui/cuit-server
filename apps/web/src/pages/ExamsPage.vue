<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  examCourseName,
  examLocation,
  examsOnDate,
  formatExamDate,
  groupExamsByDate,
  isExamStatusDanger,
  splitExamTime,
  useExamsStore,
} from '@/features/exams'
import { useSessionStore } from '@/features/session'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppSelect from '@/shared/ui/AppSelect.vue'

defineOptions({ name: 'ExamsPage' })

const router = useRouter()
const store = useExamsStore()
const session = useSessionStore()

usePageTheme('#f2f2f7')

const selectedSemester = computed(() =>
  store.semesters.find((semester) => semester.ID === store.selectedSemesterID),
)
const selectedBatch = computed(() =>
  store.batches.find((batch) => batch.ID === store.selectedBatchID),
)
const semesterOptions = computed(() =>
  store.semesters.map((semester) => ({
    value: semester.ID,
    label: `${semester.SchoolYear} · 第${semester.Term}学期`,
  })),
)
const displayGroups = computed(() =>
  groupExamsByDate(store.exams).map((group) => ({
    ...group,
    exams: group.exams.map((exam) => ({ exam, time: splitExamTime(exam.ExamTime) })),
  })),
)
const today = new Date()
const todayDateLabel = formatExamDate(
  [
    today.getFullYear(),
    String(today.getMonth() + 1).padStart(2, '0'),
    String(today.getDate()).padStart(2, '0'),
  ].join('-'),
)
const todayExams = computed(() =>
  examsOnDate(store.exams, today).map((exam) => ({
    exam,
    time: splitExamTime(exam.ExamTime),
  })),
)
const pendingCount = computed(
  () => displayGroups.value.find((group) => group.pending)?.exams.length ?? 0,
)
const resultSummary = computed(() => {
  const count = store.exams.length
  if (!count) return ''
  const pending = pendingCount.value
  return pending ? `共 ${count} 门 · ${pending} 门待安排` : `共 ${count} 门`
})

onMounted(() => {
  void store.initialize()
})

watch(
  () => session.status,
  (status) => {
    if (status === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/exams' } })
    }
  },
)

function chooseSemester(value: string | number) {
  void store.changeSemester(String(value))
}

function chooseBatch(batchID: 'final' | 'makeup') {
  void store.changeBatch(batchID)
}

function creditLabel(credits: string) {
  const value = credits.trim()
  return value ? `${value} 学分` : ''
}
</script>

<template>
  <main class="exam-page">
    <header class="exam-topbar">
      <button
        type="button"
        class="exam-icon-button"
        aria-label="返回工具页"
        @click="router.push({ name: 'tools' })"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <h1>考场安排</h1>
      <button
        type="button"
        class="exam-icon-button"
        aria-label="刷新考场安排"
        :disabled="store.initializing || store.loadingExams"
        @click="store.refresh"
      >
        <svg
          aria-hidden="true"
          viewBox="0 0 24 24"
          :class="{ 'is-spinning': store.loadingExams }"
        >
          <path d="M19 8a7.5 7.5 0 1 0 .15 7.7" />
          <path d="M19 4v4h-4" />
        </svg>
      </button>
    </header>

    <section class="exam-content">
      <div v-if="store.initializing && !store.initialized" class="exam-page-state" aria-live="polite">
        <span class="exam-spinner" aria-hidden="true" />
        <p>正在读取考试安排…</p>
      </div>

      <div
        v-else-if="store.initializationError && !store.initialized"
        class="exam-page-state exam-page-state--error"
        role="alert"
      >
        <span class="exam-state-icon" aria-hidden="true">!</span>
        <h2>暂时无法读取考试安排</h2>
        <p>{{ store.initializationError }}</p>
        <button type="button" @click="store.initialize(true)">重新读取</button>
      </div>

      <div v-else-if="store.semesters.length === 0" class="exam-page-state">
        <span class="exam-empty-mark" aria-hidden="true">—</span>
        <h2>暂无可用学期</h2>
        <p>教务系统返回学期后，即可查看对应的考试批次。</p>
      </div>

      <template v-else>
        <section class="exam-filter-card" aria-label="考试筛选条件">
          <label class="exam-semester-field">
            <span>学期</span>
            <AppSelect
              class="exam-select-control"
              :model-value="store.selectedSemesterID"
              :options="semesterOptions"
              title="选择考试学期"
              aria-label="选择考试学期"
              :disabled="store.loadingExams"
              @change="chooseSemester"
            />
          </label>

          <fieldset class="exam-batch-picker">
            <legend>
              <span>考试批次</span>
              <small v-if="store.batches.length">{{ store.batches.length }} 个批次</small>
            </legend>

            <div class="exam-batch-options">
              <button
                v-for="batch in store.batches"
                :key="batch.ID"
                type="button"
                :class="{ 'is-selected': batch.ID === store.selectedBatchID }"
                :aria-pressed="batch.ID === store.selectedBatchID"
                :disabled="store.loadingExams"
                @click="chooseBatch(batch.ID)"
              >
                {{ batch.Name }}
              </button>
            </div>
          </fieldset>
        </section>

        <section
          v-if="store.selectedBatchID && store.hasLoadedExams"
          class="exam-today-card"
          aria-labelledby="exam-today-title"
        >
          <header>
            <div>
              <span>{{ todayDateLabel }}</span>
              <h2 id="exam-today-title">今日考试</h2>
            </div>
            <strong>{{ todayExams.length ? `${todayExams.length} 门` : '无安排' }}</strong>
          </header>

          <div v-if="todayExams.length" class="exam-today-list">
            <article
              v-for="{ exam, time } in todayExams"
              :key="`today-${exam.CourseSequence}-${exam.ExamTime}-${exam.Location}`"
            >
              <div class="exam-today-time">
                <strong>{{ time.start }}</strong>
                <span v-if="time.end">至 {{ time.end }}</span>
              </div>
              <div>
                <h3>{{ examCourseName(exam) }}</h3>
                <p>
                  <svg aria-hidden="true" viewBox="0 0 16 16">
                    <path d="M8 14s4-3.8 4-7.4a4 4 0 1 0-8 0C4 10.2 8 14 8 14Z" />
                    <circle cx="8" cy="6.5" r="1.35" />
                  </svg>
                  <span>{{ examLocation(exam) }}</span>
                </p>
              </div>
            </article>
          </div>

          <div v-else class="exam-today-empty">
            <span aria-hidden="true">✓</span>
            <div>
              <strong>今天没有考试</strong>
              <p>当前批次今天没有考试安排。</p>
            </div>
          </div>
        </section>

        <section v-if="store.selectedBatchID" class="exam-results" aria-labelledby="exam-results-title">
          <header class="exam-results-heading">
            <div>
              <h2 id="exam-results-title">考试安排</h2>
              <p>
                {{ selectedSemester?.SchoolYear }}学年 第{{ selectedSemester?.Term }}学期
                <template v-if="selectedBatch">· {{ selectedBatch.Name }}</template>
              </p>
            </div>
            <span v-if="store.loadingExams && store.exams.length" role="status">更新中…</span>
            <span v-else-if="resultSummary">{{ resultSummary }}</span>
          </header>

          <p v-if="store.examError && store.exams.length" class="exam-refresh-error" role="alert">
            {{ store.examError }}
            <button type="button" @click="store.loadExams">重试</button>
          </p>

          <div
            v-if="store.loadingExams && !store.hasLoadedExams && store.exams.length === 0"
            class="exam-skeleton-list"
            aria-hidden="true"
          >
            <div v-for="index in 3" :key="index">
              <span />
              <div><span /><span /></div>
            </div>
          </div>

          <div
            v-else-if="store.examError && store.exams.length === 0"
            class="exam-result-state exam-result-state--error"
            role="alert"
          >
            <span class="exam-state-icon" aria-hidden="true">!</span>
            <h3>考场安排没有读取成功</h3>
            <p>{{ store.examError }}</p>
            <button type="button" @click="store.loadExams">重新读取</button>
          </div>

          <div
            v-else-if="store.hasLoadedExams && store.exams.length === 0"
            class="exam-result-state"
          >
            <span class="exam-empty-mark" aria-hidden="true">—</span>
            <h3>这个批次暂无考试安排</h3>
            <p>可能尚未发布，也可能当前没有需要参加的考试。</p>
          </div>

          <div v-else-if="displayGroups.length" class="exam-groups" aria-live="polite">
            <section
              v-for="group in displayGroups"
              :key="group.key"
              class="exam-group"
              :class="{ 'exam-group--pending': group.pending }"
            >
              <header>
                <h3>{{ group.label }}</h3>
                <span>{{ group.exams.length }} 门</span>
              </header>
              <div class="exam-list">
                <article v-for="{ exam, time } in group.exams" :key="`${exam.CourseSequence}-${exam.ExamTime}-${exam.Location}`" class="exam-row">
                  <div class="exam-time" :class="{ 'exam-time--pending': group.pending }">
                    <strong>{{ time.start }}</strong>
                    <span v-if="time.end">至 {{ time.end }}</span>
                  </div>
                  <div class="exam-details">
                    <h4>{{ examCourseName(exam) }}</h4>
                    <p class="exam-location">
                      <svg aria-hidden="true" viewBox="0 0 16 16">
                        <path d="M8 14s4-3.8 4-7.4a4 4 0 1 0-8 0C4 10.2 8 14 8 14Z" />
                        <circle cx="8" cy="6.5" r="1.35" />
                      </svg>
                      <span>{{ examLocation(exam) }}</span>
                    </p>
                    <div class="exam-meta">
                      <span v-if="exam.ExamType.trim()">{{ exam.ExamType }}</span>
                      <span v-if="creditLabel(exam.Credits)">{{ creditLabel(exam.Credits) }}</span>
                      <span
                        v-if="exam.Status.trim()"
                        :class="{ 'is-danger': isExamStatusDanger(exam.Status) }"
                      >
                        {{ exam.Status }}
                      </span>
                    </div>
                    <p v-if="exam.Remark.trim()" class="exam-remark">
                      <span>备注</span>{{ exam.Remark }}
                    </p>
                  </div>
                </article>
              </div>
            </section>
          </div>
        </section>
      </template>
    </section>
  </main>
</template>
