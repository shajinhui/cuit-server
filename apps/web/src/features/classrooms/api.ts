import { request } from '@/shared/api/client'

export interface ClassroomOption {
  ID: string
  Name: string
}

export interface ClassroomOptions {
  Campuses: ClassroomOption[] | null
  ClassroomTypes: ClassroomOption[] | null
  Buildings: ClassroomOption[] | null
}

export interface Classroom {
  ID: string
  Code: string
  Name: string
  Building: string
  Campus: string
  Type: string
  Capacity: number
}

export interface ClassroomOccupancy {
  Weekday: number
  StartSection: number
  EndSection: number
  Weeks: number[]
}

export interface ClassroomScheduleRoom {
  Classroom: Classroom
  Occupancies: ClassroomOccupancy[]
}

export interface ClassroomSchedule {
  SemesterID: string
  CampusID: string
  Rooms: ClassroomScheduleRoom[]
}

export interface AvailableClassroomQuery {
  semesterID: string
  week: number
  weekday: number
  sections: number[]
  campusID: string
  buildingID?: string
  classroomTypeID?: string
  minCapacity?: number
}

export function getClassroomOptions(semesterID: string, campusID = '') {
  const parameters = new URLSearchParams({ semester_id: semesterID })
  if (campusID) parameters.set('campus_id', campusID)
  return request<ClassroomOptions>(`/api/v1/jwxt/classroom-options?${parameters}`)
}

export function getAvailableClassrooms(query: AvailableClassroomQuery) {
  const parameters = new URLSearchParams({
    semester_id: query.semesterID,
    week: String(query.week),
    weekday: String(query.weekday),
    sections: [...query.sections].sort((left, right) => left - right).join(','),
    campus_id: query.campusID,
  })
  if (query.buildingID) parameters.set('building_id', query.buildingID)
  if (query.classroomTypeID) parameters.set('classroom_type_id', query.classroomTypeID)
  if (query.minCapacity !== undefined) parameters.set('min_capacity', String(query.minCapacity))
  return request<Classroom[]>(`/api/v1/jwxt/available-classrooms?${parameters}`)
}

export function getClassroomSchedule(semesterID: string, campusID: string) {
  const parameters = new URLSearchParams({
    semester_id: semesterID,
    campus_id: campusID,
  })
  return request<ClassroomSchedule>(`/api/v1/jwxt/classroom-schedule?${parameters}`)
}
