import { describe, expect, it } from 'vitest'

import {
  courseCountdownLabel,
  courseStartTimeLabel,
  courseStatus,
  courseTimeLabel,
  formatHomeDate,
  greetingForHour,
} from './model'

describe('home model', () => {
  it('formats the greeting and current date', () => {
    expect(greetingForHour(8)).toBe('早上好')
    expect(greetingForHour(13)).toBe('中午好')
    expect(greetingForHour(19)).toBe('晚上好')
    expect(formatHomeDate(new Date(2026, 7, 8))).toBe('8 月 8 日 · 星期六')
  })

  it('formats known and extended section times', () => {
    expect(courseTimeLabel({ start: 1, span: 2 })).toBe('08:20–09:45')
    expect(courseStartTimeLabel({ start: 1 })).toBe('08:20')
    expect(courseTimeLabel({ start: 12, span: 2 })).toBe('第 12–13 节')
  })

  it('describes whether a course is past, ongoing, or upcoming', () => {
    const course = { start: 3, span: 2 }
    expect(courseStatus(course, new Date(2026, 7, 8, 9, 30))).toBe('upcoming')
    expect(courseStatus(course, new Date(2026, 7, 8, 10, 30))).toBe('ongoing')
    expect(courseStatus(course, new Date(2026, 7, 8, 12, 0))).toBe('past')
    expect(courseCountdownLabel(course, new Date(2026, 7, 8, 9, 28))).toBe('还有 42 分钟')
    expect(courseCountdownLabel(course, new Date(2026, 7, 8, 8, 40))).toBe('还有 1 小时 30 分')
    expect(courseCountdownLabel(course, new Date(2026, 7, 8, 10, 30))).toBe('进行中')
  })
})
