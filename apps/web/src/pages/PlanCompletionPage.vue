<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  completionStatusTone,
  creditProgress,
  groupPlanCompletionItems,
  type PlanCompletionItem,
  usePlanCompletionStore,
} from '@/features/plan-completion'
import { useSessionStore } from '@/features/session'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'PlanCompletionPage' })

const router = useRouter()
const store = usePlanCompletionStore()
const session = useSessionStore()

usePageTheme('#f2f2f7')

const summary = computed(() => store.data?.Summary)
const groups = computed(() => groupPlanCompletionItems(store.data?.Items ?? []))
const progress = computed(() => {
  const value = summary.value
  return value ? creditProgress(value.RequiredCredits, value.EarnedCredits) : null
})
const progressLabel = computed(() => (progress.value === null ? '—' : `${Math.round(progress.value)}%`))

onMounted(() => {
  void store.load()
})

watch(
  () => session.status,
  (status) => {
    if (status === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/plan-completion' } })
    }
  },
)

function courseMeta(item: PlanCompletionItem) {
  return [
    item.CourseCode,
    item.EarnedCredits ? `实修 ${item.EarnedCredits} 学分` : '',
    item.RequiredCredits ? `要求 ${item.RequiredCredits} 学分` : '',
  ]
    .filter(Boolean)
    .join(' · ')
}
</script>

<template>
  <main class="completion-page">
    <header class="completion-topbar">
      <button
        type="button"
        class="completion-icon-button"
        aria-label="返回我的页面"
        @click="router.push({ name: 'profile' })"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <h1>学业完成情况</h1>
      <button
        type="button"
        class="completion-icon-button"
        aria-label="刷新学业完成情况"
        :disabled="store.loading"
        @click="store.load(true)"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M20 6v5h-5M19 11a7 7 0 1 0 .2 5" /></svg>
      </button>
    </header>

    <section class="completion-content">
      <div v-if="store.loading && !store.data" class="completion-state" aria-live="polite">
        <span class="completion-spinner" aria-hidden="true" />
        <p>正在读取培养方案…</p>
      </div>

      <div v-else-if="store.error && !store.data" class="completion-state completion-state--error" role="alert">
        <span class="completion-state__icon" aria-hidden="true">!</span>
        <h2>学业完成情况暂时无法读取</h2>
        <p>{{ store.error }}</p>
        <button type="button" @click="store.load(true)">重新读取</button>
      </div>

      <template v-else-if="store.data && summary">
        <p v-if="store.error" class="completion-error" role="alert">
          {{ store.error }}
        </p>

        <section class="completion-summary-card" aria-label="学业完成概览">
          <div class="completion-summary-card__headline">
            <div>
              <span>总体学分</span>
              <p>
                已修 <strong>{{ summary.EarnedCredits || '—' }}</strong>
                <small>/ {{ summary.RequiredCredits || '—' }}</small>
              </p>
            </div>
            <strong>{{ progressLabel }}</strong>
          </div>

          <div
            class="completion-progress"
            role="progressbar"
            aria-label="总体学分完成度"
            aria-valuemin="0"
            aria-valuemax="100"
            :aria-valuenow="progress === null ? undefined : Math.round(progress)"
          >
            <span :style="{ width: `${progress ?? 0}%` }" />
          </div>

          <div class="completion-summary-card__metrics">
            <article>
              <span>平均绩点</span>
              <strong>{{ summary.GPA || '—' }}</strong>
            </article>
            <article>
              <span>审核结果</span>
              <strong :class="`status-text--${completionStatusTone(summary.AuditResult)}`">
                {{ summary.AuditResult || '暂未审核' }}
              </strong>
            </article>
          </div>

          <p v-if="summary.Remark" class="completion-summary-card__remark">{{ summary.Remark }}</p>
        </section>

        <div class="completion-section-heading">
          <h2>培养方案明细</h2>
          <span>{{ store.loading ? '更新中…' : `${groups.length} 个分类` }}</span>
        </div>

        <div v-if="groups.length" class="completion-groups">
          <section
            v-for="(group, groupIndex) in groups"
            :key="`${group.requirement?.Name || 'uncategorized'}-${groupIndex}`"
            class="completion-group"
          >
            <header class="completion-group__header">
              <div>
                <h2>{{ group.requirement?.Name || '其他课程' }}</h2>
                <p v-if="group.requirement">
                  实修 {{ group.requirement.EarnedCredits || '—' }} /
                  要求 {{ group.requirement.RequiredCredits || '—' }} 学分
                </p>
              </div>
              <span
                v-if="group.requirement?.Status"
                :class="`completion-status completion-status--${completionStatusTone(group.requirement.Status)}`"
              >
                {{ group.requirement.Status }}
              </span>
            </header>

            <div v-if="group.courses.length" class="completion-course-list">
              <article
                v-for="(course, courseIndex) in group.courses"
                :key="`${course.CourseCode}-${course.Sequence}-${courseIndex}`"
                class="completion-course-row"
              >
                <div>
                  <h3>{{ course.Name || '未命名课程' }}</h3>
                  <p>{{ courseMeta(course) || '课程信息未提供' }}</p>
                  <small v-if="course.Remark">{{ course.Remark }}</small>
                </div>
                <div class="completion-course-row__result">
                  <strong>{{ course.Score || '—' }}</strong>
                  <span :class="`status-text--${completionStatusTone(course.Status)}`">
                    {{ course.Status || '未标记' }}
                  </span>
                </div>
              </article>
            </div>

            <p v-else class="completion-group__empty">暂无课程明细</p>
          </section>
        </div>

        <div v-else class="completion-empty">
          <span aria-hidden="true">—</span>
          <h2>暂无培养方案明细</h2>
          <p>教务系统返回明细后会显示在这里。</p>
        </div>

        <p class="completion-footnote">
          数据来自教务系统培养方案预审，最终结果以学校审核为准。
          <template v-if="summary.AuditTime">审核时间：{{ summary.AuditTime }}</template>
        </p>
      </template>
    </section>
  </main>
</template>
