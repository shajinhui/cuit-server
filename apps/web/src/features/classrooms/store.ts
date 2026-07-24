import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { getCurrentWeek } from '@/shared/api/currentWeek'
import { listSemesters } from '@/shared/api/semesters'
import {
  compareSemestersNewestFirst,
  findCurrentSemester,
  type Semester,
} from '@/shared/models/academic'

import {
  getClassroomSchedule,
  getClassroomOptions,
  type AvailableClassroomQuery,
  type Classroom,
  type ClassroomOption,
  type ClassroomSchedule,
} from './api'
import {
  readClassroomScheduleCache,
  writeClassroomScheduleCache,
} from './cache'
import { defaultWeekday, findAvailableClassrooms, toggleSectionPair } from './model'
import { classroomCampuses, classroomTypes } from './options'

export interface ClassroomQueryContext {
  semesterLabel: string
  campusName: string
  week: number
  weekday: number
  sections: number[]
}

export const useClassroomsStore = defineStore('classrooms', {
  state: () => ({
    initialized: false,
    initializing: false,
    initializationError: '',
    semesters: [] as Semester[],
    selectedSemesterID: '',
    currentWeek: 1,
    week: 1,
    weekday: defaultWeekday(),
    sections: [1, 2] as number[],
    campuses: [...classroomCampuses] as ClassroomOption[],
    classroomTypes: [...classroomTypes] as ClassroomOption[],
    buildings: [] as ClassroomOption[],
    selectedCampusID: '',
    selectedBuildingID: '',
    selectedClassroomTypeID: '',
    minCapacity: '' as number | '',
    loadingOptions: false,
    optionsError: '',
    loadingResults: false,
    refreshingSchedule: false,
    rooms: [] as Classroom[],
    hasSearched: false,
    resultError: '',
    refreshError: '',
    cacheNotice: '',
    classroomSchedule: null as ClassroomSchedule | null,
    scheduleCachedAt: 0,
    usingCachedSchedule: false,
    lastQueryContext: null as ClassroomQueryContext | null,
  }),
  actions: {
    async initialize(force = false) {
      if ((this.initialized && !force) || this.initializing) return

      this.initializing = true
      this.initializationError = ''
      try {
        const [semesters, currentWeekResult] = await Promise.all([
          listSemesters(),
          getCurrentWeek().catch(() => null),
        ])
        this.semesters = [...semesters].sort(compareSemestersNewestFirst)
        this.currentWeek = validWeek(currentWeekResult?.CurrentWeek) ? currentWeekResult.CurrentWeek : 1
        if (this.semesters.length === 0) {
          this.selectedSemesterID = ''
          this.initialized = true
          useSessionStore().markAuthenticated()
          return
        }
        if (!this.semesters.some((semester) => semester.ID === this.selectedSemesterID)) {
          this.selectedSemesterID = findCurrentSemester(this.semesters)?.ID ?? ''
        }
        this.week = this.isCurrentSemester() ? this.currentWeek : 1
        if (!this.campuses.some((campus) => campus.ID === this.selectedCampusID)) {
          this.selectedCampusID = preferredCampusID(this.campuses)
        }
        this.initialized = true
        useSessionStore().markAuthenticated()
      } catch (error) {
        this.handleAuthorizationError(error)
        this.initializationError = errorMessage(error, '空教室筛选项读取失败，请稍后重试')
      } finally {
        this.initializing = false
      }
    },
    async changeSemester(semesterID: string) {
      if (!semesterID || semesterID === this.selectedSemesterID) return
      this.selectedSemesterID = semesterID
      this.week = this.isCurrentSemester() ? this.currentWeek : 1
      this.resetResults()
      this.resetSchedule()
      this.selectedCampusID = ''
      this.selectedBuildingID = ''
      this.selectedClassroomTypeID = ''
      this.buildings = []
      this.selectedCampusID = preferredCampusID(this.campuses)
    },
    async loadBuildings() {
      if (!this.selectedSemesterID || !this.selectedCampusID) return false
      this.loadingOptions = true
      this.optionsError = ''
      try {
        const options = await getClassroomOptions(this.selectedSemesterID, this.selectedCampusID)
        this.buildings = options.Buildings ?? []
        return true
      } catch (error) {
        this.handleAuthorizationError(error)
        this.optionsError = errorMessage(error, '教学楼读取失败，请稍后重试')
        return false
      } finally {
        this.loadingOptions = false
      }
    },
    async changeCampus(campusID: string) {
      if (campusID === this.selectedCampusID) return
      this.selectedCampusID = campusID
      this.selectedBuildingID = ''
      this.buildings = []
      this.resetResults()
      this.resetSchedule()
      this.optionsError = ''
    },
    togglePair(pairStart: number) {
      this.sections = toggleSectionPair(this.sections, pairStart)
    },
    async search(forceRefresh = false) {
      const query = this.buildQuery()
      if (!query) return

      const preservingResults =
        forceRefresh &&
        this.hasSearched &&
        this.classroomSchedule?.SemesterID === query.semesterID &&
        this.classroomSchedule.CampusID === query.campusID
      this.loadingResults = !preservingResults
      this.refreshingSchedule = preservingResults
      this.resultError = ''
      this.refreshError = ''
      this.cacheNotice = ''
      if (!preservingResults) {
        this.rooms = []
        this.hasSearched = true
        this.lastQueryContext = this.buildQueryContext()
      }
      try {
        const schedule = await this.loadSchedule(query.semesterID, query.campusID, forceRefresh)
        const buildingName = this.buildings.find(
          (building) => building.ID === query.buildingID,
        )?.Name
        const classroomTypeName = this.classroomTypes.find(
          (type) => type.ID === query.classroomTypeID,
        )?.Name
        this.rooms = findAvailableClassrooms(schedule, {
          week: query.week,
          weekday: query.weekday,
          sections: query.sections,
          buildingName,
          classroomTypeName,
          minCapacity: query.minCapacity,
        })
        this.hasSearched = true
        this.lastQueryContext = this.buildQueryContext()
        useSessionStore().markAuthenticated()
      } catch (error) {
        this.handleAuthorizationError(error)
        if (preservingResults) {
          this.refreshError = errorMessage(error, '教室课表更新失败，仍显示上次的数据')
        } else {
          this.resultError = errorMessage(error, '空教室查询失败，请稍后重试')
        }
      } finally {
        this.loadingResults = false
        this.refreshingSchedule = false
      }
    },
    async loadSchedule(semesterID: string, campusID: string, forceRefresh: boolean) {
      if (
        !forceRefresh &&
        this.classroomSchedule?.SemesterID === semesterID &&
        this.classroomSchedule.CampusID === campusID
      ) {
        return this.classroomSchedule
      }

      if (!forceRefresh) {
        try {
          const cached = await readClassroomScheduleCache(semesterID, campusID)
          if (cached) {
            this.classroomSchedule = cached.schedule
            this.scheduleCachedAt = cached.cachedAt
            this.usingCachedSchedule = true
            return cached.schedule
          }
        } catch {
          this.cacheNotice = '本地缓存暂时不可用，本次将使用在线数据'
        }
      }

      const schedule = await getClassroomSchedule(semesterID, campusID)
      if (schedule.SemesterID !== semesterID || schedule.CampusID !== campusID) {
        throw new Error('教室课表响应与查询条件不一致')
      }
      this.classroomSchedule = schedule
      const fetchedAt = Date.now()
      this.scheduleCachedAt = 0
      this.usingCachedSchedule = false
      try {
        const cached = await writeClassroomScheduleCache(schedule, fetchedAt)
        this.scheduleCachedAt = cached.cachedAt
      } catch {
        this.cacheNotice = '查询已完成，但本次教室课表未能保存到本机'
      }
      return schedule
    },
    async refreshSchedule() {
      await this.search(true)
    },
    clearData() {
      this.initialized = false
      this.initializing = false
      this.initializationError = ''
      this.semesters = []
      this.selectedSemesterID = ''
      this.currentWeek = 1
      this.week = 1
      this.weekday = defaultWeekday()
      this.sections = [1, 2]
      this.campuses = [...classroomCampuses]
      this.classroomTypes = [...classroomTypes]
      this.buildings = []
      this.selectedCampusID = ''
      this.selectedBuildingID = ''
      this.selectedClassroomTypeID = ''
      this.minCapacity = ''
      this.loadingOptions = false
      this.optionsError = ''
      this.resetResults()
      this.resetSchedule()
    },
    resetResults() {
      this.rooms = []
      this.loadingResults = false
      this.refreshingSchedule = false
      this.hasSearched = false
      this.resultError = ''
      this.refreshError = ''
      this.cacheNotice = ''
      this.lastQueryContext = null
    },
    resetSchedule() {
      this.classroomSchedule = null
      this.scheduleCachedAt = 0
      this.usingCachedSchedule = false
    },
    isCurrentSemester() {
      return findCurrentSemester(this.semesters)?.ID === this.selectedSemesterID
    },
    buildQuery(): AvailableClassroomQuery | null {
      if (!this.selectedSemesterID) {
        this.resultError = '请选择学期'
        return null
      }
      if (!this.selectedCampusID) {
        this.resultError = '请选择校区'
        return null
      }
      if (this.sections.length === 0) {
        this.resultError = '请至少选择一个节次'
        return null
      }
      const parsedCapacity = this.minCapacity === '' ? undefined : Number(this.minCapacity)
      if (
        parsedCapacity !== undefined &&
        (!Number.isInteger(parsedCapacity) || parsedCapacity < 0)
      ) {
        this.resultError = '最低容量需要填写大于或等于 0 的整数'
        return null
      }
      return {
        semesterID: this.selectedSemesterID,
        week: this.week,
        weekday: this.weekday,
        sections: [...this.sections],
        campusID: this.selectedCampusID,
        buildingID: this.selectedBuildingID || undefined,
        classroomTypeID: this.selectedClassroomTypeID || undefined,
        minCapacity: parsedCapacity,
      }
    },
    buildQueryContext(): ClassroomQueryContext {
      const semester = this.semesters.find((item) => item.ID === this.selectedSemesterID)
      const campus = this.campuses.find((item) => item.ID === this.selectedCampusID)
      return {
        semesterLabel: semester ? `${semester.SchoolYear}学年 第${semester.Term}学期` : '当前学期',
        campusName: campus?.Name || '所选校区',
        week: this.week,
        weekday: this.weekday,
        sections: [...this.sections],
      }
    },
    handleAuthorizationError(error: unknown) {
      if (error instanceof ApiError && error.status === 401) {
        useSessionStore().markAnonymous()
      }
    },
  },
})

function validWeek(week: number | undefined): week is number {
  return typeof week === 'number' && Number.isInteger(week) && week >= 1 && week <= 53
}

function preferredCampusID(campuses: ClassroomOption[]) {
  return campuses.find((campus) => campus.Name.trim().includes('航空港'))?.ID || campuses[0]?.ID || ''
}

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback
}
