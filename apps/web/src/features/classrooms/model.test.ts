import { describe, expect, it } from 'vitest'

import type { Classroom, ClassroomSchedule } from './api'
import {
  classroomTitle,
  defaultWeekday,
  findAvailableClassrooms,
  formatSections,
  groupClassroomsByBuilding,
  toggleSectionPair,
} from './model'

const rooms: Classroom[] = [
  {
    ID: '67',
    Code: 'H2101',
    Name: 'H2101',
    Building: '航空港第二教学楼',
    Campus: '航空港',
    Type: '多媒体',
    Capacity: 166,
  },
  {
    ID: '68',
    Code: 'H2102',
    Name: 'H2102',
    Building: '航空港第二教学楼',
    Campus: '航空港',
    Type: '智慧教室',
    Capacity: 80,
  },
]

describe('toggleSectionPair', () => {
  it('成对选择和取消节次，并始终保持顺序', () => {
    expect(toggleSectionPair([3, 4], 1)).toEqual([1, 2, 3, 4])
    expect(toggleSectionPair([1, 2, 3, 4], 3)).toEqual([1, 2])
  })
})

describe('formatSections', () => {
  it('把连续节次压缩成易读区间', () => {
    expect(formatSections([4, 1, 2, 3, 7, 8])).toBe('第 1–4、7–8 节')
    expect(formatSections([])).toBe('未选择节次')
  })
})

describe('groupClassroomsByBuilding', () => {
  it('按后端顺序将教室归入教学楼', () => {
    const groups = groupClassroomsByBuilding([
      ...rooms,
      { ...rooms[0], ID: '70', Name: 'A101', Building: '主教学楼' },
    ])

    expect(groups).toHaveLength(2)
    expect(groups[0].building).toBe('航空港第二教学楼')
    expect(groups[0].rooms).toHaveLength(2)
    expect(groups[1].rooms[0].Name).toBe('A101')
  })
})

describe('findAvailableClassrooms', () => {
  const schedule: ClassroomSchedule = {
    SemesterID: '905',
    CampusID: '1',
    Rooms: [
      {
        Classroom: rooms[0],
        Occupancies: [
          { Weekday: 1, StartSection: 1, EndSection: 2, Weeks: [1, 2, 3] },
        ],
      },
      {
        Classroom: rooms[1],
        Occupancies: [
          { Weekday: 3, StartSection: 3, EndSection: 4, Weeks: [2, 4, 6] },
        ],
      },
    ],
  }

  it('按周次、星期和节次从整学期快照中排除已占用教室', () => {
    expect(
      findAvailableClassrooms(schedule, {
        week: 2,
        weekday: 1,
        sections: [1, 2],
      }).map((room) => room.ID),
    ).toEqual(['68'])
  })

  it('在本地应用教学楼、类型和容量筛选', () => {
    expect(
      findAvailableClassrooms(schedule, {
        week: 1,
        weekday: 7,
        sections: [11, 12],
        buildingName: '航空港第二教学楼',
        classroomTypeName: '多媒体',
        minCapacity: 100,
      }).map((room) => room.ID),
    ).toEqual(['67'])
  })
})

describe('classroomTitle', () => {
  it('避免名称和代码相同时重复显示', () => {
    expect(classroomTitle(rooms[0])).toBe('H2101')
    expect(classroomTitle({ ...rooms[0], Name: '第一机房' })).toBe('第一机房 · H2101')
  })
})

describe('defaultWeekday', () => {
  it('将星期日转换为接口约定的 7', () => {
    expect(defaultWeekday(new Date('2026-07-19T12:00:00'))).toBe(7)
    expect(defaultWeekday(new Date('2026-07-20T12:00:00'))).toBe(1)
  })
})
