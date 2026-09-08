<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import overviewIcon from '@/assets/icons/nav-tools.png'
import devicesIcon from '@/assets/icons/nav-profile-tab.png'
import BottomNavigation from '@/app/components/BottomNavigation.vue'
import {
  fetchServiceStats,
  percentage,
  platformDeviceDistribution,
  StatsTrendChart,
  type ChartSeries,
  type ServiceStats,
} from '@/features/analytics'
import { ApiError } from '@/shared/api/client'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppSelect from '@/shared/ui/AppSelect.vue'

defineOptions({ name: 'AdminStatsPage' })

const tokenStorageKey = 'cuit-admin-stats-token'
const numberFormatter = new Intl.NumberFormat('zh-CN')
const periodOptions = [
  { value: 7, label: '近 7 天' },
  { value: 30, label: '近 30 天' },
  { value: 90, label: '近 90 天' },
]
const tokenInput = ref('')
const periodDays = ref(30)
const stats = ref<ServiceStats>()
const loading = ref(false)
const error = ref('')
const activeSection = ref<'overview' | 'devices'>('overview')
const adminNavigationItems = [
  { name: 'overview', label: '服务概览', icon: overviewIcon, iconClass: 'tools' },
  { name: 'devices', label: '用户设备', icon: devicesIcon, iconClass: 'profile' },
] as const

usePageTheme('#f4f6fa')

const errorRate = computed(() =>
  percentage(stats.value?.summary.errors_period ?? 0, stats.value?.summary.requests_period ?? 0),
)
const cacheHitRate = computed(() => {
  const cache = stats.value?.cache
  if (!cache) return 0
  return percentage(cache.hits + cache.coalesced_requests, cache.requests)
})
const cacheStatus = computed(() => {
  const cache = stats.value?.cache
  if (!cache?.enabled) return '未启用'
  return cache.reachable ? '运行正常' : '连接异常'
})
const requestSeries = computed<ChartSeries[]>(() => [
  {
    label: '请求量',
    color: '#1677ff',
    values: stats.value?.daily.map((item) => item.request_count) ?? [],
  },
  {
    label: '错误量',
    color: '#f04452',
    values: stats.value?.daily.map((item) => item.error_count) ?? [],
  },
])
const userSeries = computed<ChartSeries[]>(() => [
  {
    label: '活跃用户',
    color: '#34a853',
    values: stats.value?.daily.map((item) => item.active_users) ?? [],
  },
  {
    label: '新增用户',
    color: '#8b5cf6',
    values: stats.value?.daily.map((item) => item.new_users) ?? [],
  },
])
const dates = computed(() => stats.value?.daily.map((item) => item.date) ?? [])
const updatedAt = computed(() => {
  if (!stats.value?.generated_at) return ''
  return new Intl.DateTimeFormat('zh-CN', {
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(stats.value.generated_at))
})
const deviceDistribution = computed(() => platformDeviceDistribution(stats.value?.devices))
const deviceTrackedUsers = computed(() => stats.value?.devices?.tracked_users ?? 0)
const deviceCoverage = computed(() =>
  percentage(deviceTrackedUsers.value, stats.value?.summary.total_users ?? 0),
)
const brandDistribution = computed(() =>
  (stats.value?.devices?.brands ?? []).map((item) => ({
    ...item,
    share: percentage(item.count, deviceTrackedUsers.value),
  })),
)
const iosShare = computed(
  () => deviceDistribution.value.find((item) => item.platform === 'ios')?.share ?? 0,
)
const deviceChartStyle = computed(() => ({ '--ios-share': `${iosShare.value}%` }))

onMounted(() => {
  const savedToken = window.sessionStorage.getItem(tokenStorageKey)
  if (savedToken) {
    void loadStats(savedToken)
  }
})

async function unlock() {
  const token = tokenInput.value.trim()
  if (!token) {
    error.value = '请输入管理员令牌'
    return
  }
  await loadStats(token)
}

async function refreshStats() {
  const token = window.sessionStorage.getItem(tokenStorageKey)
  if (!token) {
    lockDashboard()
    return
  }
  await loadStats(token)
}

async function loadStats(token: string) {
  loading.value = true
  error.value = ''
  try {
    const result = await fetchServiceStats(token, periodDays.value)
    stats.value = result
    periodDays.value = result.period_days
    window.sessionStorage.setItem(tokenStorageKey, token)
    tokenInput.value = ''
  } catch (cause) {
    if (cause instanceof ApiError && cause.status === 401) {
      window.sessionStorage.removeItem(tokenStorageKey)
      stats.value = undefined
      error.value = '管理员令牌无效，请重新输入'
    } else {
      if (stats.value) {
        periodDays.value = stats.value.period_days
      }
      error.value = cause instanceof Error ? cause.message : '统计数据暂时无法读取'
    }
  } finally {
    loading.value = false
  }
}

function lockDashboard() {
  window.sessionStorage.removeItem(tokenStorageKey)
  tokenInput.value = ''
  stats.value = undefined
  error.value = ''
}

function formatNumber(value: number): string {
  return numberFormatter.format(value)
}

function formatLatency(value: number): string {
  if (value >= 1000) return `${(value / 1000).toFixed(1)} 秒`
  return `${Math.round(value)} ms`
}

function formatBytes(value: number): string {
  if (value >= 1024 * 1024) return `${(value / (1024 * 1024)).toFixed(1)} MB`
  if (value >= 1024) return `${(value / 1024).toFixed(1)} KB`
  return `${value} B`
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('zh-CN', {
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

function feedbackTypeLabel(type: 'suggestion' | 'bug'): string {
  return type === 'bug' ? 'Bug' : '建议'
}

function selectAdminSection(name: string) {
  if (name === 'overview' || name === 'devices') activeSection.value = name
}
</script>

<template>
  <main class="admin-stats-page">
    <header class="admin-topbar">
      <a class="admin-brand" href="/" aria-label="返回成信友友首页">
        <img src="/icons/app-icon-192.png" alt="" />
        <span>
          <strong>成信友友</strong>
          <small>服务统计</small>
        </span>
      </a>
      <button v-if="stats" type="button" class="admin-lock-button" @click="lockDashboard">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M7 10V7a5 5 0 0 1 9.8-1.4M6 10h12v10H6z" />
        </svg>
        退出统计
      </button>
    </header>

    <section v-if="!stats" class="admin-unlock">
      <div class="admin-unlock__mark" aria-hidden="true">
        <svg viewBox="0 0 24 24">
          <path d="M12 3 5.5 5.7v5.6c0 4.2 2.7 7.9 6.5 9.7 3.8-1.8 6.5-5.5 6.5-9.7V5.7L12 3Z" />
          <path d="m9.2 12 1.8 1.8 3.9-4" />
        </svg>
      </div>
      <p class="admin-eyebrow">PRIVATE ANALYTICS</p>
      <h1>查看服务运行情况</h1>
      <p class="admin-unlock__description">
        输入服务器上的管理员令牌，查看接口调用和用户增长。令牌仅保留在当前浏览器会话中。
      </p>

      <form class="admin-token-form" @submit.prevent="unlock">
        <label for="admin-token">管理员令牌</label>
        <div class="admin-token-field">
          <svg aria-hidden="true" viewBox="0 0 24 24">
            <circle cx="8" cy="12" r="3.5" />
            <path d="M11.5 12H21M17 12v3M14 12v2" />
          </svg>
          <input
            id="admin-token"
            v-model="tokenInput"
            type="password"
            autocomplete="off"
            spellcheck="false"
            placeholder="输入 ADMIN_STATS_TOKEN"
            :disabled="loading"
          />
        </div>
        <p v-if="error" class="admin-form-error" role="alert">{{ error }}</p>
        <button type="submit" :disabled="loading">
          <span v-if="loading" class="admin-button-spinner" aria-hidden="true" />
          {{ loading ? '正在验证…' : '进入统计面板' }}
        </button>
      </form>
    </section>

    <template v-else>
      <div class="admin-tabbar-shell">
        <BottomNavigation
          class="admin-tab-navigation"
          :items="adminNavigationItems"
          :active-name="activeSection"
          aria-label="统计页面导航"
          inline
          compact
          @select="selectAdminSection"
        />
      </div>

      <section class="admin-dashboard">
        <template v-if="activeSection === 'overview'">
          <header class="admin-dashboard-heading">
        <div>
          <p class="admin-eyebrow">OVERVIEW</p>
          <h1>服务概览</h1>
          <p>最近更新于 {{ updatedAt }}</p>
        </div>
        <div class="admin-dashboard-actions">
          <label>
            <span class="visually-hidden">统计周期</span>
            <AppSelect
              v-model="periodDays"
              class="admin-period-select"
              :options="periodOptions"
              title="选择统计周期"
              aria-label="选择统计周期"
              :disabled="loading"
              @change="refreshStats"
            />
          </label>
          <button type="button" aria-label="刷新统计" :disabled="loading" @click="refreshStats">
            <svg aria-hidden="true" viewBox="0 0 24 24" :class="{ 'is-spinning': loading }">
              <path d="M20 6v5h-5M19 11a7 7 0 1 0 .2 5" />
            </svg>
          </button>
        </div>
          </header>

          <p v-if="error" class="admin-dashboard-error" role="alert">{{ error }}</p>

      <section class="admin-metric-grid" aria-label="核心指标">
        <article class="admin-metric-card admin-metric-card--blue">
          <span class="admin-metric-card__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M16 20v-1.7c0-2-1.8-3.6-4-3.6s-4 1.6-4 3.6V20M12 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7ZM18 9.5a3 3 0 0 1 0 5.8M19 16.5c1.2.5 2 1.5 2 2.7v.8" /></svg>
          </span>
          <p>总用户</p>
          <strong>{{ formatNumber(stats.summary.total_users) }}</strong>
          <small>今日新增 {{ formatNumber(stats.summary.new_users_today) }}</small>
        </article>
        <article class="admin-metric-card admin-metric-card--green">
          <span class="admin-metric-card__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M4 17.5 9 12l3.5 3.5L20 7M15 7h5v5" /></svg>
          </span>
          <p>今日活跃</p>
          <strong>{{ formatNumber(stats.summary.dau_today) }}</strong>
          <small>WAU {{ formatNumber(stats.summary.wau) }} · MAU {{ formatNumber(stats.summary.mau) }}</small>
        </article>
        <article class="admin-metric-card admin-metric-card--purple">
          <span class="admin-metric-card__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M5 5h14v14H5zM8 15l2.5-3 2 2 3.5-5" /></svg>
          </span>
          <p>接口请求</p>
          <strong>{{ formatNumber(stats.summary.requests_period) }}</strong>
          <small>{{ stats.period_days }} 天累计</small>
        </article>
        <article class="admin-metric-card admin-metric-card--orange">
          <span class="admin-metric-card__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8" /><path d="M12 8v5M12 16.5v.5" /></svg>
          </span>
          <p>错误率</p>
          <strong>{{ errorRate.toFixed(1) }}%</strong>
          <small>{{ formatNumber(stats.summary.errors_period) }} 次错误</small>
        </article>
        <article class="admin-metric-card admin-metric-card--slate">
          <span class="admin-metric-card__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8" /><path d="M12 7v5l3 2" /></svg>
          </span>
          <p>平均耗时</p>
          <strong>{{ formatLatency(stats.summary.average_latency_ms) }}</strong>
          <small>所有接口请求</small>
        </article>
        <article class="admin-metric-card admin-metric-card--cyan">
          <span class="admin-metric-card__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M4 19V9M10 19V5M16 19v-7M22 19V8" /></svg>
          </span>
          <p>周期新增</p>
          <strong>{{ formatNumber(stats.summary.new_users_period) }}</strong>
          <small>最近 {{ stats.period_days }} 天</small>
        </article>
      </section>

      <section class="admin-cache-card" aria-labelledby="admin-cache-title">
        <header class="admin-card-heading">
          <div>
            <h2 id="admin-cache-title">缓存运行情况</h2>
            <p>应用级指标，自本次 API 服务启动以来累计</p>
          </div>
          <span
            class="admin-cache-status"
            :class="{
              'is-online': stats.cache.enabled && stats.cache.reachable,
              'is-error': stats.cache.enabled && !stats.cache.reachable,
            }"
          >
            {{ cacheStatus }}
          </span>
        </header>
        <div class="admin-cache-grid">
          <article>
            <span>有效命中率</span>
            <strong>{{ cacheHitRate.toFixed(1) }}%</strong>
          </article>
          <article>
            <span>缓存请求</span>
            <strong>{{ formatNumber(stats.cache.requests) }}</strong>
          </article>
          <article>
            <span>实际回源</span>
            <strong>{{ formatNumber(stats.cache.source_loads) }}</strong>
          </article>
          <article>
            <span>合并请求</span>
            <strong>{{ formatNumber(stats.cache.coalesced_requests) }}</strong>
          </article>
          <article>
            <span>缓存条目</span>
            <strong>{{ formatNumber(stats.cache.keys) }}</strong>
          </article>
          <article>
            <span>Redis 内存</span>
            <strong>{{ formatBytes(stats.cache.memory_bytes) }}</strong>
          </article>
        </div>
        <p class="admin-cache-detail">
          读写错误 {{ formatNumber(stats.cache.read_errors + stats.cache.write_errors) }}
          · 已驱逐 {{ formatNumber(stats.cache.evicted_keys) }}
          · 已过期 {{ formatNumber(stats.cache.expired_keys) }}
        </p>
      </section>

      <section class="admin-chart-grid">
        <StatsTrendChart
          title="接口调用趋势"
          :description="`最近 ${stats.period_days} 天请求与错误数量`"
          :dates="dates"
          :series="requestSeries"
        />
        <StatsTrendChart
          title="用户增长趋势"
          :description="`最近 ${stats.period_days} 天活跃与新增用户`"
          :dates="dates"
          :series="userSeries"
        />
      </section>

      <section class="admin-routes-card">
        <header class="admin-card-heading">
          <div>
            <h2>热门接口</h2>
            <p>按统计周期内的调用量排序</p>
          </div>
          <span>{{ stats.top_routes.length }} 个接口</span>
        </header>
        <div v-if="stats.top_routes.length" class="admin-route-table-wrap">
          <table class="admin-route-table">
            <thead>
              <tr>
                <th>接口</th>
                <th>请求量</th>
                <th>错误</th>
                <th>平均耗时</th>
                <th>最大耗时</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="route in stats.top_routes" :key="`${route.method}-${route.route}`">
                <td>
                  <span :class="`admin-method admin-method--${route.method.toLowerCase()}`">{{ route.method }}</span>
                  <code>{{ route.route }}</code>
                </td>
                <td data-label="请求量">{{ formatNumber(route.request_count) }}</td>
                <td data-label="错误" :class="{ 'has-errors': route.error_count > 0 }">
                  {{ formatNumber(route.error_count) }}
                </td>
                <td data-label="平均耗时">{{ formatLatency(route.average_latency_ms) }}</td>
                <td data-label="最大耗时">{{ formatLatency(route.max_latency_ms) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-else class="admin-empty-state">
          <p>暂无接口调用数据</p>
          <span>新部署的统计服务会从现在开始累计。</span>
        </div>
      </section>

          <section class="admin-feedback-card" aria-labelledby="admin-feedback-title">
        <header class="admin-card-heading">
          <div>
            <h2 id="admin-feedback-title">用户反馈</h2>
            <p>最近提交的 50 条反馈，不展示用户身份信息</p>
          </div>
          <span>{{ stats.feedback.length }} 条</span>
        </header>
        <div v-if="stats.feedback.length" class="admin-feedback-list">
          <article v-for="item in stats.feedback" :key="item.id">
            <header>
              <div>
                <span :class="`admin-feedback-type is-${item.type}`">
                  {{ feedbackTypeLabel(item.type) }}
                </span>
                <span class="admin-feedback-platform">{{ item.platform }}</span>
              </div>
              <time :datetime="item.created_at">{{ formatDateTime(item.created_at) }}</time>
            </header>
            <p>{{ item.content }}</p>
          </article>
        </div>
        <div v-else class="admin-empty-state">
          <p>暂无用户反馈</p>
          <span>用户通过“问题反馈”提交后会显示在这里。</span>
        </div>
          </section>
        </template>

        <section v-else class="admin-device-dashboard" aria-labelledby="admin-device-title">
          <header class="admin-dashboard-heading admin-device-heading">
            <div>
              <p class="admin-eyebrow">DEVICES</p>
              <h1 id="admin-device-title">用户设备</h1>
              <p>按账号去重，展示最近一次识别到的移动设备</p>
            </div>
            <button
              type="button"
              class="admin-device-refresh"
              aria-label="刷新设备统计"
              :disabled="loading"
              @click="refreshStats"
            >
              <svg aria-hidden="true" viewBox="0 0 24 24" :class="{ 'is-spinning': loading }">
                <path d="M20 6v5h-5M19 11a7 7 0 1 0 .2 5" />
              </svg>
            </button>
          </header>

          <p v-if="error" class="admin-dashboard-error" role="alert">{{ error }}</p>

          <section class="admin-device-overview" aria-labelledby="admin-device-distribution-title">
            <header class="admin-card-heading">
              <div>
                <h2 id="admin-device-distribution-title">设备分布</h2>
                <p>
                  已识别 {{ formatNumber(deviceTrackedUsers) }} / {{ formatNumber(stats.summary.total_users) }}
                  位用户
                </p>
              </div>
              <span>{{ deviceCoverage.toFixed(1) }}% 覆盖</span>
            </header>

            <div class="admin-device-coverage" aria-hidden="true">
              <span :style="{ width: `${deviceCoverage}%` }" />
            </div>

            <div v-if="deviceTrackedUsers" class="admin-device-distribution">
              <div class="admin-device-ring" :style="deviceChartStyle" aria-hidden="true">
                <div>
                  <strong>{{ formatNumber(deviceTrackedUsers) }}</strong>
                  <span>位用户</span>
                </div>
              </div>
              <div class="admin-device-platforms">
                <article
                  v-for="item in deviceDistribution"
                  :key="item.platform"
                  :class="`is-${item.platform}`"
                >
                  <span class="admin-device-platform-icon" aria-hidden="true">
                    <svg v-if="item.platform === 'ios'" viewBox="0 0 24 24">
                      <rect x="7" y="2.5" width="10" height="19" rx="2.5" />
                      <path d="M10 5h4M11 18.5h2" />
                    </svg>
                    <svg v-else viewBox="0 0 24 24">
                      <path d="m8 6-2-3M16 6l2-3M6 9h12v9.5a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2zM6 11H4v6M18 11h2v6M9 20.5V23M15 20.5V23" />
                      <circle cx="9.5" cy="9" r=".5" fill="currentColor" stroke="none" />
                      <circle cx="14.5" cy="9" r=".5" fill="currentColor" stroke="none" />
                    </svg>
                  </span>
                  <div>
                    <span>{{ item.label }}</span>
                    <strong>{{ item.share.toFixed(1) }}%</strong>
                    <small>{{ formatNumber(item.count) }} 位用户</small>
                  </div>
                </article>
              </div>
            </div>
            <div v-else class="admin-empty-state admin-device-empty">
              <p>暂无设备数据</p>
              <span>用户再次打开应用后会自动完成识别。</span>
            </div>
          </section>

          <section class="admin-device-brands" aria-labelledby="admin-device-brands-title">
            <header class="admin-card-heading">
              <div>
                <h2 id="admin-device-brands-title">品牌分布</h2>
                <p>按已识别用户的最近一次设备统计</p>
              </div>
              <span>{{ brandDistribution.length }} 个品牌</span>
            </header>
            <div v-if="brandDistribution.length" class="admin-device-brand-list">
              <article v-for="item in brandDistribution" :key="item.name">
                <header>
                  <strong>{{ item.name }}</strong>
                  <span>{{ formatNumber(item.count) }} 人 · {{ item.share.toFixed(1) }}%</span>
                </header>
                <div aria-hidden="true"><span :style="{ width: `${item.share}%` }" /></div>
              </article>
            </div>
            <div v-else class="admin-empty-state admin-device-empty">
              <p>暂无品牌数据</p>
              <span>用户再次打开应用后会自动完成识别。</span>
            </div>
          </section>

        </section>
      </section>
    </template>
  </main>
</template>
