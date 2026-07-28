import { createManualCourse, isManualCourse, type ManualCourseInput } from './manualCourse'

export interface CourseOverride {
  targetID: string
  semesterID: string
  name: string
  room: string
  weekday: number
  startSection: number
  endSection: number
  weeks: number[]
}

export function createCourseOverride(
  input: ManualCourseInput,
  semesterID: string,
  targetID: string,
): CourseOverride {
  const normalized = createManualCourse(input, semesterID, targetID)
  return {
    targetID,
    semesterID,
    name: normalized.name,
    room: normalized.room,
    weekday: normalized.weekday,
    startSection: normalized.startSection,
    endSection: normalized.endSection,
    weeks: normalized.weeks,
  }
}

export function isCourseOverride(value: unknown): value is CourseOverride {
  if (!value || typeof value !== 'object') return false

  const override = value as Partial<CourseOverride>
  return (
    typeof override.targetID === 'string' &&
    isManualCourse({
      id: override.targetID,
      semesterID: override.semesterID,
      name: override.name,
      room: override.room,
      weekday: override.weekday,
      startSection: override.startSection,
      endSection: override.endSection,
      weeks: override.weeks,
    })
  )
}
