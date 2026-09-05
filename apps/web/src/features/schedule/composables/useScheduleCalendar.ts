import { computed, ref, watch, type Ref } from 'vue'

import { calendarForSemester, schoolSemesterForDate } from '../model/semesterCalendar'

import {
  buildCourseBlocks,
  buildTimeSlots,
  buildWeekDates,
  buildWeekOptions,
  dateForSemesterWeek,
  dateForWeekday,
  formatDateTitle,
  scheduleCampusFromName,
} from '../model/calendar'
import type { useScheduleStore } from '../store'

type ScheduleStore = ReturnType<typeof useScheduleStore>

export function useScheduleCalendar(
  store: ScheduleStore,
  campusName?: Readonly<Ref<string | undefined>>,
) {
  const selectedDate = ref(new Date())
  const today = ref(new Date())
  const selectedWeek = ref(0)
  const weekSelectionIsManual = ref(false)

  const hasSemesterCalendar = computed(() => !!calendarForSemester(selectedSemester.value))
  const dateTitle = computed(() =>
    hasSemesterCalendar.value ? formatDateTitle(selectedDate.value) : '校历日期待更新',
  )
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
  const timeSlots = computed(() =>
    buildTimeSlots(courses.value, scheduleCampusFromName(campusName?.value), selectedSemester.value),
  )
  const isCurrentSemester = computed(() => {
    const current = schoolSemesterForDate(today.value)
    return selectedSemester.value?.SchoolYear === current.SchoolYear &&
      selectedSemester.value?.Term === current.Term
  })
  const selectedSemester = computed(() =>
    store.semesters.find((semester) => semester.ID === store.selectedSemesterID),
  )
  const weekOptions = computed(() =>
    buildWeekOptions(
      store.table?.WeekCount || calendarForSemester(selectedSemester.value)?.weekCount || 0,
      isCurrentSemester.value ? store.currentWeek : 0,
      selectedWeek.value,
    ),
  )
  const selectedWeekStatus = computed(() => {
    if (store.loading && !store.table) return '同步中'
    if (!hasSemesterCalendar.value) return '校历待更新'
    if (!isCurrentSemester.value) {
      const firstDay = dateForSemesterWeek(selectedSemester.value, 1, 1)
      return firstDay && firstDay > today.value ? '未来学期' : '历史学期'
    }
    if (store.currentWeek <= 0) return store.weekError ? '当前周不可用' : '非教学周'
    return selectedWeek.value === store.currentWeek ? '本周' : '非本周'
  })
  watch(
    [() => store.table, () => store.currentWeek],
    ([table, currentWeek]) => {
      if (!table || weekSelectionIsManual.value) return
      const nextWeek = isCurrentSemester.value && currentWeek > 0 ? currentWeek : 1
      selectedWeek.value = nextWeek
      selectedDate.value = dateInSelectedSemester(nextWeek)
    },
    { immediate: true },
  )

  function selectDay(index: number) {
    selectedDate.value = dateForWeekday(selectedDate.value, index)
  }

  function selectWeek(nextWeek: number) {
    if (!Number.isInteger(nextWeek) || nextWeek < 1 || nextWeek === selectedWeek.value) return

    const weekday = selectedDate.value.getDay() || 7
    const semesterDate = dateForSemesterWeek(selectedSemester.value, nextWeek, weekday)
    if (semesterDate) {
      selectedDate.value = semesterDate
    }
    selectedWeek.value = nextWeek
    weekSelectionIsManual.value = true
  }

  function resetWeekSelection() {
    today.value = new Date()
    store.updateLocalCurrentWeek()
    weekSelectionIsManual.value = false
    const nextWeek = isCurrentSemester.value && store.currentWeek > 0 ? store.currentWeek : 1
    selectedWeek.value = nextWeek
    selectedDate.value = dateInSelectedSemester(nextWeek)
  }

  function dateInSelectedSemester(week: number) {
    const today = new Date()
    const weekday = today.getDay() || 7
    return dateForSemesterWeek(selectedSemester.value, week, weekday) ?? today
  }

  return {
    courses,
    dateTitle,
    hasSemesterCalendar,
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
