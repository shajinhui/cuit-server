import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { listSemesters } from '@/shared/api/semesters'
import type { Semester } from '@/shared/models/academic'

import { getCourseTable, getCurrentWeek, type CourseTable } from './api'
import {
  clearScheduleCache,
  readManualCourses,
  readScheduleCache,
  writeManualCourses,
  writeScheduleCache,
  type CachedSchedule,
} from './cache'
import { useScheduleStore } from './store'

vi.mock('@/shared/api/semesters', () => ({ listSemesters: vi.fn() }))
vi.mock('./api', () => ({
  getCourseTable: vi.fn(),
  getCurrentWeek: vi.fn(),
}))
vi.mock('./cache', () => ({
  clearScheduleCache: vi.fn(),
  readManualCourses: vi.fn(),
  readScheduleCache: vi.fn(),
  writeManualCourses: vi.fn(),
  writeScheduleCache: vi.fn(),
}))

const listSemestersMock = vi.mocked(listSemesters)
const getCourseTableMock = vi.mocked(getCourseTable)
const getCurrentWeekMock = vi.mocked(getCurrentWeek)
const clearScheduleCacheMock = vi.mocked(clearScheduleCache)
const readManualCoursesMock = vi.mocked(readManualCourses)
const readScheduleCacheMock = vi.mocked(readScheduleCache)
const writeManualCoursesMock = vi.mocked(writeManualCourses)
const writeScheduleCacheMock = vi.mocked(writeScheduleCache)

const currentSemester: Semester = { ID: 'semester-2', SchoolYear: '2026-2027', Term: '1' }
const previousSemester: Semester = { ID: 'semester-1', SchoolYear: '2025-2026', Term: '2' }

describe('schedule store loading', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    readManualCoursesMock.mockResolvedValue([])
    clearScheduleCacheMock.mockResolvedValue()
    writeManualCoursesMock.mockResolvedValue()
    writeScheduleCacheMock.mockResolvedValue()
    getCurrentWeekMock.mockResolvedValue({ CurrentWeek: 3 })
  })

  it('uses the local table without querying the remote system on page entry', async () => {
    readScheduleCacheMock.mockResolvedValue(createCache(previousSemester, createTable(previousSemester.ID)))
    const store = useScheduleStore()

    await store.load()

    expect(store.selectedSemesterID).toBe(previousSemester.ID)
    expect(listSemestersMock).not.toHaveBeenCalled()
    expect(getCourseTableMock).not.toHaveBeenCalled()
    expect(getCurrentWeekMock).not.toHaveBeenCalled()
  })

  it('queries the remote system when no local table exists', async () => {
    const table = createTable(currentSemester.ID)
    readScheduleCacheMock.mockResolvedValue(null)
    listSemestersMock.mockResolvedValue([currentSemester])
    getCourseTableMock.mockResolvedValue(table)
    const store = useScheduleStore()

    await store.load()

    expect(listSemestersMock).toHaveBeenCalledOnce()
    expect(getCourseTableMock).toHaveBeenCalledWith(currentSemester.ID)
    expect(store.table).toEqual(table)
  })

  it('queries the remote system when the user explicitly refreshes', async () => {
    readScheduleCacheMock.mockResolvedValue(createCache(currentSemester, createTable(currentSemester.ID)))
    listSemestersMock.mockResolvedValue([currentSemester])
    getCourseTableMock.mockResolvedValue(createTable(currentSemester.ID, '刷新后的课程'))
    const store = useScheduleStore()

    await store.load({ refresh: true })

    expect(getCourseTableMock).toHaveBeenCalledWith(currentSemester.ID)
    expect(store.table?.Courses?.[0]?.Name).toBe('刷新后的课程')
  })

  it('queries the selected semester when the user switches away from the cached semester', async () => {
    readScheduleCacheMock.mockResolvedValue(createCache(previousSemester, createTable(previousSemester.ID)))
    listSemestersMock.mockResolvedValue([currentSemester, previousSemester])
    getCourseTableMock.mockResolvedValue(createTable(currentSemester.ID))
    const store = useScheduleStore()

    await store.load({ semesterID: currentSemester.ID })

    expect(getCourseTableMock).toHaveBeenCalledWith(currentSemester.ID)
    expect(store.selectedSemesterID).toBe(currentSemester.ID)
  })
})

function createTable(semesterID: string, courseName = '示例课程'): CourseTable {
  return {
    SemesterID: semesterID,
    WeekCount: 20,
    SectionsPerDay: 11,
    Courses: [
      {
        LessonID: 'lesson-1',
        Code: 'COURSE001',
        Name: courseName,
        Credits: '2',
        Sequence: '',
        TeachingClass: '',
        Teachers: null,
        Activities: [],
      },
    ],
  }
}

function createCache(semester: Semester, table: CourseTable): CachedSchedule {
  return {
    version: 1,
    semesters: [semester],
    selectedSemesterID: semester.ID,
    table,
    currentWeek: 3,
    cachedAt: 1,
  }
}
