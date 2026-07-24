import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { listSemesters } from '@/shared/api/semesters'
import {
  compareSemestersNewestFirst,
  findCurrentSemester,
  type Semester,
} from '@/shared/models/academic'

import { getGrades, type Grade } from './api'

type AuthState = 'checking' | 'anonymous' | 'authenticated' | 'unavailable'

export const useGradesStore = defineStore('grades', {
  state: () => ({
    authState: 'checking' as AuthState,
    semesters: [] as Semester[],
    selectedSemesterID: '',
    grades: [] as Grade[],
    loading: false,
    error: '',
  }),
  actions: {
    async initialize() {
      this.error = ''
      try {
        await this.refreshSemesters()
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          this.authState = 'anonymous'
          useSessionStore().markAnonymous()
          return
        }
        // 网络异常只表示成绩暂时不可用，不能据此判定用户已经退出登录。
        this.authState = 'unavailable'
        this.error = errorMessage(error)
      }
    },
    async refreshSemesters() {
      const semesters = await listSemesters()
      this.semesters = [...semesters].sort(compareSemestersNewestFirst)
      this.authState = 'authenticated'
      useSessionStore().markAuthenticated()
      if (this.semesters.length === 0) {
        this.selectedSemesterID = ''
        this.grades = []
        return
      }
      if (!this.semesters.some((semester) => semester.ID === this.selectedSemesterID)) {
        this.selectedSemesterID = findCurrentSemester(this.semesters)?.ID ?? ''
      }
      await this.loadGrades()
    },
    async loadGrades() {
      if (!this.selectedSemesterID) return
      this.loading = true
      this.error = ''
      try {
        this.grades = await getGrades(this.selectedSemesterID)
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          this.authState = 'anonymous'
          this.grades = []
          useSessionStore().markAnonymous()
        }
        this.error = errorMessage(error)
      } finally {
        this.loading = false
      }
    },
  },
})

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : '请求失败，请稍后重试'
}
