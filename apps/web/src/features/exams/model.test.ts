import { describe, expect, it } from 'vitest'

import type { Exam } from './api'
import {
  examsOnDate,
  formatExamDate,
  groupExamsByDate,
  isExamPending,
  isExamStatusDanger,
  splitExamTime,
} from './model'

const scheduledExam: Exam = {
  CourseSequence: 'A001',
  CourseName: '高等数学',
  ExamType: '期末考试',
  ExamDate: '2026-01-10',
  ExamTime: '09:30~11:30',
  Location: 'A101',
  ExamRoomID: '101',
  Credits: '4',
  Status: '正常',
  Remark: '',
}

describe('exam presentation model', () => {
  it('formats a backend date without relying on UTC parsing', () => {
    expect(formatExamDate('2026-01-10')).toBe('1月10日 周六')
    expect(formatExamDate('日期另行通知')).toBe('日期另行通知')
  })

  it('splits common exam time ranges and keeps unusual text intact', () => {
    expect(splitExamTime('09:30~11:30')).toEqual({ start: '09:30', end: '11:30' })
    expect(splitExamTime('下午场')).toEqual({ start: '下午场', end: '' })
    expect(splitExamTime('时间未安排')).toEqual({ start: '待定', end: '' })
  })

  it('groups scheduled exams by first-seen date and places pending items last', () => {
    const groups = groupExamsByDate([
      scheduledExam,
      { ...scheduledExam, CourseName: '大学英语', ExamTime: '14:00~16:00' },
      {
        ...scheduledExam,
        CourseName: '大学物理',
        ExamDate: '时间未安排',
        ExamTime: '时间未安排',
        Location: '地点未安排',
      },
    ])

    expect(groups).toHaveLength(2)
    expect(groups[0].label).toBe('1月10日 周六')
    expect(groups[0].exams).toHaveLength(2)
    expect(groups[1].label).toBe('待安排')
    expect(groups[1].pending).toBe(true)
  })

  it('uses danger styling only for explicit abnormal states', () => {
    expect(isExamPending({ ...scheduledExam, ExamTime: '时间未安排' })).toBe(true)
    expect(isExamStatusDanger('正常')).toBe(false)
    expect(isExamStatusDanger('考试取消')).toBe(true)
  })

  it('finds only scheduled exams on the local calendar date', () => {
    const exams = [
      scheduledExam,
      { ...scheduledExam, CourseName: '大学英语', ExamDate: '2026-01-11' },
      { ...scheduledExam, CourseName: '大学物理', ExamDate: '待安排' },
    ]

    expect(examsOnDate(exams, new Date(2026, 0, 10, 12))).toEqual([scheduledExam])
  })
})
