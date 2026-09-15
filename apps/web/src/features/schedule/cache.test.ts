import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type { Semester } from '@/shared/models/academic'

import type { CourseTable } from './api'
import { readScheduleCache, type CachedSchedule } from './cache'

const openDatabaseMock = vi.hoisted(() => vi.fn())

vi.mock('@/shared/storage/offlineDatabase', () => ({
  offlineStoreName: 'offline-data',
  openOfflineDatabase: openDatabaseMock,
}))

describe('schedule launch snapshot', () => {
  let values: Map<string, string>

  beforeEach(() => {
    values = new Map()
    openDatabaseMock.mockReset()
    vi.stubGlobal('window', {
      localStorage: {
        getItem: (key: string) => values.get(key) ?? null,
        setItem: (key: string, value: string) => values.set(key, value),
        removeItem: (key: string) => values.delete(key),
      },
    })
  })

  afterEach(() => vi.unstubAllGlobals())

  it('restores the launch snapshot without opening IndexedDB', async () => {
    const cachedSchedule = createCachedSchedule()
    values.set('schedule-launch-snapshot-v3', JSON.stringify(cachedSchedule))

    await expect(readScheduleCache()).resolves.toEqual(cachedSchedule)
    expect(openDatabaseMock).not.toHaveBeenCalled()
  })

  it('drops a damaged launch snapshot before falling back to IndexedDB', async () => {
    values.set('schedule-launch-snapshot-v3', '{damaged')
    openDatabaseMock.mockRejectedValueOnce(new Error('IndexedDB unavailable'))

    await expect(readScheduleCache()).rejects.toThrow('IndexedDB unavailable')
    expect(values.has('schedule-launch-snapshot-v3')).toBe(false)
  })
})

function createCachedSchedule(): CachedSchedule {
  const semester: Semester = { ID: 'semester-1', SchoolYear: '2026-2027', Term: '1' }
  const table: CourseTable = {
    SemesterID: semester.ID,
    WeekCount: 20,
    SectionsPerDay: 12,
    Courses: [],
  }
  return {
    version: 3,
    semesters: [semester],
    selectedSemesterID: semester.ID,
    table,
    currentWeek: 2,
    cachedAt: 1,
  }
}
