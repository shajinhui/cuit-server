import { computed, ref, watch } from 'vue'

import { findCurrentSemester } from '@/shared/models/academic'

import {
  buildCourseBlocks,
  buildTimeSlots,
  buildWeekDates,
  buildWeekOptions,
  dateForWeekday,
  formatDateTitle,
} from '../model/calendar'
import type { useScheduleStore } from '../store'

type ScheduleStore = ReturnType<typeof useScheduleStore>

export function useScheduleCalendar(store: ScheduleStore) {
  const selectedDate = ref(new Date())
  const selectedWeek = ref(0)
  const weekSelectionIsManual = ref(false)

  const dateTitle = computed(() => formatDateTitle(selectedDate.value))
  const weekDates = computed(() => buildWeekDates(selectedDate.value))
  const courses = computed(() =>
    buildCourseBlocks(
      store.table?.Courses,
      selectedWeek.value,
      store.manualCourses.filter((course) => course.semesterID === store.selectedSemesterID),
      store.courseOverrides.filter(
        (courseOverride) => courseOverride.semesterID === store.selectedSemesterID,
      ),
      store.courseColorPreferences.filter(
        (preference) => preference.semesterID === store.selectedSemesterID,
      ),
    ),
  )
  const timeSlots = computed(() => buildTimeSlots(courses.value))
  const isCurrentSemester = computed(
    () => store.selectedSemesterID === findCurrentSemester(store.semesters)?.ID,
  )
  const weekOptions = computed(() =>
    buildWeekOptions(store.table?.WeekCount ?? 0, store.currentWeek, selectedWeek.value),
  )
  const selectedWeekStatus = computed(() => {
    if (store.loading && !store.table) return '同步中'
    if (!isCurrentSemester.value) return '历史学期'
    if (store.currentWeek <= 0) return store.weekError ? '当前周不可用' : ''
    return selectedWeek.value === store.currentWeek ? '本周' : '非本周'
  })
  watch(
    [() => store.table, () => store.currentWeek],
    ([table, currentWeek]) => {
      if (!table || weekSelectionIsManual.value) return
      const nextWeek = isCurrentSemester.value && currentWeek > 0 ? currentWeek : 1
      if (selectedWeek.value !== nextWeek) {
        selectedWeek.value = nextWeek
        selectedDate.value = new Date()
      }
    },
    { immediate: true },
  )

  function selectDay(index: number) {
    selectedDate.value = dateForWeekday(selectedDate.value, index)
  }

  function selectWeek(nextWeek: number) {
    if (!Number.isInteger(nextWeek) || nextWeek < 1 || nextWeek === selectedWeek.value) return

    if (store.currentWeek > 0) {
      const date = new Date(selectedDate.value)
      date.setDate(date.getDate() + (nextWeek - selectedWeek.value) * 7)
      selectedDate.value = date
    }
    selectedWeek.value = nextWeek
    weekSelectionIsManual.value = true
  }

  function resetWeekSelection() {
    weekSelectionIsManual.value = false
    selectedWeek.value = isCurrentSemester.value && store.currentWeek > 0 ? store.currentWeek : 1
    selectedDate.value = new Date()
  }

  return {
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
  }
}
