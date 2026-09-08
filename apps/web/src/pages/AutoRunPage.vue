<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import campusRunIcon from '@/assets/icons/nav-campus-run.png'
import clubIcon from '@/assets/icons/nav-club.png'
import profileIcon from '@/assets/icons/nav-profile-tab.png'
import BottomNavigation from '@/app/components/BottomNavigation.vue'
import {
  autoRunProgressPercent,
  buildAutoRunProgressCards,
  cancelAutoRunClub,
  clearAutoRunCredentials,
  clearAutoRunSessionKey,
  createAutoRunWeekDates,
  describeAutoRunClubSignTask,
  formatAutoRunNumber,
  formatLocalDate,
  getAutoRunClubData,
  getAutoRunInfo,
  isAutoRunAuthExpiredError,
  isSignedStatus,
  joinAutoRunClub,
  loadAutoRunCredentials,
  loadAutoRunSessionKey,
  loginToAutoRun,
  normalizeAutoRunClubActivities,
  normalizeAutoRunClubSignTask,
  resolveAutoRunClubSignAction,
  restoreAutoRunSession,
  saveAutoRunCredentials,
  saveAutoRunSessionKey,
  setAutoRunClubSchedule,
  signAutoRunClub,
  submitAutoRun,
  type AutoRunClubActivityView,
  type AutoRunClubSignTaskView,
  type AutoRunProgressCard,
} from '@/features/autorun'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'AutoRunPage' })

type PageTab = 'run' | 'club' | 'mine'
type DataStatus = 'loading' | 'empty' | 'ready'
type ActionStatus = 'idle' | 'loading' | 'success' | 'error'

interface ToastMessage {
  id: number
  message: string
  tone: 'success' | 'error'
}

const router = useRouter()
const activeTab = ref<PageTab>('run')
const sessionKey = ref(loadAutoRunSessionKey(window.localStorage, window.sessionStorage))
const rememberedCredentials = loadAutoRunCredentials()
const phone = ref(rememberedCredentials?.phone ?? '')
const password = ref(rememberedCredentials?.password ?? '')
const authChecking = ref(true)
const authenticated = ref(false)
const showLogin = ref(false)
const loginLoading = ref(false)
const loginError = ref('')
const manualLoadingCount = ref(0)
const toasts = ref<ToastMessage[]>([])
const toastTimers = new Set<number>()
let toastSequence = 0

const runStatus = ref<DataStatus>('loading')
const runCards = ref<AutoRunProgressCard[]>([])
const runMessage = ref('登录后可同步本学期校园跑进度')
const runActionStatus = ref<ActionStatus>('idle')
const runActionMessage = ref('')

const clubStatus = ref<DataStatus>('loading')
const clubMessage = ref('登录后可同步俱乐部活动')
const clubJoined = ref(0)
const clubTarget = ref(12)
const clubActivities = ref<AutoRunClubActivityView[]>([])
const clubQueryDate = ref(formatLocalDate())
const clubSignTask = ref<AutoRunClubSignTaskView | null>(null)
const clubSignLoading = ref(false)
const clubActionLoading = ref<Record<string, boolean>>({})
const clubScheduleEnabled = ref(false)
const clubScheduleSaving = ref(false)
const clubScheduleMessage = ref('定时未开启')
const now = ref(Date.now())
let clockTimer: number | undefined

const tabs: Array<{ name: PageTab; label: string; icon: string; iconClass: string }> = [
  { name: 'run', label: '校园跑', icon: campusRunIcon, iconClass: 'campus-run' },
  { name: 'club', label: '俱乐部', icon: clubIcon, iconClass: 'club' },
  { name: 'mine', label: '我的', icon: profileIcon, iconClass: 'profile' },
]
const pageTitle = computed(() => {
  if (activeTab.value === 'club') return '俱乐部'
  if (activeTab.value === 'mine') return '我的'
  return '校园跑'
})
const pageSubtitle = computed(() =>
  activeTab.value === 'club' ? '查看签到状态并完成一键签到或签退' : '',
)
const weekDates = computed(() => createAutoRunWeekDates())
const clubProgress = computed(() => autoRunProgressPercent(clubJoined.value, clubTarget.value))
const clubSignAction = computed(() => resolveAutoRunClubSignAction(clubSignTask.value))
const clubSignStatus = computed(() => describeAutoRunClubSignTask(clubSignTask.value))
const signBackCountdown = computed(() => {
  const task = clubSignTask.value
  if (!task || !isSignedStatus(task.signInStatus) || isSignedStatus(task.signBackStatus)) return ''
  const eventTime = parseEventTime(clubQueryDate.value, task.endTime)
  if (!eventTime) return ''
  const remaining = eventTime.getTime() - 10 * 60 * 1000 - now.value
  return remaining > 0 ? `距签退窗口 ${formatCountdown(remaining)}` : '已进入签退试探窗口'
})

usePageTheme('#f2f2f7')

onMounted(() => {
  clockTimer = window.setInterval(() => (now.value = Date.now()), 1000)
  void initializeAutoRun()
})

onBeforeUnmount(() => {
  window.clearInterval(clockTimer)
  toastTimers.forEach((timer) => window.clearTimeout(timer))
})

watch([activeTab, clubQueryDate], ([tab]) => {
  if (tab === 'club' && authenticated.value && !authChecking.value) {
    void loadClubData()
  }
})

async function initializeAutoRun() {
  const savedSession = sessionKey.value.trim()
  if (!savedSession) {
    authChecking.value = false
    showLogin.value = true
    return
  }

  try {
    const result = await restoreAutoRunSession(savedSession, currentCredentials())
    updateSessionKey(result.data.sessionKey)
    authenticated.value = true
    showLogin.value = false
    await loadRunData()
  } catch (error) {
    if (isAutoRunAuthExpiredError(error)) {
      clearSession()
      loginError.value = '登录态已失效，请重新输入手机号和密码'
      showLogin.value = true
    } else {
      authenticated.value = true
      showLogin.value = false
      runStatus.value = 'empty'
      runMessage.value = readableError(error, '暂时无法校验登录态，请稍后刷新')
    }
  } finally {
    authChecking.value = false
  }
}

async function login() {
  const normalizedPhone = phone.value.trim()
  const normalizedPassword = password.value.trim()
  if (!normalizedPhone || !normalizedPassword) {
    loginError.value = '手机号和密码不能为空'
    return
  }

  loginLoading.value = true
  loginError.value = ''
  try {
    const result = await loginToAutoRun(normalizedPhone, normalizedPassword)
    phone.value = normalizedPhone
    password.value = normalizedPassword
    saveAutoRunCredentials(normalizedPhone, normalizedPassword)
    updateSessionKey(result.data.sessionKey)
    authenticated.value = true
    showLogin.value = false
    pushToast('登录成功', 'success')
    if (activeTab.value === 'club') await loadClubData()
    else await loadRunData()
  } catch (error) {
    if (isAutoRunAuthExpiredError(error)) clearSession()
    loginError.value = readableError(error, '登录失败')
  } finally {
    loginLoading.value = false
    authChecking.value = false
  }
}

function logout() {
  clearSession()
  runCards.value = []
  clubActivities.value = []
  runStatus.value = 'empty'
  clubStatus.value = 'empty'
  loginError.value = ''
  showLogin.value = true
}

async function loadRunData(manual = false) {
  if (!requireSession()) return
  if (runCards.value.length === 0) runStatus.value = 'loading'
  try {
    const result = await withManualLoading(manual, () =>
      getAutoRunInfo(sessionKey.value, currentCredentials()),
    )
    adoptRotatedSession(result.data)
    runCards.value = buildAutoRunProgressCards(result.data)
    runStatus.value = 'ready'
    runMessage.value = '已同步校园跑进度'
  } catch (error) {
    if (runCards.value.length === 0) runStatus.value = 'empty'
    runMessage.value = handleApiError(error, '加载校园跑进度失败')
  }
}

async function runOnce() {
  if (!requireSession() || runActionStatus.value === 'loading') return
  runActionStatus.value = 'loading'
  runActionMessage.value = '处理中…'
  try {
    const result = await withManualLoading(true, () =>
      submitAutoRun(sessionKey.value, currentCredentials()),
    )
    adoptRotatedSession(result.data)
    const message = result.message || '提交成功'
    runActionStatus.value = 'success'
    runActionMessage.value = message
    pushToast(message, 'success')
    await loadRunData()
  } catch (error) {
    const message = handleApiError(error, '提交失败')
    runActionStatus.value = 'error'
    runActionMessage.value = message
    pushToast(message, 'error')
  }
}

async function loadClubData(manual = false) {
  if (!requireSession()) return
  if (clubActivities.value.length === 0) clubStatus.value = 'loading'
  try {
    const result = await withManualLoading(manual, () =>
      getAutoRunClubData(sessionKey.value, clubQueryDate.value, currentCredentials()),
    )
    const data = result.data
    adoptRotatedSession(data)
    const joined = toNumber(data.joinProgress.joinNum) ?? 0
    const target = toNumber(data.joinProgress.totalNum) ?? 12
    clubJoined.value = joined
    clubTarget.value = Math.max(target, joined, 1)
    clubActivities.value = normalizeAutoRunClubActivities(data.activities ?? [])
    clubSignTask.value = normalizeAutoRunClubSignTask(data.signTask)
    clubScheduleEnabled.value = data.schedule?.enabled === true
    clubScheduleMessage.value =
      data.schedule?.lastMessage || (data.schedule?.enabled ? '定时已开启' : '定时未开启')
    clubStatus.value = clubActivities.value.length > 0 ? 'ready' : 'empty'
    clubMessage.value =
      clubActivities.value.length > 0
        ? `已同步 ${clubQueryDate.value} 的俱乐部活动`
        : `${clubQueryDate.value} 暂无俱乐部活动`
  } catch (error) {
    if (clubActivities.value.length === 0) clubStatus.value = 'empty'
    clubMessage.value = handleApiError(error, '加载俱乐部数据失败')
  }
}

async function toggleClubJoin(activity: AutoRunClubActivityView) {
  if (!requireSession() || clubActionLoading.value[activity.id]) return
  clubActionLoading.value = { ...clubActionLoading.value, [activity.id]: true }
  try {
    const result = await withManualLoading(true, () =>
      activity.isJoined
        ? cancelAutoRunClub(sessionKey.value, activity.activityId, currentCredentials())
        : joinAutoRunClub(sessionKey.value, activity.activityId, currentCredentials()),
    )
    adoptRotatedSession(result.data)
    pushToast(activity.isJoined ? '已取消报名' : '报名成功', 'success')
    await loadClubData()
  } catch (error) {
    pushToast(handleApiError(error, '操作失败'), 'error')
  } finally {
    clubActionLoading.value = { ...clubActionLoading.value, [activity.id]: false }
  }
}

async function handleClubSign() {
  const action = clubSignAction.value
  if (!requireSession() || !action || action.disabled || clubSignLoading.value) return
  clubSignLoading.value = true
  try {
    const result = await withManualLoading(true, () =>
      signAutoRunClub(sessionKey.value, action.signType, currentCredentials()),
    )
    adoptRotatedSession(result.data)
    if (result.data.success !== true) throw new Error(result.message || '当前暂不可操作')
    pushToast(action.signType === '1' ? '签到成功' : '签退成功', 'success')
    await loadClubData()
  } catch (error) {
    pushToast(handleApiError(error, '签到操作失败'), 'error')
  } finally {
    clubSignLoading.value = false
  }
}

async function saveClubSchedule(enabled: boolean) {
  if (!requireSession() || clubScheduleSaving.value) return
  const previous = clubScheduleEnabled.value
  clubScheduleEnabled.value = enabled
  clubScheduleSaving.value = true
  try {
    const result = await withManualLoading(true, () =>
      setAutoRunClubSchedule(sessionKey.value, enabled, currentCredentials()),
    )
    adoptRotatedSession(result.data)
    const schedule = result.data.schedule
    clubScheduleEnabled.value = schedule?.enabled ?? enabled
    clubScheduleMessage.value =
      schedule?.lastMessage || (clubScheduleEnabled.value ? '定时已开启' : '定时未开启')
    pushToast(result.message || (enabled ? '已开启俱乐部定时' : '已关闭俱乐部定时'), 'success')
  } catch (error) {
    clubScheduleEnabled.value = previous
    pushToast(handleApiError(error, '保存定时配置失败'), 'error')
  } finally {
    clubScheduleSaving.value = false
  }
}

function selectTab(tab: string) {
  if (tab === 'run' || tab === 'club' || tab === 'mine') activeTab.value = tab
}

function goBack() {
  void router.push({ name: 'tools' })
}

function requireSession() {
  if (authenticated.value && sessionKey.value) return true
  showLogin.value = true
  if (!loginError.value) loginError.value = '请先登录后再进行操作'
  return false
}

function updateSessionKey(value: string) {
  const normalized = value.trim()
  if (!normalized) return
  sessionKey.value = normalized
  saveAutoRunSessionKey(normalized, window.localStorage, window.sessionStorage)
}

function adoptRotatedSession(value: { sessionKey?: string }) {
  if (value.sessionKey) updateSessionKey(value.sessionKey)
}

function currentCredentials() {
  const normalizedPhone = phone.value.trim()
  const normalizedPassword = password.value.trim()
  return normalizedPhone && normalizedPassword
    ? { phone: normalizedPhone, password: normalizedPassword }
    : undefined
}

function clearSession() {
  authenticated.value = false
  sessionKey.value = ''
  password.value = ''
  clearAutoRunCredentials()
  clearAutoRunSessionKey(window.localStorage, window.sessionStorage)
}

function handleApiError(error: unknown, fallback: string) {
  if (isAutoRunAuthExpiredError(error)) {
    clearSession()
    showLogin.value = true
    loginError.value = '登录态已失效，请重新输入手机号和密码'
  }
  return readableError(error, fallback)
}

function readableError(error: unknown, fallback: string) {
  if (!(error instanceof Error)) return fallback
  const message = error.message.replace(/\s+/g, ' ').trim()
  return message ? (message.length > 100 ? `${message.slice(0, 100)}…` : message) : fallback
}

async function withManualLoading<T>(manual: boolean, request: () => Promise<T>) {
  if (manual) manualLoadingCount.value += 1
  try {
    return await request()
  } finally {
    if (manual) manualLoadingCount.value = Math.max(0, manualLoadingCount.value - 1)
  }
}

function pushToast(message: string, tone: ToastMessage['tone']) {
  const id = ++toastSequence
  toasts.value.push({ id, message, tone })
  const timer = window.setTimeout(() => {
    toasts.value = toasts.value.filter((toast) => toast.id !== id)
    toastTimers.delete(timer)
  }, 3200)
  toastTimers.add(timer)
}

function toNumber(value: unknown) {
  const number = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(number) ? number : null
}

function parseEventTime(date: string, value: string) {
  if (!value || value === '--:--') return null
  const normalized = value.replace(/\//g, '-').replace(' ', 'T')
  const complete = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(normalized)
    ? normalized
    : `${date}T${normalized}`
  const parsed = new Date(complete)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function formatCountdown(milliseconds: number) {
  const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000))
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  return [hours, minutes, seconds]
    .filter((_, index) => hours > 0 || index > 0)
    .map((value) => String(value).padStart(2, '0'))
    .join(':')
}
</script>

<template>
  <main class="autorun-page" :class="`is-${activeTab}`">
    <header v-if="activeTab === 'run'" class="autorun-run-header">
      <div>
        <h1>校园跑</h1>
        <p>查看本学期运动进度</p>
      </div>
      <button
        type="button"
        class="autorun-run-refresh"
        aria-label="刷新校园跑进度"
        title="刷新校园跑进度"
        @click="loadRunData(true)"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M20 6v5h-5" />
          <path d="M18.2 15.5A7 7 0 1 1 19 8.7L20 11" />
        </svg>
      </button>
    </header>

    <header v-else class="autorun-header" :class="{ 'is-club': activeTab === 'club' }">
      <h1>{{ pageTitle }}</h1>
      <p v-if="pageSubtitle">{{ pageSubtitle }}</p>
    </header>

    <section v-if="activeTab === 'run'" class="autorun-content">
      <section class="autorun-overview" aria-labelledby="autorun-overview-title">
        <div class="autorun-overview__heading">
          <div>
            <span>本学期概览</span>
            <h2 id="autorun-overview-title">运动进度</h2>
          </div>
          <p class="autorun-overview__sync" :class="`is-${runStatus}`">
            <i aria-hidden="true" />{{ runMessage }}
          </p>
        </div>

        <div v-if="runStatus === 'loading'" class="autorun-metrics" aria-label="正在加载校园跑进度">
          <article v-for="index in 2" :key="index" class="autorun-metric autorun-metric--skeleton autorun-skeleton">
            <i /><i /><i />
          </article>
        </div>

        <div v-else-if="runStatus === 'ready'" class="autorun-metrics">
          <article v-for="card in runCards" :key="card.id" class="autorun-metric">
            <div class="autorun-metric__heading">
              <span :style="{ background: card.accent }">
                {{ card.id === 'count-progress' ? '次' : 'km' }}
              </span>
              <div>
                <p>{{ card.id === 'count-progress' ? '有效次数' : '有效距离' }}</p>
              </div>
              <strong>{{ autoRunProgressPercent(card.current, card.target) }}%</strong>
            </div>
            <p class="autorun-metric__value">
              {{ formatAutoRunNumber(card.current) }}
              <span>/ {{ formatAutoRunNumber(card.target) }} {{ card.unit }}</span>
            </p>
            <div class="autorun-metric__progress" :aria-label="`${card.title}进度`">
              <span
                :style="{
                  width: `${autoRunProgressPercent(card.current, card.target)}%`,
                  background: card.accent,
                }"
              />
            </div>
          </article>
        </div>

        <div v-else class="autorun-overview__empty">
          <div><strong>暂时没有进度数据</strong><p>{{ runMessage }}</p></div>
          <button type="button" class="autorun-secondary" @click="loadRunData(true)">重新加载</button>
        </div>
      </section>

      <section class="autorun-run-zone" :class="`is-${runActionStatus}`">
        <div class="autorun-run-zone__heading">
          <span>跑步记录</span>
          <h2>生成并提交</h2>
          <p>{{ runActionMessage || '自动生成轨迹并提交至校园跑' }}</p>
        </div>

        <button
          type="button"
          class="autorun-run-command"
          :class="`is-${runActionStatus}`"
          :disabled="runActionStatus === 'loading'"
          :aria-busy="runActionStatus === 'loading'"
          aria-label="生成并提交校园跑记录"
          @click="runOnce"
        >
          <span class="autorun-run-command__kicker">
            {{ runActionStatus === 'loading' ? '跑步记录生成中' : '校园跑执行按钮' }}
          </span>
          <svg class="autorun-run-command__flag" viewBox="0 0 64 64" aria-hidden="true">
            <path d="M20 52V12" />
            <path d="M22 15h26L41 25l7 10H22" />
          </svg>
          <strong>{{ runActionStatus === 'loading' ? '严肃处理中' : '郑重开跑' }}</strong>
          <small v-if="runActionStatus === 'success'">记录已郑重提交，任务圆满完成</small>
          <small v-else-if="runActionStatus === 'error'">执行未果，请再次郑重尝试</small>
          <small v-else>事关本学期运动大局，请认真轻点</small>
        </button>
      </section>
    </section>

    <section v-else-if="activeTab === 'club'" class="autorun-club">
      <div class="autorun-club-hero">
        <p>运动让生活更美好</p>
        <div class="autorun-truck" aria-hidden="true">
          <svg viewBox="0 0 198 93">
            <path d="M7 2h120v88H7z" fill="#dfdfdf" stroke="#282828" stroke-width="3" />
            <path d="M135 23h42l15 35v32h-57z" fill="#f83d3d" stroke="#282828" stroke-width="3" />
            <path d="M146 34h35l8 21h-43z" fill="#7d7c7c" stroke="#282828" stroke-width="3" />
            <circle cx="36" cy="85" r="12" fill="#282828" />
            <circle cx="36" cy="85" r="6" fill="#dfdfdf" />
            <circle cx="164" cy="85" r="12" fill="#282828" />
            <circle cx="164" cy="85" r="6" fill="#dfdfdf" />
          </svg>
          <span />
        </div>
      </div>

      <div class="autorun-club-progress">
        <div><span :style="{ width: `${clubProgress}%` }" /></div>
        <p><span>已参加：{{ clubJoined }}次</span><span>目标：{{ clubTarget }}次</span></p>
      </div>

      <section class="autorun-club-panel autorun-sign-panel">
        <div class="autorun-sign-main">
          <div>
            <span class="autorun-sign-badge" :class="{ 'is-signback': clubSignAction?.signType === '2' }">
              {{ clubSignStatus }}
            </span>
            <h3>{{ clubSignTask?.activityName ?? '签到任务' }}</h3>
            <template v-if="clubSignTask">
              <p>活动时间：{{ clubSignTask.startTime }}–{{ clubSignTask.endTime }}</p>
              <p>活动地点：{{ clubSignTask.address }}</p>
            </template>
            <p v-else>{{ clubMessage }}</p>
          </div>
          <button
            type="button"
            class="autorun-sign-button"
            :class="{ 'is-signback': clubSignAction?.signType === '2' }"
            :disabled="!clubSignAction || clubSignAction.disabled || clubSignLoading"
            @click="handleClubSign"
          >
            {{ clubSignLoading ? clubSignAction?.pendingLabel ?? '处理中…' : clubSignAction?.label ?? '暂无任务' }}
          </button>
        </div>
        <div v-if="clubSignTask" class="autorun-sign-detail">
          <span>签到：{{ clubSignTask.signInTime || (isSignedStatus(clubSignTask.signInStatus) ? '已签到' : '--') }}</span>
          <span>{{ signBackCountdown || `签退：${isSignedStatus(clubSignTask.signBackStatus) ? '已签退' : '--'}` }}</span>
        </div>
      </section>

      <section class="autorun-club-panel autorun-schedule-panel">
        <div>
          <h3>定时签到/签退</h3>
          <p>{{ clubScheduleMessage }}</p>
        </div>
        <label class="autorun-switch" :class="{ 'is-saving': clubScheduleSaving }">
          <input
            type="checkbox"
            :checked="clubScheduleEnabled"
            :disabled="clubScheduleSaving"
            aria-label="定时签到或签退"
            @change="saveClubSchedule(($event.target as HTMLInputElement).checked)"
          />
          <span />
        </label>
      </section>

      <section class="autorun-club-board">
        <header><h3>俱乐部活动</h3><span>点日期查询</span></header>
        <div class="autorun-club-calendar">
          <button
            v-for="date in weekDates"
            :key="date.full"
            type="button"
            :class="{ 'is-active': date.full === clubQueryDate }"
            @click="clubQueryDate = date.full"
          >
            <span>{{ date.day }}</span><strong>{{ date.date }}</strong>
          </button>
        </div>
        <div v-if="clubStatus === 'loading'" class="autorun-club-empty">正在同步俱乐部活动…</div>
        <div v-else-if="clubStatus === 'empty'" class="autorun-club-empty">{{ clubMessage }}</div>
        <div v-else class="autorun-club-list">
          <article v-for="activity in clubActivities" :key="activity.id">
            <h4>{{ activity.title }}</h4>
            <p>活动时间：{{ activity.startTime }}–{{ activity.endTime }}</p>
            <p>活动地点：{{ activity.address }}</p>
            <footer>
              <span>体能教研室 · {{ activity.joined }}/{{ activity.capacity || '--' }} 人</span>
              <button
                type="button"
                :class="activity.isJoined ? 'is-cancel' : 'is-join'"
                :disabled="clubActionLoading[activity.id] || (!activity.isJoined && activity.isFull)"
                @click="toggleClubJoin(activity)"
              >
                {{ clubActionLoading[activity.id] ? '处理中' : activity.isJoined ? '取消报名' : activity.isFull ? '已满员' : '报名' }}
              </button>
            </footer>
          </article>
        </div>
      </section>

      <button type="button" class="autorun-secondary autorun-refresh" @click="loadClubData(true)">
        刷新活动
      </button>
    </section>

    <section v-else class="autorun-account">
      <div class="autorun-section-heading">
        <h2>校园跑账号</h2>
        <p>登录凭证仅保存在此设备，不保存密码；退出账号或服务确认失效时会自动清除。</p>
      </div>
      <div class="autorun-account-card autorun-glass">
        <span class="autorun-account-icon" aria-hidden="true">✓</span>
        <div><strong>账号已连接</strong><p>可以使用校园跑与俱乐部功能</p></div>
      </div>
      <button type="button" class="autorun-logout" @click="logout">退出校园跑账号</button>
    </section>

    <div class="autorun-bottom-bar">
      <button type="button" class="autorun-back" aria-label="返回工具页" @click="goBack">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="m14.5 5-7 7 7 7" />
        </svg>
      </button>
      <BottomNavigation
        class="autorun-tab-navigation"
        :items="tabs"
        :active-name="activeTab"
        aria-label="校园运动功能"
        inline
        compact
        @select="selectTab"
      />
    </div>

    <div v-if="toasts.length" class="autorun-toasts" role="status" aria-live="polite">
      <div v-for="toast in toasts" :key="toast.id" :class="toast.tone">{{ toast.message }}</div>
    </div>

    <div v-if="manualLoadingCount > 0" class="autorun-loading" role="status" aria-label="请求处理中">
      <div>
        <div class="autorun-loading__wheel" role="img" aria-label="仓鼠在滚轮中奔跑">
          <div class="wheel" />
          <div class="hamster">
            <div class="hamster__body">
              <div class="hamster__head">
                <div class="hamster__ear" />
                <div class="hamster__eye" />
                <div class="hamster__nose" />
              </div>
              <div class="hamster__limb hamster__limb--fr" />
              <div class="hamster__limb hamster__limb--fl" />
              <div class="hamster__limb hamster__limb--br" />
              <div class="hamster__limb hamster__limb--bl" />
              <div class="hamster__tail" />
            </div>
          </div>
          <div class="spoke" />
        </div>
        <p>请求处理中…</p>
      </div>
    </div>

    <div v-if="showLogin" class="autorun-login-backdrop" role="dialog" aria-modal="true" aria-label="校园跑登录">
      <form class="autorun-login autorun-glass" @submit.prevent="login">
        <h2>登录校园跑</h2>
        <p>请输入 unirun 手机号和密码，登录后密码不会保存。</p>
        <label><span>手机号</span><input v-model="phone" autocomplete="username" inputmode="tel" placeholder="请输入手机号" /></label>
        <label><span>密码</span><input v-model="password" type="password" autocomplete="current-password" placeholder="请输入密码" /></label>
        <p v-if="loginLoading" class="autorun-login__status" role="status" aria-live="polite">
          正在连接校园跑服务，最长等待 20 秒…
        </p>
        <p v-else-if="loginError" class="autorun-login__error" role="alert">{{ loginError }}</p>
        <button type="submit" class="autorun-primary" :disabled="loginLoading || authChecking">
          {{ loginLoading || authChecking ? '验证中…' : '登录' }}
        </button>
        <button type="button" class="autorun-login__back" @click="goBack">返回工具页</button>
      </form>
    </div>
  </main>
</template>
