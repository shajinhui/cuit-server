<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'

import {
  createRatingModerationAction,
  formatRatingTime,
  getRatingAdminContent,
  listRatingAdminReports,
  updateRatingAdminReport,
  type RatingAdminContent,
  type RatingAdminReport,
  type RatingAdminReportStatus,
  type RatingAdminTargetType,
} from '@/features/ratings'
import { RatingPageHeader, RatingState } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'RatingAdminPage' })

const router = useRouter()
const status = ref<RatingAdminReportStatus>('open')
const reports = ref<RatingAdminReport[]>([])
const contentByReport = reactive<Record<string, RatingAdminContent | undefined>>({})
const reasonByReport = reactive<Record<string, string>>({})
const loading = ref(true)
const loadingMore = ref(false)
const busyReportID = ref('')
const error = ref('')
const notice = ref('')
const nextCursor = ref<string | null>(null)
const hasMore = ref(false)
let requestVersion = 0

usePageTheme('#f2f2f7')
onMounted(() => void loadReports(true))

async function loadReports(reset: boolean) {
  const version = ++requestVersion
  if (reset) loading.value = true
  else loadingMore.value = true
  error.value = ''
  notice.value = ''
  try {
    const page = await listRatingAdminReports({
      status: status.value,
      cursor: reset ? undefined : nextCursor.value ?? undefined,
      limit: 20,
    })
    if (version !== requestVersion) return
    reports.value = reset ? page.items : [...reports.value, ...page.items]
    nextCursor.value = page.next_cursor
    hasMore.value = page.has_more
  } catch (reason) {
    if (version === requestVersion) {
      error.value = reason instanceof Error ? reason.message : '举报列表加载失败'
    }
  } finally {
    if (version === requestVersion) {
      loading.value = false
      loadingMore.value = false
    }
  }
}

function changeStatus(value: RatingAdminReportStatus) {
  if (status.value === value) return
  status.value = value
  reports.value = []
  void loadReports(true)
}

async function inspect(report: RatingAdminReport) {
  if (contentByReport[report.id]) {
    delete contentByReport[report.id]
    return
  }
  await refreshContent(report)
}

async function refreshContent(report: RatingAdminReport) {
  busyReportID.value = report.id
  error.value = ''
  try {
    contentByReport[report.id] = await getRatingAdminContent(
      report.target_type,
      report.target_id,
    )
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '内容加载失败'
  } finally {
    busyReportID.value = ''
  }
}

async function moderate(report: RatingAdminReport) {
  const content = contentByReport[report.id]
  if (!content) return
  const action = content.content.status === 'published' ? 'hide' : 'restore'
  const reason = (reasonByReport[report.id] || '').trim()
  if (reason.length < 2) {
    error.value = '请填写至少 2 个字的管理原因'
    return
  }
  busyReportID.value = report.id
  error.value = ''
  notice.value = ''
  try {
    await createRatingModerationAction({
      target_type: report.target_type,
      target_id: report.target_id,
      action,
      reason,
      expected_version: content.content.version,
    })
    contentByReport[report.id] = await getRatingAdminContent(
      report.target_type,
      report.target_id,
    )
    reasonByReport[report.id] = ''
    notice.value = action === 'hide' ? '内容已隐藏并记录管理日志' : '内容已恢复并记录管理日志'
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '管理操作失败'
  } finally {
    busyReportID.value = ''
  }
}

async function updateReport(report: RatingAdminReport, nextStatus: RatingAdminReportStatus) {
  busyReportID.value = report.id
  error.value = ''
  notice.value = ''
  try {
    await updateRatingAdminReport(report.id, nextStatus)
    reports.value = reports.value.filter((entry) => entry.id !== report.id)
    notice.value = nextStatus === 'resolved' ? '举报已标记为已处理' : nextStatus === 'rejected' ? '举报已驳回' : '举报已重新打开'
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '举报状态更新失败'
  } finally {
    busyReportID.value = ''
  }
}

function targetLabel(type: RatingAdminTargetType) {
  return type === 'board' ? '板块' : type === 'item' ? '对象' : '评论'
}

function contentTitle(content: RatingAdminContent) {
  return content.content.title || content.content.name || content.content.body || '无标题内容'
}

function statusLabel(value: RatingAdminContent['content']['status']) {
  return value === 'published' ? '公开中' : value === 'hidden' ? '已隐藏' : '已删除'
}
</script>

<template>
  <main class="ratings-page rating-admin-page">
    <RatingPageHeader title="评分内容管理" subtitle="举报与内容状态" @back="router.push({ name: 'ratings' })" />

    <section class="rating-admin-toolbar" aria-label="举报状态筛选">
      <div class="ratings-segment ratings-segment--three" role="tablist">
        <button
          v-for="option in ([['open', '待处理'], ['resolved', '已处理'], ['rejected', '已驳回']] as const)"
          :key="option[0]"
          type="button"
          role="tab"
          :aria-selected="status === option[0]"
          :class="{ 'is-active': status === option[0] }"
          @click="changeStatus(option[0])"
        >
          {{ option[1] }}
        </button>
      </div>
      <p>管理权限由 Ratings Worker 按当前账号校验。</p>
    </section>

    <p v-if="error" class="rating-admin-banner is-error" role="alert">{{ error }}</p>
    <p v-if="notice" class="rating-admin-banner" role="status">{{ notice }}</p>

    <section class="ratings-section ratings-section--inset">
      <RatingState v-if="loading" title="正在加载举报" loading />
      <RatingState
        v-else-if="reports.length === 0"
        title="当前没有举报"
        description="切换状态可查看已处理或已驳回的记录。"
      />
      <div v-else class="rating-admin-list">
        <article v-for="report in reports" :key="report.id" class="rating-admin-card">
          <header>
            <div>
              <span>{{ targetLabel(report.target_type) }}</span>
              <strong>{{ report.reporter_name }} 的举报</strong>
            </div>
            <time :datetime="report.created_at">{{ formatRatingTime(report.created_at) }}</time>
          </header>
          <p class="rating-admin-card__reason">{{ report.reason }}</p>
          <code>{{ report.target_id }}</code>
          <button
            type="button"
            class="rating-admin-secondary"
            :disabled="busyReportID === report.id"
            @click="inspect(report)"
          >
            {{ contentByReport[report.id] ? '收起内容' : busyReportID === report.id ? '正在读取…' : '查看目标内容' }}
          </button>

          <section v-if="contentByReport[report.id]" class="rating-admin-content">
            <div>
              <span :class="`is-${contentByReport[report.id]?.content.status}`">
                {{ statusLabel(contentByReport[report.id]!.content.status) }}
              </span>
              <small>版本 {{ contentByReport[report.id]!.content.version }}</small>
            </div>
            <strong>{{ contentTitle(contentByReport[report.id]!) }}</strong>
            <p v-if="contentByReport[report.id]!.content.description">
              {{ contentByReport[report.id]!.content.description }}
            </p>
            <template v-if="contentByReport[report.id]!.content.status !== 'deleted'">
              <label>
                <span>管理原因</span>
                <input
                  v-model="reasonByReport[report.id]"
                  type="text"
                  maxlength="500"
                  placeholder="至少 2 个字，将写入管理日志"
                />
              </label>
              <button
                type="button"
                :class="contentByReport[report.id]!.content.status === 'published' ? 'rating-admin-danger' : 'rating-admin-primary'"
                :disabled="busyReportID === report.id"
                @click="moderate(report)"
              >
                {{ contentByReport[report.id]!.content.status === 'published' ? '隐藏内容' : '恢复内容' }}
              </button>
            </template>
          </section>

          <footer>
            <template v-if="status === 'open'">
              <button type="button" :disabled="busyReportID === report.id" @click="updateReport(report, 'rejected')">驳回</button>
              <button type="button" class="is-primary" :disabled="busyReportID === report.id" @click="updateReport(report, 'resolved')">标记已处理</button>
            </template>
            <button v-else type="button" class="is-primary" :disabled="busyReportID === report.id" @click="updateReport(report, 'open')">重新打开</button>
          </footer>
        </article>
        <button v-if="hasMore" type="button" class="ratings-load-more" :disabled="loadingMore" @click="loadReports(false)">
          {{ loadingMore ? '正在加载…' : '加载更多' }}
        </button>
      </div>
    </section>
  </main>
</template>
