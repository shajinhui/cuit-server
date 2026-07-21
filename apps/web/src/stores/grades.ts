import { defineStore } from 'pinia'

import { ApiError } from '@/api/client'
import { getGrades, listSemesters, type Grade, type Semester } from '@/api/grades'
import { useSessionStore } from '@/stores/session'

type AuthState = 'checking' | 'anonymous' | 'authenticated'

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
        this.authState = 'anonymous'
        this.error = errorMessage(error)
      }
    },
    async login(username: string, password: string) {
      this.loading = true
      this.error = ''
      try {
        await useSessionStore().login(username, password, false)
        await this.refreshSemesters()
      } catch (error) {
        this.authState = 'anonymous'
        this.error = errorMessage(error)
        throw error
      } finally {
        this.loading = false
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
        this.selectedSemesterID = (this.semesters[1] ?? this.semesters[0]).ID
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
    async logout() {
      try {
        await useSessionStore().logout()
      } finally {
        this.authState = 'anonymous'
        this.semesters = []
        this.selectedSemesterID = ''
        this.grades = []
        this.error = ''
      }
    },
  },
})

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : '请求失败，请稍后重试'
}

function compareSemestersNewestFirst(left: Semester, right: Semester) {
  const schoolYearOrder = right.SchoolYear.localeCompare(left.SchoolYear, 'zh-CN', { numeric: true })
  if (schoolYearOrder !== 0) return schoolYearOrder

  const leftTerm = Number.parseInt(left.Term, 10)
  const rightTerm = Number.parseInt(right.Term, 10)
  if (!Number.isNaN(leftTerm) && !Number.isNaN(rightTerm)) return rightTerm - leftTerm

  return right.Term.localeCompare(left.Term, 'zh-CN', { numeric: true })
}
