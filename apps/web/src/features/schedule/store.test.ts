import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { listSemesters } from '@/shared/api/semesters'
import type { Semester } from '@/shared/models/academic'

import { getCourseTable, getCurrentWeek, type CourseTable } from './api'
import {
  clearScheduleCache,
  readCourseColorPreferences,
  readCourseOverrides,
  readManualCourses,
  readScheduleCache,
  writeCourseColorPreferences,
  writeCourseOverrides,
  writeManualCourses,
  writeScheduleCache,
  type CachedSchedule,
} from './cache'
import { useScheduleStore } from './store'
import type { ManualCourse, ManualCourseInput } from './model/manualCourse'

vi.mock('@/shared/api/semesters', () => ({ listSemesters: vi.fn() }))
vi.mock('./api', () => ({
  getCourseTable: vi.fn(),
  getCurrentWeek: vi.fn(),
}))
vi.mock('./cache', () => ({
  clearScheduleCache: vi.fn(),
  readCourseColorPreferences: vi.fn(),
  readCourseOverrides: vi.fn(),
  readManualCourses: vi.fn(),
  readScheduleCache: vi.fn(),
  writeCourseColorPreferences: vi.fn(),
  writeCourseOverrides: vi.fn(),
  writeManualCourses: vi.fn(),
  writeScheduleCache: vi.fn(),
}))

const listSemestersMock = vi.mocked(listSemesters)
const getCourseTableMock = vi.mocked(getCourseTable)
const getCurrentWeekMock = vi.mocked(getCurrentWeek)
const clearScheduleCacheMock = vi.mocked(clearScheduleCache)
const readCourseColorPreferencesMock = vi.mocked(readCourseColorPreferences)
const readCourseOverridesMock = vi.mocked(readCourseOverrides)
const readManualCoursesMock = vi.mocked(readManualCourses)
const readScheduleCacheMock = vi.mocked(readScheduleCache)
const writeManualCoursesMock = vi.mocked(writeManualCourses)
const writeCourseColorPreferencesMock = vi.mocked(writeCourseColorPreferences)
const writeCourseOverridesMock = vi.mocked(writeCourseOverrides)
const writeScheduleCacheMock = vi.mocked(writeScheduleCache)

const currentSemester: Semester = { ID: 'semester-2', SchoolYear: '2026-2027', Term: '1' }
const previousSemester: Semester = { ID: 'semester-1', SchoolYear: '2025-2026', Term: '2' }

describe('schedule store loading', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    readCourseOverridesMock.mockResolvedValue([])
    readCourseColorPreferencesMock.mockResolvedValue([])
    readManualCoursesMock.mockResolvedValue([])
    clearScheduleCacheMock.mockResolvedValue()
    writeManualCoursesMock.mockResolvedValue()
    writeCourseColorPreferencesMock.mockResolvedValue()
    writeCourseOverridesMock.mockResolvedValue()
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

  it('removes a manual course from local persistence and state', async () => {
    readScheduleCacheMock.mockResolvedValue(null)
    const store = useScheduleStore()
    const course = createManualCourse()
    store.manualCourses = [course]
    store.manualCoursesLoaded = true

    const removedCourse = await store.removeManualCourse(course.id)

    expect(writeManualCoursesMock).toHaveBeenCalledWith([])
    expect(removedCourse).toEqual(course)
    expect(store.manualCourses).toEqual([])
  })

  it('keeps a manual course in state when local persistence fails', async () => {
    readScheduleCacheMock.mockResolvedValue(null)
    writeManualCoursesMock.mockRejectedValueOnce(new Error('write failed'))
    const store = useScheduleStore()
    const course = createManualCourse()
    store.manualCourses = [course]
    store.manualCoursesLoaded = true

    await expect(store.removeManualCourse(course.id)).rejects.toThrow('write failed')

    expect(store.manualCourses).toEqual([course])
  })

  it('updates a manual course without changing its local identity', async () => {
    const store = useScheduleStore()
    const course = createManualCourse()
    store.selectedSemesterID = currentSemester.ID
    store.manualCourses = [course]

    const updated = await store.updateCourse(
      {
        id: course.id,
        source: 'manual',
        name: course.name,
        room: course.room,
        weekday: course.weekday,
        startSection: course.startSection,
        endSection: course.endSection,
        weeks: course.weeks,
      },
      createManualCourseInput({ name: '修改后的课程', room: 'H2201' }),
    )

    expect(updated).toMatchObject({
      id: course.id,
      name: '修改后的课程',
      room: 'H2201',
    })
    expect(writeManualCoursesMock).toHaveBeenCalledWith([updated])
  })

  it('persists an original course edit as a local override', async () => {
    const store = useScheduleStore()
    store.selectedSemesterID = currentSemester.ID

    const updated = await store.updateCourse(
      {
        id: 'lesson-1-1-1-2',
        source: 'jwxt',
        name: '原始课程',
        room: 'H2101',
        weekday: 1,
        startSection: 1,
        endSection: 2,
        weeks: [1, 2],
      },
      createManualCourseInput({ name: '本机名称', weekday: 3 }),
    )

    expect(updated).toMatchObject({
      targetID: 'lesson-1-1-1-2',
      semesterID: currentSemester.ID,
      name: '本机名称',
      weekday: 3,
    })
    expect(writeCourseOverridesMock).toHaveBeenCalledWith([updated])
  })

  it('persists and restores a custom course color for the selected semester', async () => {
    const store = useScheduleStore()
    store.selectedSemesterID = currentSemester.ID

    await store.setCourseColor('course-1', 'muted-coral')

    expect(writeCourseColorPreferencesMock).toHaveBeenLastCalledWith([
      {
        semesterID: currentSemester.ID,
        courseKey: 'course-1',
        tone: 'muted-coral',
      },
    ])
    expect(store.courseColorPreferences).toEqual([
      {
        semesterID: currentSemester.ID,
        courseKey: 'course-1',
        tone: 'muted-coral',
      },
    ])

    await store.setCourseColor('course-1', null)

    expect(writeCourseColorPreferencesMock).toHaveBeenLastCalledWith([])
    expect(store.courseColorPreferences).toEqual([])
  })

  it('keeps the previous course color when local persistence fails', async () => {
    writeCourseColorPreferencesMock.mockRejectedValueOnce(new Error('write failed'))
    const store = useScheduleStore()
    store.selectedSemesterID = currentSemester.ID
    store.courseColorPreferences = [
      {
        semesterID: currentSemester.ID,
        courseKey: 'course-1',
        tone: 'haze-blue',
      },
    ]

    await expect(store.setCourseColor('course-1', 'muted-coral')).rejects.toThrow('write failed')

    expect(store.courseColorPreferences[0]?.tone).toBe('haze-blue')
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

function createManualCourse(): ManualCourse {
  return {
    id: 'manual-1',
    semesterID: currentSemester.ID,
    name: '本机课程',
    room: 'H2101',
    weekday: 1,
    startSection: 1,
    endSection: 2,
    weeks: [1, 2, 3],
  }
}

function createManualCourseInput(
  overrides: Partial<ManualCourseInput> = {},
): ManualCourseInput {
  return {
    name: '本机课程',
    room: 'H2101',
    weekday: 1,
    startSection: 1,
    endSection: 2,
    startWeek: 1,
    endWeek: 3,
    repeat: 'weekly',
    ...overrides,
  }
}
