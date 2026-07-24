import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { getCurrentWeek } from '@/shared/api/currentWeek'
import { listSemesters } from '@/shared/api/semesters'
import type { Semester } from '@/shared/models/academic'

import {
  getClassroomSchedule,
  getClassroomOptions,
  type ClassroomSchedule,
} from './api'
import {
  readClassroomInitializationCache,
  readClassroomScheduleCache,
  writeClassroomInitializationCache,
  writeClassroomScheduleCache,
} from './cache'
import { defaultWeekday } from './model'
import { useClassroomsStore } from './store'

vi.mock('@/shared/api/currentWeek', () => ({ getCurrentWeek: vi.fn() }))
vi.mock('@/shared/api/semesters', () => ({ listSemesters: vi.fn() }))
vi.mock('./api', () => ({
  getClassroomSchedule: vi.fn(),
  getClassroomOptions: vi.fn(),
}))
vi.mock('./cache', () => ({
  readClassroomInitializationCache: vi.fn(),
  readClassroomScheduleCache: vi.fn(),
  writeClassroomInitializationCache: vi.fn(),
  writeClassroomScheduleCache: vi.fn(),
}))

const getCurrentWeekMock = vi.mocked(getCurrentWeek)
const listSemestersMock = vi.mocked(listSemesters)
const getClassroomOptionsMock = vi.mocked(getClassroomOptions)
const getClassroomScheduleMock = vi.mocked(getClassroomSchedule)
const readClassroomInitializationCacheMock = vi.mocked(readClassroomInitializationCache)
const readClassroomScheduleCacheMock = vi.mocked(readClassroomScheduleCache)
const writeClassroomInitializationCacheMock = vi.mocked(writeClassroomInitializationCache)
const writeClassroomScheduleCacheMock = vi.mocked(writeClassroomScheduleCache)

const currentSemester: Semester = { ID: '1106', SchoolYear: '2025-2026', Term: '1' }
const previousSemester: Semester = { ID: '905', SchoolYear: '2024-2025', Term: '2' }
const classroomSchedule: ClassroomSchedule = {
  SemesterID: currentSemester.ID,
  CampusID: '1',
  Rooms: [
    {
      Classroom: {
        ID: '67',
        Code: 'H2101',
        Name: 'H2101',
        Building: '第二教学楼',
        Campus: '航空港',
        Type: '多媒体',
        Capacity: 166,
      },
      Occupancies: [],
    },
    {
      Classroom: {
        ID: '68',
        Code: 'H2102',
        Name: 'H2102',
        Building: '第二教学楼',
        Campus: '航空港',
        Type: '智慧教室',
        Capacity: 80,
      },
      Occupancies: [
        { Weekday: 3, StartSection: 1, EndSection: 4, Weeks: [8] },
      ],
    },
  ],
}

describe('classrooms store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    listSemestersMock.mockResolvedValue([previousSemester, currentSemester])
    getCurrentWeekMock.mockResolvedValue({ CurrentWeek: 8 })
    getClassroomOptionsMock.mockImplementation(async (_semesterID, campusID = '') => ({
      Campuses: [{ ID: '1', Name: '航空港' }],
      ClassroomTypes: [{ ID: '2', Name: '多媒体' }],
      Buildings: campusID ? [{ ID: '3', Name: '第二教学楼' }] : [],
    }))
    getClassroomScheduleMock.mockResolvedValue(classroomSchedule)
    readClassroomInitializationCacheMock.mockResolvedValue(null)
    readClassroomScheduleCacheMock.mockResolvedValue(null)
    writeClassroomInitializationCacheMock.mockResolvedValue()
    writeClassroomScheduleCacheMock.mockImplementation(async (schedule, cachedAt) => ({
      version: 1,
      semesterID: schedule.SemesterID,
      campusID: schedule.CampusID,
      schedule,
      cachedAt: cachedAt ?? Date.now(),
    }))
  })

  it('defaults to the current semester, current week, today and the aviation campus', async () => {
    const store = useClassroomsStore()
    store.campuses = [
      { ID: '2', Name: '龙泉' },
      { ID: '1', Name: '航空港' },
      { ID: '22', Name: '芯谷' },
    ]

    await store.initialize()

    expect(store.selectedSemesterID).toBe(currentSemester.ID)
    expect(store.week).toBe(8)
    expect(store.weekday).toBe(defaultWeekday())
    expect(store.selectedCampusID).toBe('1')
    expect(store.campuses).toEqual([
      { ID: '2', Name: '龙泉' },
      { ID: '1', Name: '航空港' },
      { ID: '22', Name: '芯谷' },
    ])
    expect(getClassroomOptionsMock).not.toHaveBeenCalled()
    expect(writeClassroomInitializationCacheMock).toHaveBeenCalledWith({
      semesters: [currentSemester, previousSemester],
      selectedSemesterID: currentSemester.ID,
      currentWeek: 8,
      selectedCampusID: '1',
    })
  })

  it('restores query conditions and the semester snapshot without network access', async () => {
    const cachedAt = new Date('2026-07-24T09:00:00+08:00').getTime()
    readClassroomInitializationCacheMock.mockResolvedValue({
      version: 1,
      semesters: [currentSemester, previousSemester],
      selectedSemesterID: currentSemester.ID,
      currentWeek: 8,
      selectedCampusID: '1',
      cachedAt,
    })
    readClassroomScheduleCacheMock.mockResolvedValue({
      version: 1,
      semesterID: currentSemester.ID,
      campusID: '1',
      schedule: classroomSchedule,
      cachedAt,
    })
    const store = useClassroomsStore()

    await store.initialize()
    await store.search()

    expect(store.initialized).toBe(true)
    expect(store.initializationError).toBe('')
    expect(store.selectedSemesterID).toBe(currentSemester.ID)
    expect(store.currentWeek).toBe(8)
    expect(store.selectedCampusID).toBe('1')
    expect(store.classroomSchedule).toEqual(classroomSchedule)
    expect(store.usingCachedSchedule).toBe(true)
    expect(store.buildings).toEqual([{ ID: '第二教学楼', Name: '第二教学楼' }])
    expect(store.hasSearched).toBe(true)
    expect(listSemestersMock).not.toHaveBeenCalled()
    expect(getCurrentWeekMock).not.toHaveBeenCalled()
    expect(getClassroomScheduleMock).not.toHaveBeenCalled()
  })

  it('loads campus-dependent buildings only when requested', async () => {
    const store = useClassroomsStore()
    await store.initialize()

    await store.loadBuildings()

    expect(getClassroomOptionsMock).toHaveBeenCalledWith(currentSemester.ID, '1')
    expect(store.buildings).toEqual([{ ID: '3', Name: '第二教学楼' }])
  })

  it('does not apply the public current week to a historical semester', async () => {
    const store = useClassroomsStore()
    await store.initialize()

    await store.changeSemester(previousSemester.ID)

    expect(store.selectedSemesterID).toBe(previousSemester.ID)
    expect(store.week).toBe(1)
    expect(store.hasSearched).toBe(false)
  })

  it('downloads one semester snapshot and applies selected filters locally', async () => {
    const store = useClassroomsStore()
    await store.initialize()
    store.weekday = 3
    store.sections = [1, 2, 3, 4]
    store.buildings = [{ ID: '3', Name: '第二教学楼' }]
    store.selectedBuildingID = '3'
    store.selectedClassroomTypeID = '2'
    store.minCapacity = 100

    await store.search()

    expect(getClassroomScheduleMock).toHaveBeenCalledWith(currentSemester.ID, '1')
    expect(writeClassroomScheduleCacheMock).toHaveBeenCalledOnce()
    expect(store.rooms.map((room) => room.ID)).toEqual(['67'])
    expect(store.hasSearched).toBe(true)
    expect(store.resultError).toBe('')
  })

  it('reuses the local semester snapshot without querying the backend again', async () => {
    const cachedAt = new Date('2026-07-24T09:00:00+08:00').getTime()
    readClassroomScheduleCacheMock.mockResolvedValue({
      version: 1,
      semesterID: currentSemester.ID,
      campusID: '1',
      schedule: classroomSchedule,
      cachedAt,
    })
    const store = useClassroomsStore()
    await store.initialize()

    await store.search()
    store.weekday = 4
    await store.search()

    expect(readClassroomScheduleCacheMock).toHaveBeenCalledOnce()
    expect(getClassroomScheduleMock).not.toHaveBeenCalled()
    expect(store.usingCachedSchedule).toBe(true)
    expect(store.scheduleCachedAt).toBe(cachedAt)
  })

  it('only refreshes the cached semester snapshot when explicitly requested', async () => {
    const store = useClassroomsStore()
    await store.initialize()
    await store.search()

    await store.refreshSchedule()

    expect(getClassroomScheduleMock).toHaveBeenCalledTimes(2)
    expect(writeClassroomScheduleCacheMock).toHaveBeenCalledTimes(2)
  })

  it('requests another snapshot after switching semesters', async () => {
    getClassroomScheduleMock.mockImplementation(async (semesterID, campusID) => ({
      ...classroomSchedule,
      SemesterID: semesterID,
      CampusID: campusID,
    }))
    const store = useClassroomsStore()
    await store.initialize()
    await store.search()

    await store.changeSemester(previousSemester.ID)
    await store.search()

    expect(getClassroomScheduleMock).toHaveBeenNthCalledWith(1, currentSemester.ID, '1')
    expect(getClassroomScheduleMock).toHaveBeenNthCalledWith(2, previousSemester.ID, '1')
  })

  it('marks the session anonymous when the backend rejects classroom access', async () => {
    const store = useClassroomsStore()
    await store.initialize()
    getClassroomOptionsMock.mockRejectedValue(new ApiError('教务登录已失效', 401, 40101))

    await store.loadBuildings()

    expect(useSessionStore().status).toBe('anonymous')
  })
})
