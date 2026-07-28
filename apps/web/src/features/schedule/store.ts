import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { listSemesters } from '@/shared/api/semesters'
import {
  compareSemestersNewestFirst,
  findCurrentSemester,
  type Semester,
} from '@/shared/models/academic'

import { getCourseTable, getCurrentWeek, type CourseTable } from './api'
import {
  clearScheduleCache,
  readCourseOverrides,
  readManualCourses,
  readScheduleCache,
  writeCourseOverrides,
  writeManualCourses,
  writeScheduleCache,
} from './cache'
import {
  createCourseOverride,
  type CourseOverride,
} from './model/courseOverride'
import {
  createManualCourse,
  type CourseEditTarget,
  type ManualCourse,
  type ManualCourseInput,
} from './model/manualCourse'

interface ScheduleLoadOptions {
  semesterID?: string
  refresh?: boolean
}

export const useScheduleStore = defineStore('schedule', {
  state: () => ({
    semesters: [] as Semester[],
    selectedSemesterID: '',
    table: null as CourseTable | null,
    manualCourses: [] as ManualCourse[],
    manualCoursesLoaded: false,
    courseOverrides: [] as CourseOverride[],
    courseOverridesLoaded: false,
    currentWeek: 0,
    loading: false,
    error: '',
    weekError: '',
    syncError: '',
    usingCachedData: false,
    cachedAt: 0,
  }),
  actions: {
    async load(options: ScheduleLoadOptions = {}) {
      if (this.loading) return

      const requestedSemesterID = options.semesterID ?? ''
      this.loading = true
      this.error = ''
      this.weekError = ''
      this.syncError = ''
      try {
        await this.restoreCachedSchedule()
        await this.restoreManualCourses()
        await this.restoreCourseOverrides()
        const cachedSemesterMatches =
          !requestedSemesterID || requestedSemesterID === this.selectedSemesterID
        if (!options.refresh && this.table && cachedSemesterMatches) {
          // 页面进入只读取本机课表；首次登录没有缓存时，才继续查询教务系统。
          this.usingCachedData = useSessionStore().status === 'offline'
          return
        }

        const semesters = [...((await listSemesters()) ?? [])].sort(compareSemestersNewestFirst)
        if (semesters.length === 0) {
          this.semesters = []
          this.selectedSemesterID = ''
          this.table = null
          this.manualCourses = []
          this.manualCoursesLoaded = true
          this.courseOverrides = []
          this.courseOverridesLoaded = true
          this.currentWeek = 0
          this.usingCachedData = false
          this.cachedAt = 0
          await clearScheduleCache().catch(() => undefined)
          return
        }
        const targetSemesterID = requestedSemesterID || this.selectedSemesterID
        const selectedSemesterID = semesters.some((semester) => semester.ID === targetSemesterID)
          ? targetSemesterID
          : (findCurrentSemester(semesters)?.ID ?? '')

        const [tableResult, weekResult] = await Promise.allSettled([
          getCourseTable(selectedSemesterID),
          getCurrentWeek(),
        ])
        if (tableResult.status === 'rejected') throw tableResult.reason

        const currentWeek = weekResult.status === 'fulfilled' ? weekResult.value.CurrentWeek : this.currentWeek
        const cachedAt = Date.now()
        this.semesters = semesters
        this.selectedSemesterID = selectedSemesterID
        this.table = tableResult.value
        if (weekResult.status === 'fulfilled') {
          this.currentWeek = currentWeek
        } else {
          this.weekError = errorMessage(weekResult.reason)
        }
        this.cachedAt = cachedAt
        this.usingCachedData = false
        useSessionStore().markAuthenticated()
        await writeScheduleCache({
          version: 1,
          semesters,
          selectedSemesterID,
          table: tableResult.value,
          currentWeek,
          cachedAt,
        }).catch(() => undefined)
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          this.semesters = []
          this.selectedSemesterID = ''
          this.table = null
          this.currentWeek = 0
          this.usingCachedData = false
          this.cachedAt = 0
          this.error = errorMessage(error)
          useSessionStore().markAnonymous()
        } else if (this.table) {
          // 同步失败时保留最后一次成功数据，避免刷新动作把可用课表清空。
          this.usingCachedData = true
          this.syncError = errorMessage(error)
        } else {
          this.error = errorMessage(error)
        }
      } finally {
        this.loading = false
      }
    },
    async restoreCachedSchedule() {
      if (this.table) return

      const cache = await readScheduleCache().catch(() => null)
      if (!cache) return

      this.semesters = cache.semesters
      this.selectedSemesterID = cache.selectedSemesterID
      this.table = cache.table
      this.currentWeek = cache.currentWeek
      this.cachedAt = cache.cachedAt
      this.usingCachedData = true
    },
    async restoreManualCourses() {
      if (this.manualCoursesLoaded) return

      this.manualCourses = await readManualCourses()
      this.manualCoursesLoaded = true
    },
    async restoreCourseOverrides() {
      if (this.courseOverridesLoaded) return

      this.courseOverrides = await readCourseOverrides()
      this.courseOverridesLoaded = true
    },
    async addManualCourse(input: ManualCourseInput) {
      const course = createManualCourse(input, this.selectedSemesterID, createManualCourseID())
      const nextCourses = [...this.manualCourses, course]
      // 手动课程与教务课表分开保存，后续同步学校课表时不会覆盖用户自己添加的内容。
      await writeManualCourses(nextCourses)
      this.manualCourses = nextCourses
      return course
    },
    async updateCourse(target: CourseEditTarget, input: ManualCourseInput) {
      if (target.source === 'manual') {
        const courseIndex = this.manualCourses.findIndex((course) => course.id === target.id)
        if (courseIndex < 0) throw new Error('没有找到这门本机课程')

        const course = createManualCourse(input, this.selectedSemesterID, target.id)
        const nextCourses = [...this.manualCourses]
        nextCourses[courseIndex] = course
        await writeManualCourses(nextCourses)
        this.manualCourses = nextCourses
        return course
      }

      const courseOverride = createCourseOverride(input, this.selectedSemesterID, target.id)
      const nextCourseOverrides = this.courseOverrides.filter(
        (item) =>
          item.targetID !== target.id || item.semesterID !== this.selectedSemesterID,
      )
      nextCourseOverrides.push(courseOverride)
      await writeCourseOverrides(nextCourseOverrides)
      this.courseOverrides = nextCourseOverrides
      return courseOverride
    },
    async removeManualCourse(courseID: string) {
      const course = this.manualCourses.find((item) => item.id === courseID)
      if (!course) return null

      const nextCourses = this.manualCourses.filter((item) => item.id !== courseID)
      await writeManualCourses(nextCourses)
      this.manualCourses = nextCourses
      return course
    },
    clearData() {
      this.semesters = []
      this.selectedSemesterID = ''
      this.table = null
      this.manualCourses = []
      this.manualCoursesLoaded = false
      this.courseOverrides = []
      this.courseOverridesLoaded = false
      this.currentWeek = 0
      this.error = ''
      this.weekError = ''
      this.syncError = ''
      this.usingCachedData = false
      this.cachedAt = 0
    },
  },
})

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : '请求失败，请稍后重试'
}

function createManualCourseID() {
  return `manual-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}
