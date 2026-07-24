import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { listSemesters } from '@/shared/api/semesters'
import {
  compareSemestersNewestFirst,
  findCurrentSemester,
  type Semester,
} from '@/shared/models/academic'

import { listExams, type Exam, type ExamBatch, type ExamType } from './api'
import { examBatches } from './options'

export const useExamsStore = defineStore('exams', {
  state: () => ({
    initialized: false,
    initializing: false,
    initializationError: '',
    semesters: [] as Semester[],
    selectedSemesterID: '',
    batches: [...examBatches] as ExamBatch[],
    selectedBatchID: 'final' as ExamType,
    exams: [] as Exam[],
    loadingExams: false,
    hasLoadedExams: false,
    examError: '',
    examRequestVersion: 0,
  }),
  actions: {
    async initialize(force = false) {
      if ((this.initialized && !force) || this.initializing) return

      this.initializing = true
      this.initializationError = ''
      try {
        const semesters = await listSemesters()
        this.semesters = [...semesters].sort(compareSemestersNewestFirst)
        if (this.semesters.length === 0) {
          this.selectedSemesterID = ''
          this.exams = []
          this.hasLoadedExams = true
          this.initialized = true
          useSessionStore().markAuthenticated()
          return
        }
        if (!this.semesters.some((semester) => semester.ID === this.selectedSemesterID)) {
          this.selectedSemesterID = findCurrentSemester(this.semesters)?.ID ?? ''
        }
        await this.loadExams()
        if (useSessionStore().status === 'anonymous') return
        this.initialized = true
        useSessionStore().markAuthenticated()
      } catch (error) {
        this.handleAuthorizationError(error)
        this.initializationError = errorMessage(error, '学期读取失败，请稍后重试')
      } finally {
        this.initializing = false
      }
    },
    async changeSemester(semesterID: string) {
      if (!semesterID || semesterID === this.selectedSemesterID) return
      this.selectedSemesterID = semesterID
      this.resetExams()
      await this.loadExams()
    },
    async changeBatch(batchID: ExamType) {
      if (!batchID || batchID === this.selectedBatchID) return
      this.selectedBatchID = batchID
      this.resetExams()
      await this.loadExams()
    },
    async loadExams() {
      if (!this.selectedBatchID) return false

      const requestVersion = ++this.examRequestVersion
      this.loadingExams = true
      this.examError = ''
      try {
        const exams = await listExams(this.selectedSemesterID, this.selectedBatchID)
        if (requestVersion !== this.examRequestVersion) return false

        this.exams = exams
        this.hasLoadedExams = true
        useSessionStore().markAuthenticated()
        return true
      } catch (error) {
        if (requestVersion !== this.examRequestVersion) return false
        this.handleAuthorizationError(error)
        this.examError = errorMessage(error, '考场安排读取失败，请稍后重试')
        this.hasLoadedExams = true
        return false
      } finally {
        if (requestVersion === this.examRequestVersion) this.loadingExams = false
      }
    },
    async refresh() {
      if (this.loadingExams) return
      await this.loadExams()
    },
    clearData() {
      this.examRequestVersion += 1
      this.initialized = false
      this.initializing = false
      this.initializationError = ''
      this.semesters = []
      this.selectedSemesterID = ''
      this.batches = [...examBatches]
      this.selectedBatchID = 'final'
      this.resetExams()
    },
    resetExams() {
      this.examRequestVersion += 1
      this.exams = []
      this.loadingExams = false
      this.hasLoadedExams = false
      this.examError = ''
    },
    handleAuthorizationError(error: unknown) {
      if (error instanceof ApiError && error.status === 401) {
        useSessionStore().markAnonymous()
      }
    },
  },
})

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback
}
