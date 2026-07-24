import type { Classroom, ClassroomSchedule } from './api'

export interface ClassroomGroup {
  building: string
  rooms: Classroom[]
}

export interface LocalClassroomQuery {
  week: number
  weekday: number
  sections: number[]
  buildingName?: string
  classroomTypeName?: string
  minCapacity?: number
}

export function toggleSectionPair(sections: number[], pairStart: number) {
  const pair = [pairStart, pairStart + 1]
  const selected = new Set(sections)
  const removing = pair.every((section) => selected.has(section))
  for (const section of pair) {
    if (removing) selected.delete(section)
    else selected.add(section)
  }
  return [...selected].sort((left, right) => left - right)
}

export function formatSections(sections: number[]) {
  const sorted = [...new Set(sections)].sort((left, right) => left - right)
  if (sorted.length === 0) return '未选择节次'

  const ranges: string[] = []
  let start = sorted[0]
  let end = sorted[0]
  for (const section of sorted.slice(1)) {
    if (section === end + 1) {
      end = section
      continue
    }
    ranges.push(start === end ? String(start) : `${start}–${end}`)
    start = section
    end = section
  }
  ranges.push(start === end ? String(start) : `${start}–${end}`)
  return `第 ${ranges.join('、')} 节`
}

export function groupClassroomsByBuilding(rooms: Classroom[]) {
  const groups = new Map<string, Classroom[]>()
  for (const room of rooms) {
    const building = room.Building.trim() || '其他教学楼'
    const current = groups.get(building)
    if (current) current.push(room)
    else groups.set(building, [room])
  }
  return [...groups].map(([building, groupedRooms]) => ({ building, rooms: groupedRooms }))
}

export function findAvailableClassrooms(
  schedule: ClassroomSchedule,
  query: LocalClassroomQuery,
) {
  const buildingName = query.buildingName?.trim()
  const classroomTypeName = query.classroomTypeName?.trim()
  return schedule.Rooms.filter(({ Classroom: room, Occupancies: occupancies }) => {
    if (buildingName && room.Building.trim() !== buildingName) return false
    if (classroomTypeName && room.Type.trim() !== classroomTypeName) return false
    if (query.minCapacity !== undefined && room.Capacity < query.minCapacity) return false

    return !occupancies.some(
      (period) =>
        period.Weekday === query.weekday &&
        period.Weeks.includes(query.week) &&
        query.sections.some(
          (section) => section >= period.StartSection && section <= period.EndSection,
        ),
    )
  }).map(({ Classroom: room }) => room)
}

export function classroomTitle(room: Classroom) {
  const name = room.Name.trim()
  const code = room.Code.trim()
  if (!name) return code || '未命名教室'
  return code && code !== name ? `${name} · ${code}` : name
}

export function defaultWeekday(date = new Date()) {
  return date.getDay() || 7
}
