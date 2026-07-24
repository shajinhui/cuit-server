import type { Exam } from './api'

export interface ExamGroup {
  key: string
  label: string
  pending: boolean
  exams: Exam[]
}

export interface ExamTimeParts {
  start: string
  end: string
}

const unarrangedPattern = /未安排|待安排|暂无/
const abnormalStatusPattern = /取消|异常|缺考|缓考|停考/
const weekdayLabels = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

export function isExamPending(exam: Exam) {
  return (
    !exam.ExamDate.trim() ||
    !exam.ExamTime.trim() ||
    unarrangedPattern.test(exam.ExamDate) ||
    unarrangedPattern.test(exam.ExamTime)
  )
}

export function groupExamsByDate(exams: Exam[]) {
  const groups = new Map<string, Exam[]>()
  const pending: Exam[] = []

  for (const exam of exams) {
    if (isExamPending(exam)) {
      pending.push(exam)
      continue
    }
    const date = exam.ExamDate.trim()
    const current = groups.get(date)
    if (current) current.push(exam)
    else groups.set(date, [exam])
  }

  const result: ExamGroup[] = [...groups].map(([date, groupedExams]) => ({
    key: date,
    label: formatExamDate(date),
    pending: false,
    exams: groupedExams,
  }))
  if (pending.length) {
    result.push({
      key: 'pending',
      label: '待安排',
      pending: true,
      exams: pending,
    })
  }
  return result
}

export function examsOnDate(exams: Exam[], date = new Date()) {
  const dateKey = [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0'),
  ].join('-')
  return exams.filter((exam) => !isExamPending(exam) && exam.ExamDate.trim() === dateKey)
}

export function formatExamDate(date: string) {
  const match = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(date.trim())
  if (!match) return date.trim() || '日期待定'

  const year = Number(match[1])
  const month = Number(match[2])
  const day = Number(match[3])
  const parsed = new Date(year, month - 1, day)
  if (
    parsed.getFullYear() !== year ||
    parsed.getMonth() !== month - 1 ||
    parsed.getDate() !== day
  ) {
    return date.trim()
  }
  return `${month}月${day}日 ${weekdayLabels[parsed.getDay()]}`
}

export function splitExamTime(time: string): ExamTimeParts {
  const value = time.trim()
  if (!value || unarrangedPattern.test(value)) return { start: '待定', end: '' }

  const match = /^(\d{1,2}:\d{2})\s*[~～\-–—]\s*(\d{1,2}:\d{2})$/.exec(value)
  return match ? { start: match[1], end: match[2] } : { start: value, end: '' }
}

export function examCourseName(exam: Exam) {
  return exam.CourseName.trim() || exam.CourseSequence.trim() || '未命名考试'
}

export function examLocation(exam: Exam) {
  return exam.Location.trim() || '地点未安排'
}

export function isExamStatusDanger(status: string) {
  return abnormalStatusPattern.test(status.trim())
}
