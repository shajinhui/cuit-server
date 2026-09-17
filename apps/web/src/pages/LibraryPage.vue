<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  formatLibraryDateTime,
  getLibraryCaptcha,
  getLibrarySeatMap,
  librarySeatPosition,
  libraryDate,
  reservationLocation,
  ruleSummary,
  seatTitle,
  type LibraryKind,
  type LibraryReservation,
  type LibrarySeat,
  useLibraryStore,
} from '@/features/library'
import LibrarySeatMap from '@/features/library/components/LibrarySeatMap.vue'
import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppSelect from '@/shared/ui/AppSelect.vue'
import HamsterLoader from '@/shared/ui/HamsterLoader.vue'

defineOptions({ name: 'LibraryPage' })

type PageTab = LibraryKind | 'reservations'
type ReservationAction = 'cancel' | 'finish' | 'temporary-leave'
type SeatViewMode = 'map' | 'list'

const router = useRouter()
const store = useLibraryStore()
const session = useSessionStore()
const activeTab = ref<PageTab>('seat')
const selectedSeat = ref<LibrarySeat | null>(null)
const memo = ref('')
const captcha = ref('')
const captchaURL = ref('')
const captchaLoading = ref(false)
const captchaError = ref('')
const submitError = ref('')
const actionTarget = ref<LibraryReservation | null>(null)
const actionType = ref<ReservationAction>('cancel')
const actionError = ref('')
const toast = ref('')
const seatMapURL = ref('')
const seatMapRoomID = ref('')
const seatMapLoading = ref(false)
const seatMapError = ref('')
const seatViewMode = ref<SeatViewMode>('list')
let seatMapRequestVersion = 0
let toastTimer: number | undefined

usePageTheme('#f2f2f7')

const areaOptions = computed(() =>
  store.areaOptions.map((area) => ({
    value: area.value,
    label: area.total > 0 ? `${area.label} · 余 ${area.available}/${area.total}` : area.label,
  })),
)
const regularDateMaximum = computed(() => libraryDate(1))
const queryValid = computed(() => {
  if (!store.selectedRoomID || !store.startDate) return false
  if (store.kind === 'study') return Boolean(store.endDate && store.endDate >= store.startDate)
  return Boolean(store.startTime && store.endTime && store.endTime > store.startTime)
})
const availableCount = computed(
  () => store.seats.filter((seat) => seat.Status === 'available' && !seat.OnlyView).length,
)
const hasPositionedSeats = computed(() =>
  store.seats.some((seat) => librarySeatPosition(seat.Coordinate) !== null),
)
const seatMapAvailable = computed(
  () =>
    store.kind === 'seat' &&
    Boolean(seatMapURL.value) &&
    seatMapRoomID.value === store.selectedRoomID &&
    hasPositionedSeats.value,
)
const resultTitle = computed(() => {
  if (activeTab.value === 'study') return '自修室列表'
  return seatViewMode.value === 'map' ? '座位平面图' : '座位列表'
})
const modalTimeLabel = computed(() => {
  if (store.kind === 'study') return `${store.startDate} 至 ${store.endDate}`
  return `${store.startDate} · ${store.startTime}–${store.endTime}`
})
const actionCopy = computed(() => {
  const copies = {
    cancel: { title: '取消这次预约？', detail: '取消后座位会重新释放，请确认已不再需要。', button: '确认取消' },
    finish: { title: '提前结束预约？', detail: '结束后无法恢复，本次使用时长将按当前时间结算。', button: '确认结束' },
    'temporary-leave': {
      title: '登记暂离？',
      detail: '请在图书馆规定时间内返回并重新签到，逾期可能产生违约记录。',
      button: '确认暂离',
    },
  }
  return copies[actionType.value]
})

onMounted(() => {
  void store.initialize()
})

onBeforeUnmount(() => {
  revokeCaptchaURL()
  clearSeatMap()
  window.clearTimeout(toastTimer)
})

watch(
  () => session.status,
  (status) => {
    if (status === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/library' } })
    }
  },
)

watch(
  () => store.startDate,
  (startDate) => {
    if (store.endDate < startDate) store.endDate = startDate
    store.resetSeats()
  },
)

watch(
  () => [store.endDate, store.startTime, store.endTime],
  () => store.resetSeats(),
)

watch(
  () => store.selectedRoomID,
  () => {
    store.resetSeats()
    clearSeatMap()
  },
)

async function chooseTab(tab: PageTab) {
  activeTab.value = tab
  if (tab === 'reservations') {
    await store.loadReservations()
    return
  }
  clearSeatMap()
  await store.changeKind(tab)
}

function chooseArea(value: string | number) {
  store.selectedRoomID = String(value)
}

async function refresh() {
  if (activeTab.value === 'reservations') {
    await store.loadReservations()
  } else if (store.hasSearched) {
    await searchSeats()
  } else {
    await store.loadAreas()
  }
}

async function searchSeats() {
  const roomID = store.selectedRoomID
  const searched = await store.searchSeats()
  if (!searched || roomID !== store.selectedRoomID) return
  if (store.kind !== 'seat' || !hasPositionedSeats.value) {
    clearSeatMap()
    return
  }
  await loadSeatMap(roomID)
}

async function loadSeatMap(roomID: string) {
  if (seatMapURL.value && seatMapRoomID.value === roomID) return
  const version = ++seatMapRequestVersion
  seatMapLoading.value = true
  seatMapError.value = ''
  try {
    const blob = await getLibrarySeatMap(roomID)
    if (version !== seatMapRequestVersion || roomID !== store.selectedRoomID) return
    revokeSeatMapURL()
    seatMapURL.value = URL.createObjectURL(blob)
    seatMapRoomID.value = roomID
    seatViewMode.value = 'map'
    session.markAuthenticated()
  } catch (error) {
    if (version !== seatMapRequestVersion) return
    if (error instanceof ApiError && error.status === 401) session.markAnonymous()
    seatMapError.value = error instanceof Error ? error.message : '平面图读取失败，已显示座位列表'
    seatViewMode.value = 'list'
  } finally {
    if (version === seatMapRequestVersion) seatMapLoading.value = false
  }
}

async function openReservation(seat: LibrarySeat) {
  if (seat.Status !== 'available' || seat.OnlyView) return
  selectedSeat.value = seat
  memo.value = ''
  captcha.value = ''
  submitError.value = ''
  if (store.capabilities?.CaptchaMode === 'image') await refreshCaptcha()
}

function closeReservation() {
  if (store.mutating) return
  selectedSeat.value = null
  submitError.value = ''
  revokeCaptchaURL()
}

async function refreshCaptcha() {
  revokeCaptchaURL()
  captchaLoading.value = true
  captchaError.value = ''
  captcha.value = ''
  try {
    const blob = await getLibraryCaptcha()
    captchaURL.value = URL.createObjectURL(blob)
  } catch (error) {
    captchaError.value = error instanceof Error ? error.message : '验证码读取失败'
  } finally {
    captchaLoading.value = false
  }
}

async function submitReservation() {
  if (!selectedSeat.value || store.mutating) return
  if (store.capabilities?.CaptchaMode === 'interactive') {
    openOfficialPage()
    return
  }
  submitError.value = ''
  try {
    const result = await store.create(selectedSeat.value.ID, memo.value, captcha.value)
    selectedSeat.value = null
    revokeCaptchaURL()
    showToast(result.Message || '预约成功')
  } catch (error) {
    submitError.value = error instanceof Error ? error.message : '预约提交失败'
    if (store.capabilities?.CaptchaMode === 'image') await refreshCaptcha()
  }
}

function requestAction(reservation: LibraryReservation, action: ReservationAction) {
  actionTarget.value = reservation
  actionType.value = action
  actionError.value = ''
}

function closeAction() {
  if (store.mutating) return
  actionTarget.value = null
  actionError.value = ''
}

async function confirmAction() {
  if (!actionTarget.value || store.mutating) return
  actionError.value = ''
  try {
    const result =
      actionType.value === 'cancel'
        ? await store.cancel(actionTarget.value)
        : actionType.value === 'finish'
          ? await store.finish(actionTarget.value)
          : await store.temporaryLeave(actionTarget.value)
    actionTarget.value = null
    showToast(result.Message)
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : '操作失败，请稍后重试'
  }
}

function openOfficialPage() {
  const url = store.capabilities?.OfficialURL
  if (!url) return
  const opened = window.open(url, '_blank', 'noopener,noreferrer')
  if (!opened) window.location.assign(url)
}

function showToast(message: string) {
  toast.value = message || '操作成功'
  window.clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => (toast.value = ''), 2200)
}

function revokeCaptchaURL() {
  if (captchaURL.value) URL.revokeObjectURL(captchaURL.value)
  captchaURL.value = ''
}

function revokeSeatMapURL() {
  if (seatMapURL.value) URL.revokeObjectURL(seatMapURL.value)
  seatMapURL.value = ''
  seatMapRoomID.value = ''
}

function clearSeatMap() {
  seatMapRequestVersion += 1
  seatMapLoading.value = false
  seatMapError.value = ''
  seatViewMode.value = 'list'
  revokeSeatMapURL()
}

function seatStatusLabel(seat: LibrarySeat) {
  if (seat.OnlyView || seat.Status === 'unavailable') return '不可预约'
  if (seat.Status === 'reserved') return '时段占用'
  return '可预约'
}

// 与图书馆状态位保持一致：16 为违约、512 为审核未通过。
function reservationIsDanger(status: number) {
  return (status & 16) !== 0 || (status & 512) !== 0
}
</script>

<template>
  <main class="library-page">
    <header class="library-topbar">
      <button type="button" class="library-icon-button" aria-label="返回工具页" @click="router.push({ name: 'tools' })">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <h1>图书馆预约</h1>
      <button
        type="button"
        class="library-icon-button"
        aria-label="刷新预约信息"
        :disabled="store.initializing || store.loadingSeats || store.loadingReservations"
        @click="refresh"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24" :class="{ 'is-spinning': store.loadingSeats || store.loadingReservations }">
          <path d="M19 8a7.5 7.5 0 1 0 .15 7.7" />
          <path d="M19 4v4h-4" />
        </svg>
      </button>
    </header>

    <nav class="library-tabs" aria-label="预约类型">
      <button
        v-for="tab in [
          { value: 'seat', label: '座位' },
          { value: 'study', label: '自修室' },
          { value: 'reservations', label: '我的预约' },
        ]"
        :key="tab.value"
        type="button"
        :class="{ 'is-selected': activeTab === tab.value }"
        :aria-pressed="activeTab === tab.value"
        @click="chooseTab(tab.value as PageTab)"
      >
        {{ tab.label }}
      </button>
    </nav>

    <section class="library-content">
      <div v-if="store.initializing && !store.initialized" class="library-page-state">
        <HamsterLoader label="正在连接图书馆预约系统…" />
      </div>

      <div v-else-if="store.initializationError && !store.initialized" class="library-page-state library-page-state--error" role="alert">
        <span class="library-state-mark" aria-hidden="true">!</span>
        <h2>暂时无法连接</h2>
        <p>{{ store.initializationError }}</p>
        <button type="button" @click="store.initialize(true)">重新连接</button>
      </div>

      <template v-else-if="activeTab !== 'reservations'">
        <section class="library-filter-card" aria-label="座位查询条件">
          <label class="library-field library-field--full">
            <span>预约区域</span>
            <AppSelect
              :model-value="store.selectedRoomID"
              :options="areaOptions"
              :title="activeTab === 'seat' ? '选择座位区域' : '选择自修室'"
              :disabled="store.loadingAreas"
              @change="chooseArea"
            />
          </label>

          <p v-if="store.areaError" class="library-inline-error" role="alert">{{ store.areaError }}</p>

          <div class="library-date-grid">
            <label class="library-field">
              <span>{{ activeTab === 'study' ? '开始日期' : '预约日期' }}</span>
              <input
                v-model="store.startDate"
                type="date"
                :min="libraryDate()"
                :max="activeTab === 'seat' ? regularDateMaximum : undefined"
              />
            </label>
            <label v-if="activeTab === 'study'" class="library-field">
              <span>结束日期</span>
              <input v-model="store.endDate" type="date" :min="store.startDate" />
            </label>
            <template v-else>
              <label class="library-field">
                <span>开始时间</span>
                <input v-model="store.startTime" type="time" step="1800" />
              </label>
              <label class="library-field">
                <span>结束时间</span>
                <input v-model="store.endTime" type="time" step="1800" />
              </label>
            </template>
          </div>

          <p class="library-filter-note">
            {{
              activeTab === 'seat'
                ? '普通座位以图书馆实时规则为准，通常可预约当天或次日。'
                : '自修室按连续日期预约，资格与最长天数由图书馆实时校验。'
            }}
          </p>

          <button
            type="button"
            class="library-primary-button"
            :disabled="!queryValid || store.loadingSeats"
            @click="searchSeats"
          >
            {{ store.loadingSeats ? '正在查询…' : '查询可预约座位' }}
          </button>
        </section>

        <section v-if="store.hasSearched || store.loadingSeats" class="library-results" aria-live="polite">
          <header>
            <div>
              <h2>{{ resultTitle }}</h2>
              <p>{{ store.selectedAreaLabel }}</p>
            </div>
            <strong v-if="store.hasSearched">{{ availableCount }} 个可约</strong>
          </header>

          <nav v-if="seatMapAvailable" class="library-view-switch" aria-label="座位显示方式">
            <button
              type="button"
              :class="{ 'is-selected': seatViewMode === 'map' }"
              :aria-pressed="seatViewMode === 'map'"
              @click="seatViewMode = 'map'"
            >
              平面图
            </button>
            <button
              type="button"
              :class="{ 'is-selected': seatViewMode === 'list' }"
              :aria-pressed="seatViewMode === 'list'"
              @click="seatViewMode = 'list'"
            >
              列表
            </button>
          </nav>

          <div v-if="store.loadingSeats && !store.hasSearched" class="library-list-loader">
            <HamsterLoader label="正在读取座位…" />
          </div>
          <div v-else-if="store.seatError" class="library-list-message library-list-message--error" role="alert">
            <p>{{ store.seatError }}</p>
            <button type="button" @click="searchSeats">重试</button>
          </div>
          <div v-else-if="store.seats.length === 0" class="library-list-message">
            <span aria-hidden="true">—</span>
            <h3>这个时段暂无可用座位</h3>
            <p>可以调整区域或时间后再次查询。</p>
          </div>
          <div v-else-if="seatMapLoading" class="library-map-loading" role="status">正在加载座位平面图…</div>
          <LibrarySeatMap
            v-else-if="seatMapAvailable && seatViewMode === 'map'"
            :image-url="seatMapURL"
            :seats="store.seats"
            @select="openReservation"
          />
          <template v-else>
            <p v-if="seatMapError && activeTab === 'seat'" class="library-map-fallback">
              {{ seatMapError }}，可继续使用列表预约。
            </p>
            <div class="library-seat-grid">
              <button
                v-for="seat in store.seats"
                :key="seat.ID"
                type="button"
                class="library-seat-card"
                :class="`is-${seat.Status}`"
                :disabled="seat.Status !== 'available' || seat.OnlyView"
                @click="openReservation(seat)"
              >
                <span class="library-seat-card__number">{{ seatTitle(seat) }}</span>
                <span class="library-seat-card__location">{{ [seat.Building, seat.Room].filter(Boolean).join(' · ') || '当前区域' }}</span>
                <span class="library-seat-card__status">{{ seatStatusLabel(seat) }}</span>
              </button>
            </div>
          </template>
        </section>
      </template>

      <section v-else class="library-reservations" aria-live="polite">
        <div v-if="store.loadingReservations && !store.reservationsLoaded" class="library-list-loader">
          <HamsterLoader label="正在读取预约记录…" />
        </div>
        <div v-else-if="store.reservationError" class="library-list-message library-list-message--error" role="alert">
          <p>{{ store.reservationError }}</p>
          <button type="button" @click="store.loadReservations">重新读取</button>
        </div>
        <div v-else-if="store.reservations.length === 0" class="library-list-message library-list-message--card">
          <span aria-hidden="true">—</span>
          <h2>暂无预约记录</h2>
          <p>预约成功后，会在这里显示签到状态与可用操作。</p>
        </div>
        <template v-else>
          <article v-for="reservation in store.reservations" :key="`${reservation.Kind}-${reservation.UUID}`" class="library-reservation-card">
            <header>
              <span>{{ reservation.Kind === 'seat' ? '普通座位' : '自修室' }}</span>
              <strong :class="{ 'is-danger': reservationIsDanger(reservation.Status) }">{{ reservation.StatusLabel }}</strong>
            </header>
            <h2>{{ reservation.Name || reservation.Seat || '图书馆预约' }}</h2>
            <p>{{ reservationLocation(reservation) }}</p>
            <dl>
              <div>
                <dt>开始</dt>
                <dd>{{ formatLibraryDateTime(reservation.Start) }}</dd>
              </div>
              <div>
                <dt>结束</dt>
                <dd>{{ formatLibraryDateTime(reservation.End) }}</dd>
              </div>
            </dl>
            <p v-if="reservation.TemporaryLeaveUntil" class="library-leave-note">暂离截止：{{ formatLibraryDateTime(reservation.TemporaryLeaveUntil) }}</p>
            <p v-if="reservation.ViolationReason" class="library-violation-note">{{ reservation.ViolationReason }}</p>
            <footer v-if="reservation.CanCancel || reservation.CanTemporaryLeave || reservation.CanFinish">
              <button v-if="reservation.CanTemporaryLeave" type="button" @click="requestAction(reservation, 'temporary-leave')">暂离</button>
              <button v-if="reservation.CanFinish" type="button" @click="requestAction(reservation, 'finish')">提前结束</button>
              <button v-if="reservation.CanCancel" type="button" class="is-danger" @click="requestAction(reservation, 'cancel')">取消预约</button>
            </footer>
          </article>
        </template>
      </section>
    </section>

    <Transition name="library-modal">
      <div v-if="selectedSeat" class="library-modal-backdrop" role="presentation" @click.self="closeReservation">
        <section class="library-modal" role="dialog" aria-modal="true" aria-labelledby="library-reserve-title">
          <div class="library-modal__handle" aria-hidden="true" />
          <header>
            <div>
              <span>{{ activeTab === 'seat' ? '确认座位预约' : '确认自修室预约' }}</span>
              <h2 id="library-reserve-title">{{ seatTitle(selectedSeat) }}</h2>
            </div>
            <button type="button" aria-label="关闭" :disabled="store.mutating" @click="closeReservation">×</button>
          </header>
          <div class="library-confirm-summary">
            <p>{{ [selectedSeat.Building, selectedSeat.Room].filter(Boolean).join(' · ') || store.selectedAreaLabel }}</p>
            <strong>{{ modalTimeLabel }}</strong>
            <small v-if="ruleSummary(selectedSeat.Rule)">{{ ruleSummary(selectedSeat.Rule) }}</small>
          </div>

          <label v-if="store.capabilities?.MemoRequired || store.capabilities?.MemoMaximumLength" class="library-modal-field">
            <span>预约用途{{ store.capabilities?.MemoRequired ? '（必填）' : '（选填）' }}</span>
            <textarea
              v-model="memo"
              rows="2"
              :maxlength="store.capabilities?.MemoMaximumLength || undefined"
              placeholder="简要说明本次用途"
            />
          </label>

          <div v-if="store.capabilities?.CaptchaMode === 'image'" class="library-captcha-row">
            <label class="library-modal-field">
              <span>图形验证码</span>
              <input v-model="captcha" type="text" inputmode="text" autocomplete="off" placeholder="输入右侧字符" />
            </label>
            <button type="button" :disabled="captchaLoading" aria-label="刷新验证码" @click="refreshCaptcha">
              <span v-if="captchaLoading">读取中</span>
              <img v-else-if="captchaURL" :src="captchaURL" alt="图形验证码，点击刷新" />
              <span v-else>重新读取</span>
            </button>
          </div>
          <p v-if="captchaError" class="library-inline-error" role="alert">{{ captchaError }}</p>

          <div v-if="store.capabilities?.CaptchaMode === 'interactive'" class="library-verification-note">
            <strong>需要官方交互验证</strong>
            <p>图书馆当前启用了交互式验证，请在官方页面完成这次预约。</p>
          </div>

          <p v-if="submitError" class="library-inline-error" role="alert">{{ submitError }}</p>
          <button
            type="button"
            class="library-primary-button"
            :disabled="
              store.mutating ||
              (store.capabilities?.CaptchaMode === 'image' && !captcha.trim()) ||
              (store.capabilities?.MemoRequired && !memo.trim())
            "
            @click="submitReservation"
          >
            {{
              store.mutating
                ? '正在提交…'
                : store.capabilities?.CaptchaMode === 'interactive'
                  ? '前往官方预约页'
                  : '确认预约'
            }}
          </button>
          <p class="library-modal__footnote">提交即表示你已确认日期、时段及图书馆预约规则。</p>
        </section>
      </div>
    </Transition>

    <Transition name="library-modal">
      <div v-if="actionTarget" class="library-modal-backdrop" role="presentation" @click.self="closeAction">
        <section class="library-modal library-modal--compact" role="alertdialog" aria-modal="true" aria-labelledby="library-action-title">
          <div class="library-modal__handle" aria-hidden="true" />
          <h2 id="library-action-title">{{ actionCopy.title }}</h2>
          <p>{{ actionCopy.detail }}</p>
          <p v-if="actionError" class="library-inline-error" role="alert">{{ actionError }}</p>
          <div class="library-action-buttons">
            <button type="button" :disabled="store.mutating" @click="closeAction">先不操作</button>
            <button
              type="button"
              :class="{ 'is-danger': actionType === 'cancel' }"
              :disabled="store.mutating"
              @click="confirmAction"
            >
              {{ store.mutating ? '处理中…' : actionCopy.button }}
            </button>
          </div>
        </section>
      </div>
    </Transition>

    <Transition name="library-toast">
      <div v-if="toast" class="library-toast" role="status">{{ toast }}</div>
    </Transition>
  </main>
</template>
