<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  AddCourseSheet,
  ScheduleGrid,
  useScheduleCalendar,
  useScheduleStore,
  type ManualCourseInput,
} from '@/features/schedule'
import { useSessionStore } from '@/features/session'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppShell from '@/shared/ui/AppShell.vue'

defineOptions({ name: 'SchedulePage' })

const router = useRouter()
const store = useScheduleStore()
const session = useSessionStore()
const notice = ref('')
const moreMenuOpen = ref(false)
const moreMenuRef = ref<HTMLElement | null>(null)
const addCourseOpen = ref(false)
const addingCourse = ref(false)
const addCourseError = ref('')
let noticeTimer: number | undefined

const {
  cachedAtLabel,
  courses,
  dateTitle,
  resetWeekSelection,
  selectDay,
  selectedDate,
  selectedWeek,
  selectedWeekStatus,
  selectWeek,
  timeSlots,
  weekDates,
  weekOptions,
} = useScheduleCalendar(store)

usePageTheme('#c9d5e7')

onMounted(() => {
  document.addEventListener('pointerdown', closeMoreMenuFromOutside)
  void store.load()
})

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', closeMoreMenuFromOutside)
  window.clearTimeout(noticeTimer)
})

const selectedSemesterLabel = computed(() => {
  const semester = store.semesters.find((item) => item.ID === store.selectedSemesterID)
  return semester ? semesterName(semester.SchoolYear, semester.Term) : '选择学期'
})
const selectedWeekday = computed(() => selectedDate.value.getDay() || 7)

watch(
  () => session.status,
  (status) => {
    if (status === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/schedule' } })
    }
  },
)

function chooseWeek(event: Event) {
  const nextWeek = Number.parseInt((event.target as HTMLSelectElement).value, 10)
  selectWeek(nextWeek)
}

function toggleMoreMenu() {
  moreMenuOpen.value = !moreMenuOpen.value
}

function openAddCourse() {
  if (!store.selectedSemesterID) {
    showNotice('请先加载可用学期')
    return
  }

  moreMenuOpen.value = false
  addCourseError.value = ''
  addCourseOpen.value = true
}

function closeAddCourse() {
  if (!addingCourse.value) addCourseOpen.value = false
}

async function addManualCourse(input: ManualCourseInput) {
  addingCourse.value = true
  addCourseError.value = ''
  try {
    const course = await store.addManualCourse(input)
    addCourseOpen.value = false
    showNotice(`已添加“${course.name}”`)
  } catch (error) {
    addCourseError.value = error instanceof Error ? error.message : '课程保存失败，请稍后重试'
  } finally {
    addingCourse.value = false
  }
}

function closeMoreMenuFromOutside(event: PointerEvent) {
  if (!moreMenuRef.value?.contains(event.target as Node)) {
    moreMenuOpen.value = false
  }
}

async function switchSemester(event: Event) {
  const semesterID = (event.target as HTMLSelectElement).value
  moreMenuOpen.value = false
  if (!semesterID || semesterID === store.selectedSemesterID) return

  await store.load({ semesterID })
  if (store.selectedSemesterID !== semesterID) {
    showNotice(store.syncError || store.error || '学期切换失败')
    return
  }

  resetWeekSelection()
  showNotice(`已切换至${selectedSemesterLabel.value}`)
}

function semesterName(schoolYear: string, term: string) {
  return `${schoolYear} · 第${term}学期`
}

function showNotice(message: string) {
  notice.value = message
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 1800)
}

async function refreshSchedule() {
  await store.load({ refresh: true })
  if (store.error) return
  if (store.syncError) {
    showNotice('网络不可用，继续显示离线课表')
    return
  }
  showNotice(store.weekError ? '课表已更新，教学周暂时不可用' : '课表已更新')
}

</script>

<template>
  <AppShell variant="schedule">
    <section class="schedule-page page-padding">
      <header class="schedule-header">
        <div>
          <h1>{{ dateTitle }}</h1>
          <p class="schedule-week-control">
            <label class="schedule-week-select">
              <select
                :value="selectedWeek || 1"
                aria-label="选择教学周"
                :disabled="store.loading && !store.table"
                @change="chooseWeek"
              >
                <option v-for="week in weekOptions" :key="week" :value="week">第 {{ week }} 周</option>
              </select>
              <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m3 4.5 3 3 3-3" /></svg>
            </label>
            <span v-if="selectedWeekStatus" role="status" :title="store.syncError || store.weekError">
              {{ selectedWeekStatus }}
            </span>
          </p>
        </div>
        <div class="schedule-header__actions" aria-label="课表操作">
          <button
            type="button"
            aria-label="添加课程"
            :disabled="!store.selectedSemesterID"
            @click="openAddCourse"
          >
            ＋
          </button>
          <button
            type="button"
            class="round-action"
            aria-label="重新同步课表"
            :disabled="store.loading"
            @click="refreshSchedule"
          >
            <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 4v11m-4-4 4 4 4-4M5 19h14" /></svg>
          </button>
          <div ref="moreMenuRef" class="schedule-more">
            <button
              type="button"
              class="more-button"
              aria-label="更多操作"
              aria-controls="schedule-more-menu"
              :aria-expanded="moreMenuOpen"
              @click="toggleMoreMenu"
            >
              •••
            </button>
            <Transition name="schedule-more-menu">
              <div
                v-if="moreMenuOpen"
                id="schedule-more-menu"
                class="schedule-more-menu"
                aria-label="更多课表操作"
              >
                <label class="schedule-semester-option">
                  <span>
                    <strong>切换学期</strong>
                    <small>{{ selectedSemesterLabel }}</small>
                  </span>
                  <svg aria-hidden="true" viewBox="0 0 12 12"><path d="m4 2 4 4-4 4" /></svg>
                  <select
                    :value="store.selectedSemesterID"
                    aria-label="切换学期"
                    :disabled="store.loading || store.semesters.length === 0"
                    @change="switchSemester"
                  >
                    <option v-for="semester in store.semesters" :key="semester.ID" :value="semester.ID">
                      {{ semesterName(semester.SchoolYear, semester.Term) }}
                    </option>
                  </select>
                </label>
              </div>
            </Transition>
          </div>
        </div>
      </header>

      <div class="week-strip" :aria-label="`第 ${selectedWeek || 1} 周日期`">
        <div class="week-strip__month">
          <strong>{{ selectedDate.getMonth() + 1 }}</strong>
          <span>月</span>
        </div>
        <button
          v-for="(item, index) in weekDates"
          :key="`${item.label}-${item.date}`"
          type="button"
          :class="{ 'is-active': item.active }"
          @click="selectDay(index)"
        >
          <span>{{ item.label }}</span>
          <strong>{{ item.date }}</strong>
        </button>
      </div>

      <p v-if="store.usingCachedData" class="schedule-offline-status" role="status">
        <strong>离线课表</strong>
        <span>显示 {{ cachedAtLabel }} 保存的数据</span>
      </p>

      <div class="schedule-board">
        <div v-if="store.loading && !store.table" class="schedule-state" aria-live="polite">
          <span class="schedule-state__spinner" aria-hidden="true" />
          <p>正在同步课表…</p>
        </div>

        <div v-else-if="store.error" class="schedule-state schedule-state--error" role="alert">
          <strong>课表加载失败</strong>
          <p>{{ store.error }}</p>
          <button type="button" @click="store.load()">重新加载</button>
        </div>

        <div v-else-if="!store.selectedSemesterID" class="schedule-state">
          <strong>暂无可用学期</strong>
          <p>教务系统暂未返回学期信息。</p>
        </div>

        <ScheduleGrid v-else :courses="courses" :selected-week="selectedWeek" :time-slots="timeSlots" />
      </div>

      <AddCourseSheet
        :open="addCourseOpen"
        :selected-week="selectedWeek || 1"
        :selected-weekday="selectedWeekday"
        :week-count="store.table?.WeekCount ?? 0"
        :sections-per-day="store.table?.SectionsPerDay ?? 11"
        :saving="addingCourse"
        :error="addCourseError"
        @close="closeAddCourse"
        @submit="addManualCourse"
      />

      <Transition name="toast">
        <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
      </Transition>
    </section>
  </AppShell>
</template>
