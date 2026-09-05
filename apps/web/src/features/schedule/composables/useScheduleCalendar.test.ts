import { createPinia, setActivePinia } from 'pinia'
import { effectScope, nextTick, ref, type EffectScope } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type { Semester } from '@/shared/models/academic'

import { useScheduleStore } from '../store'
import { useScheduleCalendar } from './useScheduleCalendar'

const autumn: Semester = { ID: 'autumn', SchoolYear: '2026-2027', Term: '1' }
const spring: Semester = { ID: 'spring', SchoolYear: '2026-2027', Term: '2' }
const history: Semester = { ID: 'history', SchoolYear: '2025-2026', Term: '2', Current: true }
let scope: EffectScope

describe('schedule calendar selection', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.useFakeTimers()
    vi.setSystemTime(new Date(2026, 8, 13, 12))
    scope = effectScope()
  })

  afterEach(() => {
    scope.stop()
    vi.useRealTimers()
  })

  function createCalendar(semester = autumn) {
    const store = useScheduleStore()
    store.semesters = [autumn, spring, history, semester]
    store.selectedSemesterID = semester.ID
    store.table = { SemesterID: semester.ID, WeekCount: 20, SectionsPerDay: 12, Courses: [] }
    store.updateLocalCurrentWeek()
    const campus = ref<string | undefined>()
    const calendar = scope.run(() => useScheduleCalendar(store, campus))
    if (!calendar) throw new Error('calendar scope unavailable')
    return { store, campus, calendar }
  }

  it('ignores a stale cached Current marker and starts on the current teaching week', () => {
    const { calendar } = createCalendar()
    expect(calendar.selectedWeek.value).toBe(1)
    expect(calendar.selectedWeekStatus.value).toBe('本周')
    expect(calendar.dateTitle.value).toBe('2026/9/13')
    expect(calendar.weekDates.value.map((day) => day.date)).toEqual([7, 8, 9, 10, 11, 12, 13])
  })

  it('maps spring week choices to February without using the current autumn date', () => {
    const { calendar } = createCalendar(spring)
    calendar.selectDay(0)
    expect(calendar.dateTitle.value).toBe('2027/2/22')
    expect(calendar.selectedWeekStatus.value).toBe('未来学期')
    calendar.selectWeek(2)
    expect(calendar.dateTitle.value).toBe('2027/3/1')
  })

  it('keeps a manual selection during reactive updates and resets it when returning next Monday', async () => {
    const { store, calendar } = createCalendar()
    calendar.selectWeek(5)
    store.table = { ...store.table!, Courses: [] }
    await nextTick()
    expect(calendar.selectedWeek.value).toBe(5)
    vi.setSystemTime(new Date(2026, 8, 14, 8))
    calendar.resetWeekSelection()
    await nextTick()
    expect(store.currentWeek).toBe(2)
    expect(calendar.selectedWeek.value).toBe(2)
    expect(calendar.dateTitle.value).toBe('2026/9/14')
  })

  it('updates times when cached campus information arrives and uses unified times in the new term', async () => {
    const { store, campus, calendar } = createCalendar(history)
    expect(calendar.timeSlots.value[0]).toEqual(['08:20', '09:05'])
    campus.value = '龙泉校区'
    expect(calendar.timeSlots.value[0]).toEqual(['08:30', '09:15'])
    store.selectedSemesterID = autumn.ID
    store.table = { SemesterID: autumn.ID, WeekCount: 19, SectionsPerDay: 12, Courses: [] }
    await nextTick()
    expect(calendar.timeSlots.value[0]).toEqual(['08:20', '09:05'])
    expect(calendar.dateTitle.value).toBe('2026/9/13')
  })

  it('keeps week navigation usable without inventing dates for an unpublished calendar', () => {
    const { calendar } = createCalendar({ ID: 'unknown', SchoolYear: '2030-2031', Term: '2' })
    calendar.selectWeek(3)
    expect(calendar.selectedWeek.value).toBe(3)
    expect(calendar.hasSemesterCalendar.value).toBe(false)
    expect(calendar.dateTitle.value).toBe('校历日期待更新')
    expect(calendar.selectedWeekStatus.value).toBe('校历待更新')
  })
})
