import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { listSemesters } from '@/shared/api/semesters'
import type { Semester } from '@/shared/models/academic'

import { listExams } from './api'
import { useExamsStore } from './store'

vi.mock('@/shared/api/semesters', () => ({ listSemesters: vi.fn() }))
vi.mock('./api', () => ({
  listExams: vi.fn(),
}))

const listSemestersMock = vi.mocked(listSemesters)
const listExamsMock = vi.mocked(listExams)

const currentSemester: Semester = { ID: '1106', SchoolYear: '2025-2026', Term: '1' }
const previousSemester: Semester = { ID: '905', SchoolYear: '2024-2025', Term: '2' }

describe('exams store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    listSemestersMock.mockResolvedValue([previousSemester, currentSemester])
    listExamsMock.mockResolvedValue([])
  })

  it('uses fixed exam types and loads the selected semester directly', async () => {
    const store = useExamsStore()

    await store.initialize()

    expect(store.selectedSemesterID).toBe(currentSemester.ID)
    expect(store.selectedBatchID).toBe('final')
    expect(store.batches).toEqual([
      { ID: 'final', Name: '期末考试' },
      { ID: 'makeup', Name: '开学补考' },
    ])
    expect(listExamsMock).toHaveBeenCalledWith(currentSemester.ID, 'final')
    expect(store.hasLoadedExams).toBe(true)
  })

  it('keeps the fixed exam type when the semester changes', async () => {
    const store = useExamsStore()
    await store.initialize()

    await store.changeSemester(previousSemester.ID)

    expect(store.selectedBatchID).toBe('final')
    expect(listExamsMock).toHaveBeenLastCalledWith(previousSemester.ID, 'final')
  })

  it('keeps current results visible when a refresh fails', async () => {
    const store = useExamsStore()
    listExamsMock.mockResolvedValueOnce([
      {
        CourseSequence: 'A001',
        CourseName: '高等数学',
        ExamType: '期末考试',
        ExamDate: '2026-01-10',
        ExamTime: '09:30~11:30',
        Location: 'A101',
        ExamRoomID: '101',
        Credits: '4',
        Status: '正常',
        Remark: '',
      },
    ])
    await store.initialize()
    listExamsMock.mockRejectedValueOnce(new Error('教务系统暂时不可用'))

    await store.refresh()

    expect(store.exams).toHaveLength(1)
    expect(store.examError).toBe('教务系统暂时不可用')
  })

  it('marks the session anonymous after a 401 response', async () => {
    listExamsMock.mockRejectedValue(new ApiError('教务登录已失效', 401, 40101))
    const store = useExamsStore()

    await store.initialize()

    expect(useSessionStore().status).toBe('anonymous')
    expect(store.initialized).toBe(false)
  })
})
