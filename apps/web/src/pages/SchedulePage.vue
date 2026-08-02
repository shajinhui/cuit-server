<script setup lang="ts">
import { computed, nextTick, onActivated, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  AddCourseSheet,
  CourseDetailSheet,
  ScheduleGrid,
  useScheduleCalendar,
  useScheduleStore,
  type CourseBlock,
  type CourseEditTarget,
  type CourseSlotCourse,
  type CourseTone,
  type ManualCourseInput,
} from '@/features/schedule'
import { useSessionStore } from '@/features/session'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppSelect from '@/shared/ui/AppSelect.vue'
import AppShell from '@/shared/ui/AppShell.vue'

defineOptions({ name: 'SchedulePage' })

const router = useRouter()
const store = useScheduleStore()
const session = useSessionStore()
const notice = ref('')
const moreMenuOpen = ref(false)
const semesterListOpen = ref(false)
const moreMenuRef = ref<HTMLElement | null>(null)
const addCourseOpen = ref(false)
const addingCourse = ref(false)
const addCourseError = ref('')
const editingCourse = ref<CourseEditTarget | null>(null)
const selectedCourse = ref<CourseBlock | null>(null)
const removingCourse = ref(false)
const removeCourseError = ref('')
const savingCourseColor = ref(false)
const courseColorError = ref('')
let noticeTimer: number | undefined

const {
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
  resetWeekSelection()
  void store.load()
})

onActivated(resetWeekSelection)

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', closeMoreMenuFromOutside)
  window.clearTimeout(noticeTimer)
})

const selectedSemesterLabel = computed(() => {
  const semester = store.semesters.find((item) => item.ID === store.selectedSemesterID)
  return semester ? semesterName(semester.SchoolYear, semester.Term) : '选择学期'
})
const selectedWeekday = computed(() => selectedDate.value.getDay() || 7)
const currentWeekLabel = computed(() =>
  store.currentWeek > 0 ? `当前为第 ${store.currentWeek} 周` : '',
)
const weekSelectOptions = computed(() =>
  weekOptions.value.map((week) => ({ value: week, label: `第 ${week} 周` })),
)
const customColorKeys = computed(() =>
  store.courseColorPreferences
    .filter((preference) => preference.semesterID === store.selectedSemesterID)
    .map((preference) => preference.courseKey),
)

watch(
  () => session.status,
  (status) => {
    if (status === 'anonymous') {
      void router.replace({ name: 'login', query: { redirect: '/schedule' } })
    }
  },
)

function chooseWeek(value: string | number) {
  selectWeek(Number(value))
}

function toggleMoreMenu() {
  moreMenuOpen.value = !moreMenuOpen.value
  if (!moreMenuOpen.value) semesterListOpen.value = false
}

function toggleSemesterList() {
  if (store.loading || store.semesters.length === 0) return
  semesterListOpen.value = !semesterListOpen.value
}

function openAddCourse() {
  if (!store.selectedSemesterID) {
    showNotice('请先加载可用学期')
    return
  }

  closeMoreMenu()
  addCourseError.value = ''
  editingCourse.value = null
  addCourseOpen.value = true
}

function closeAddCourse() {
  if (addingCourse.value) return
  addCourseOpen.value = false
  editingCourse.value = null
}

function openCourseDetails(course: CourseBlock) {
  removeCourseError.value = ''
  courseColorError.value = ''
  selectedCourse.value = course
}

function closeCourseDetails() {
  if (removingCourse.value || savingCourseColor.value) return
  removeCourseError.value = ''
  courseColorError.value = ''
  selectedCourse.value = null
}

function openCourseEditor(course: CourseSlotCourse) {
  const courseBlock = selectedCourse.value
  if (!courseBlock) return

  editingCourse.value = {
    id: course.id,
    source: course.source,
    name: course.name,
    room: course.room,
    weekday: courseBlock.day,
    startSection: courseBlock.start,
    endSection: courseBlock.start + courseBlock.span - 1,
    weeks: [...course.weeks],
  }
  selectedCourse.value = null
  removeCourseError.value = ''
  addCourseError.value = ''
  addCourseOpen.value = true
}

async function saveCourse(input: ManualCourseInput) {
  addingCourse.value = true
  addCourseError.value = ''
  try {
    const course = editingCourse.value
      ? await store.updateCourse(editingCourse.value, input)
      : await store.addManualCourse(input)
    const action = editingCourse.value ? '已修改' : '已添加'
    addCourseOpen.value = false
    editingCourse.value = null
    showNotice(`${action}“${course.name}”`)
  } catch (error) {
    addCourseError.value = error instanceof Error ? error.message : '课程保存失败，请稍后重试'
  } finally {
    addingCourse.value = false
  }
}

async function removeManualCourse(courseID: string) {
  removingCourse.value = true
  removeCourseError.value = ''
  try {
    const removedCourse = await store.removeManualCourse(courseID)
    if (!removedCourse) {
      removeCourseError.value = '没有找到这门本机课程'
      return
    }
    selectedCourse.value = null
    showNotice(`已删除“${removedCourse.name}”`)
  } catch (error) {
    removeCourseError.value = error instanceof Error ? error.message : '课程删除失败，请稍后重试'
  } finally {
    removingCourse.value = false
  }
}

async function setCourseColor(course: CourseSlotCourse, tone: CourseTone | null) {
  const existingPreference = store.courseColorPreferences.find(
    (preference) =>
      preference.semesterID === store.selectedSemesterID &&
      preference.courseKey === course.colorKey,
  )
  if (existingPreference?.tone === tone || (!existingPreference && tone === null)) return

  const selectedCourseID = selectedCourse.value?.id
  savingCourseColor.value = true
  courseColorError.value = ''
  try {
    await store.setCourseColor(course.colorKey, tone)
    await nextTick()
    selectedCourse.value =
      courses.value.find((courseBlock) => courseBlock.id === selectedCourseID) ??
      selectedCourse.value
  } catch (error) {
    courseColorError.value =
      error instanceof Error ? error.message : '课程颜色保存失败，请稍后重试'
  } finally {
    savingCourseColor.value = false
  }
}

function closeMoreMenuFromOutside(event: PointerEvent) {
  if (!moreMenuRef.value?.contains(event.target as Node)) {
    closeMoreMenu()
  }
}

function closeMoreMenu() {
  moreMenuOpen.value = false
  semesterListOpen.value = false
}

async function switchSemester(semesterID: string) {
  closeMoreMenu()
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
          <div class="schedule-date-line">
            <h1>{{ dateTitle }}</h1>
            <span
              v-if="currentWeekLabel"
              class="schedule-current-week"
              :class="{ 'is-browsing': selectedWeek !== store.currentWeek }"
            >
              {{ currentWeekLabel }}
            </span>
          </div>
          <p class="schedule-week-control">
            <AppSelect
              class="schedule-week-select"
              :model-value="selectedWeek || 1"
              :options="weekSelectOptions"
              title="选择教学周"
              aria-label="选择教学周"
              :disabled="store.loading && !store.table"
              @change="chooseWeek"
            />
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
            <svg aria-hidden="true" viewBox="0 0 24 24">
              <path d="M12 5v14M5 12h14" />
            </svg>
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
              <svg aria-hidden="true" viewBox="0 0 18 6">
                <circle cx="3" cy="3" r="1.5" />
                <circle cx="9" cy="3" r="1.5" />
                <circle cx="15" cy="3" r="1.5" />
              </svg>
            </button>
            <Transition name="schedule-more-menu">
              <div
                v-if="moreMenuOpen"
                id="schedule-more-menu"
                class="schedule-more-menu"
                aria-label="更多课表操作"
              >
                <button
                  type="button"
                  class="schedule-semester-option"
                  aria-controls="schedule-semester-list"
                  :aria-expanded="semesterListOpen"
                  :disabled="store.loading || store.semesters.length === 0"
                  @click="toggleSemesterList"
                >
                  <span>
                    <strong>切换学期</strong>
                    <small>{{ selectedSemesterLabel }}</small>
                  </span>
                  <svg
                    aria-hidden="true"
                    viewBox="0 0 12 12"
                    :class="{ 'is-open': semesterListOpen }"
                  >
                    <path d="m4 2 4 4-4 4" />
                  </svg>
                </button>

                <div
                  v-if="semesterListOpen"
                  id="schedule-semester-list"
                  class="schedule-semester-list"
                  role="listbox"
                  aria-label="选择学期"
                >
                  <button
                    v-for="semester in store.semesters"
                    :key="semester.ID"
                    type="button"
                    class="schedule-semester-list__item"
                    role="option"
                    :aria-selected="semester.ID === store.selectedSemesterID"
                    :class="{ 'is-selected': semester.ID === store.selectedSemesterID }"
                    :disabled="store.loading"
                    @click="switchSemester(semester.ID)"
                  >
                    <span>{{ semesterName(semester.SchoolYear, semester.Term) }}</span>
                    <svg
                      v-if="semester.ID === store.selectedSemesterID"
                      aria-hidden="true"
                      viewBox="0 0 16 16"
                    >
                      <path d="m3.5 8.5 3 3 6-7" />
                    </svg>
                  </button>
                </div>
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

        <ScheduleGrid
          v-else
          :courses="courses"
          :selected-week="selectedWeek"
          :time-slots="timeSlots"
          @select="openCourseDetails"
        />
      </div>

      <CourseDetailSheet
        :course="selectedCourse"
        :removing="removingCourse"
        :remove-error="removeCourseError"
        :saving-color="savingCourseColor"
        :color-error="courseColorError"
        :custom-color-keys="customColorKeys"
        @close="closeCourseDetails"
        @edit="openCourseEditor"
        @remove="removeManualCourse"
        @color="setCourseColor"
      />

      <AddCourseSheet
        :open="addCourseOpen"
        :selected-week="selectedWeek || 1"
        :selected-weekday="selectedWeekday"
        :week-count="store.table?.WeekCount ?? 0"
        :sections-per-day="store.table?.SectionsPerDay ?? 11"
        :saving="addingCourse"
        :error="addCourseError"
        :initial-course="editingCourse"
        @close="closeAddCourse"
        @submit="saveCourse"
      />

      <Transition name="toast">
        <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
      </Transition>
    </section>
  </AppShell>
</template>
