<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  classroomTitle,
  formatSections,
  groupClassroomsByBuilding,
  useClassroomsStore,
} from '@/features/classrooms'
import { useSessionStore } from '@/features/session'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'ClassroomsPage' })

const router = useRouter()
const store = useClassroomsStore()
const session = useSessionStore()
const advancedOpen = ref(false)
const advancedTriggerRef = ref<HTMLButtonElement | null>(null)
const sheetRef = ref<HTMLElement | null>(null)
let bodyOverflowBeforeSheet = ''

const weekOptions = Array.from({ length: 53 }, (_, index) => index + 1)
const weekdays = [
  { value: 1, short: '一', label: '周一' },
  { value: 2, short: '二', label: '周二' },
  { value: 3, short: '三', label: '周三' },
  { value: 4, short: '四', label: '周四' },
  { value: 5, short: '五', label: '周五' },
  { value: 6, short: '六', label: '周六' },
  { value: 7, short: '日', label: '周日' },
]
const sectionPairs = [1, 3, 5, 7, 9, 11]

usePageTheme('#f2f2f7')

const groupedRooms = computed(() => groupClassroomsByBuilding(store.rooms))
const scheduleBusy = computed(() => store.loadingResults || store.refreshingSchedule)
const canSearch = computed(
  () =>
    Boolean(store.selectedSemesterID && store.selectedCampusID && store.sections.length) &&
    !store.loadingOptions &&
    !scheduleBusy.value,
)
const advancedSummary = computed(() => {
  const campus = store.campuses.find((item) => item.ID === store.selectedCampusID)?.Name
  const weekday = weekdays.find((item) => item.value === store.weekday)?.label
  const building = store.buildings.find((item) => item.ID === store.selectedBuildingID)?.Name
  const type = store.classroomTypes.find((item) => item.ID === store.selectedClassroomTypeID)?.Name
  const capacity = store.minCapacity === '' ? '' : `${store.minCapacity} 人起`
  return [campus, `第 ${store.week} 周`, weekday, building, type, capacity]
    .filter(Boolean)
    .join(' · ')
})
const resultContext = computed(() => {
  const context = store.lastQueryContext
  if (!context) return ''
  const weekday = weekdays.find((item) => item.value === context.weekday)?.label || `星期${context.weekday}`
  return `${context.campusName} · 第 ${context.week} 周 ${weekday} · ${formatSections(context.sections)}`
})
const cachedAtLabel = computed(() => {
  if (!store.scheduleCachedAt) return ''
  return new Intl.DateTimeFormat('zh-CN', {
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(store.scheduleCachedAt)
})

onMounted(() => {
  void store.initialize()
})

onBeforeUnmount(() => {
  document.body.style.overflow = bodyOverflowBeforeSheet
})

watch(
  () => session.status,
  (status) => {
    if (status === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/classrooms' } })
    }
  },
)

watch(advancedOpen, async (open) => {
  if (open) {
    bodyOverflowBeforeSheet = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    await nextTick()
    sheetRef.value?.focus()
    return
  }
  document.body.style.overflow = bodyOverflowBeforeSheet
})

async function chooseSemester(event: Event) {
  await store.changeSemester((event.target as HTMLSelectElement).value)
  await store.loadBuildings()
}

async function chooseCampus(event: Event) {
  await store.changeCampus((event.target as HTMLSelectElement).value)
  await store.loadBuildings()
}

function pairSelected(pairStart: number) {
  return store.sections.includes(pairStart) && store.sections.includes(pairStart + 1)
}

function openAdvancedFilters() {
  advancedOpen.value = true
  if (store.buildings.length === 0) {
    void store.loadBuildings()
  }
}

async function closeAdvancedFilters(restoreFocus = true) {
  advancedOpen.value = false
  if (restoreFocus) {
    await nextTick()
    advancedTriggerRef.value?.focus()
  }
}

function handleSheetKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    void closeAdvancedFilters()
    return
  }
  if (event.key !== 'Tab' || !sheetRef.value) return

  const focusable = [...sheetRef.value.querySelectorAll<HTMLElement>('button, select, input, [tabindex]:not([tabindex="-1"])')]
    .filter((element) => !element.hasAttribute('disabled'))
  const first = focusable[0]
  const last = focusable.at(-1)
  if (!first || !last) return

  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}
</script>

<template>
  <main class="classroom-page">
    <header class="classroom-topbar">
      <button
        type="button"
        class="classroom-icon-button"
        aria-label="返回工具页"
        @click="router.push({ name: 'tools' })"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <h1>空教室</h1>
      <span aria-hidden="true" />
    </header>

    <section class="classroom-content">
      <div v-if="store.initializing && !store.initialized" class="classroom-state" aria-live="polite">
        <span class="classroom-spinner" aria-hidden="true" />
        <p>正在准备查询条件…</p>
      </div>

      <div
        v-else-if="store.initializationError && !store.initialized"
        class="classroom-state classroom-state--error"
        role="alert"
      >
        <span class="classroom-state__icon" aria-hidden="true">!</span>
        <h2>暂时无法读取查询条件</h2>
        <p>{{ store.initializationError }}</p>
        <button type="button" @click="store.initialize(true)">重新读取</button>
      </div>

      <div v-else-if="store.semesters.length === 0" class="classroom-state">
        <span class="classroom-state__empty-mark" aria-hidden="true">—</span>
        <h2>暂无可用学期</h2>
        <p>教务系统返回学期后即可查询空教室。</p>
      </div>

      <template v-else>
        <section class="classroom-filter-card" aria-label="空教室查询条件">
          <fieldset class="classroom-section-picker">
            <legend>
              <span>节次</span>
              <small>{{ formatSections(store.sections) }}</small>
            </legend>
            <div>
              <button
                v-for="pairStart in sectionPairs"
                :key="pairStart"
                type="button"
                :class="{ 'is-selected': pairSelected(pairStart) }"
                :aria-pressed="pairSelected(pairStart)"
                :aria-label="`第 ${pairStart} 至 ${pairStart + 1} 节`"
                :disabled="scheduleBusy"
                @click="store.togglePair(pairStart)"
              >
                {{ pairStart }}–{{ pairStart + 1 }}
              </button>
            </div>
          </fieldset>

          <button
            ref="advancedTriggerRef"
            type="button"
            class="classroom-advanced-trigger"
            aria-haspopup="dialog"
            :aria-expanded="advancedOpen"
            @click="openAdvancedFilters"
          >
            <span>
              <strong>更多筛选</strong>
              <small>{{ advancedSummary }}</small>
            </span>
            <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m4 2 4 4-4 4" /></svg>
          </button>

          <p v-if="store.optionsError" class="classroom-inline-error" role="alert">
            {{ store.optionsError }}
            <button type="button" @click="store.loadBuildings">重试</button>
          </p>
          <p v-if="store.resultError && !store.hasSearched" class="classroom-inline-error" role="alert">
            {{ store.resultError }}
          </p>

          <button type="button" class="classroom-search-button" :disabled="!canSearch" @click="store.search()">
            <span v-if="store.loadingResults" class="classroom-button-spinner" aria-hidden="true" />
            <span>{{ store.loadingResults ? '正在查询…' : '查询空教室' }}</span>
          </button>
        </section>

        <section class="classroom-results" aria-labelledby="classroom-results-title">
          <header class="classroom-results-heading">
            <div>
              <h2 id="classroom-results-title">
                {{ store.hasSearched && !store.loadingResults ? `找到 ${store.rooms.length} 间` : '查询结果' }}
              </h2>
              <p v-if="resultContext">{{ resultContext }}</p>
            </div>
            <div class="classroom-results-heading__status">
              <span v-if="store.loadingResults" role="status">正在准备学期数据…</span>
              <template v-else-if="store.hasSearched && cachedAtLabel">
                <span>{{ store.usingCachedSchedule ? '本地数据' : '已缓存' }} · {{ cachedAtLabel }}</span>
                <button
                  type="button"
                  :disabled="store.refreshingSchedule"
                  @click="store.refreshSchedule"
                >
                  {{ store.refreshingSchedule ? '更新中…' : '更新' }}
                </button>
              </template>
            </div>
          </header>

          <p v-if="store.refreshError" class="classroom-result-notice is-error" role="alert">
            {{ store.refreshError }}
          </p>
          <p v-else-if="store.cacheNotice" class="classroom-result-notice" role="status">
            {{ store.cacheNotice }}
          </p>

          <div v-if="store.loadingResults" class="classroom-skeleton-list" aria-hidden="true">
            <div v-for="index in 3" :key="index">
              <span />
              <span />
            </div>
          </div>

          <div v-else-if="store.resultError" class="classroom-result-state classroom-result-state--error" role="alert">
            <span aria-hidden="true">!</span>
            <h3>查询没有完成</h3>
            <p>{{ store.resultError }}</p>
            <button type="button" @click="store.search()">重新查询</button>
          </div>

          <div v-else-if="groupedRooms.length" class="classroom-groups">
            <section v-for="group in groupedRooms" :key="group.building" class="classroom-group">
              <header>
                <h3>{{ group.building }}</h3>
                <span>{{ group.rooms.length }} 间</span>
              </header>
              <div class="classroom-list">
                <article v-for="room in group.rooms" :key="room.ID" class="classroom-row">
                  <div>
                    <h4>{{ classroomTitle(room) }}</h4>
                    <p>{{ room.Type || '教室类型未提供' }}</p>
                  </div>
                  <p class="classroom-capacity">
                    <strong>{{ room.Capacity || '—' }}</strong>
                    <span>人</span>
                  </p>
                </article>
              </div>
            </section>
          </div>

          <div v-else-if="store.hasSearched" class="classroom-result-state">
            <span class="classroom-state__empty-mark" aria-hidden="true">—</span>
            <h3>没有符合条件的空教室</h3>
            <p>可以尝试取消教学楼、教室类型或最低容量限制。</p>
            <button type="button" @click="openAdvancedFilters">调整筛选</button>
          </div>

          <div v-else class="classroom-result-state classroom-result-state--initial">
            <span class="classroom-result-state__lines" aria-hidden="true"><i /><i /><i /></span>
            <h3>确认条件后开始查询</h3>
            <p>首次会保存本学期教室数据，之后的筛选将在本机快速完成。</p>
          </div>
        </section>
      </template>
    </section>

    <Transition name="classroom-sheet">
      <div v-if="advancedOpen" class="classroom-sheet-overlay" @click.self="closeAdvancedFilters()">
        <section
          ref="sheetRef"
          class="classroom-sheet"
          role="dialog"
          aria-modal="true"
          aria-labelledby="classroom-sheet-title"
          tabindex="-1"
          @keydown="handleSheetKeydown"
        >
          <div class="classroom-sheet__handle" aria-hidden="true" />
          <header>
            <span aria-hidden="true" />
            <h2 id="classroom-sheet-title">筛选条件</h2>
            <button type="button" class="is-primary" @click="closeAdvancedFilters()">完成</button>
          </header>

          <div class="classroom-sheet__body">
            <p class="classroom-sheet__section-title">时间与校区</p>
            <div class="classroom-sheet__fields classroom-sheet__fields--primary">
              <label>
                <span>学期</span>
                <span class="classroom-select-control">
                  <select
                    :value="store.selectedSemesterID"
                    aria-label="选择学期"
                    :disabled="store.loadingOptions || scheduleBusy"
                    @change="chooseSemester"
                  >
                    <option v-for="semester in store.semesters" :key="semester.ID" :value="semester.ID">
                      {{ semester.SchoolYear }} · 第{{ semester.Term }}学期
                    </option>
                  </select>
                  <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m3 4.5 3 3 3-3" /></svg>
                </span>
              </label>

              <div class="classroom-sheet__pair">
                <label>
                  <span>教学周</span>
                  <span class="classroom-select-control">
                    <select v-model.number="store.week" aria-label="选择教学周" :disabled="scheduleBusy">
                      <option v-for="week in weekOptions" :key="week" :value="week">第 {{ week }} 周</option>
                    </select>
                    <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m3 4.5 3 3 3-3" /></svg>
                  </span>
                </label>

                <label>
                  <span>校区</span>
                  <span class="classroom-select-control">
                    <select
                      :value="store.selectedCampusID"
                      aria-label="选择校区"
                      :disabled="store.loadingOptions || scheduleBusy"
                      @change="chooseCampus"
                    >
                      <option v-for="campus in store.campuses" :key="campus.ID" :value="campus.ID">
                        {{ campus.Name }}
                      </option>
                    </select>
                    <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m3 4.5 3 3 3-3" /></svg>
                  </span>
                </label>
              </div>

              <fieldset class="classroom-weekday-picker classroom-sheet__weekday">
                <legend>星期</legend>
                <div>
                  <button
                    v-for="day in weekdays"
                    :key="day.value"
                    type="button"
                    :class="{ 'is-selected': store.weekday === day.value }"
                    :aria-pressed="store.weekday === day.value"
                    :aria-label="day.label"
                    :disabled="scheduleBusy"
                    @click="store.weekday = day.value"
                  >
                    {{ day.short }}
                  </button>
                </div>
              </fieldset>
            </div>

            <p class="classroom-sheet__section-title">教室偏好</p>
            <div class="classroom-sheet__fields">
              <label>
                <span>教学楼</span>
                <span class="classroom-select-control">
                  <select
                    v-model="store.selectedBuildingID"
                    aria-label="选择教学楼"
                    :disabled="store.loadingOptions || scheduleBusy"
                  >
                    <option value="">全部教学楼</option>
                    <option v-for="building in store.buildings" :key="building.ID" :value="building.ID">
                      {{ building.Name }}
                    </option>
                  </select>
                  <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m3 4.5 3 3 3-3" /></svg>
                </span>
              </label>

              <label>
                <span>教室类型</span>
                <span class="classroom-select-control">
                  <select
                    v-model="store.selectedClassroomTypeID"
                    aria-label="选择教室类型"
                    :disabled="scheduleBusy"
                  >
                    <option value="">全部类型</option>
                    <option v-for="type in store.classroomTypes" :key="type.ID" :value="type.ID">
                      {{ type.Name }}
                    </option>
                  </select>
                  <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m3 4.5 3 3 3-3" /></svg>
                </span>
              </label>

              <label>
                <span>最低容量</span>
                <span class="classroom-capacity-input">
                  <input
                    v-model.number="store.minCapacity"
                    type="number"
                    min="0"
                    step="1"
                    inputmode="numeric"
                    placeholder="不限"
                    aria-label="最低容纳人数"
                    :disabled="scheduleBusy"
                  />
                  <small>人</small>
                </span>
              </label>
            </div>

            <p class="classroom-sheet__note">教学楼、教室类型和最低容量可以留空。</p>
          </div>
        </section>
      </div>
    </Transition>
  </main>
</template>
