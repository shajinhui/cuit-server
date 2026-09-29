import { describe, expect, it } from 'vitest'

import { createMockHandler } from './api'
import { currentSemesterID, mockCurrentWeek, mockPassword, mockStudentNo } from './fixtures'

interface MockBody {
  code: number
  message: string
  data: unknown
}

function bodyOf(result: { body: unknown } | null): MockBody {
  return result?.body as MockBody
}

/** 每个用例都用独立 handler，避免登录状态互相影响。 */
function loggedInHandler() {
  const handle = createMockHandler()
  handle('POST', '/api/v1/jwxt/session', { username: mockStudentNo, password: mockPassword })
  return handle
}

describe('本地 mock 教务接口', () => {
  it('未登录时业务接口返回 401', () => {
    const handle = createMockHandler()
    const result = handle('GET', '/api/v1/jwxt/profile', undefined)

    expect(result?.status).toBe(401)
    expect(bodyOf(result).code).toBe(40100)
  })

  it('演示账号可以登录，密码错误被拒', () => {
    const handle = createMockHandler()

    expect(bodyOf(handle('GET', '/api/v1/jwxt/session', undefined)).data).toEqual({
      authenticated: false,
    })

    const wrong = handle('POST', '/api/v1/jwxt/session', {
      username: mockStudentNo,
      password: 'wrong-password',
    })
    expect(wrong?.status).toBe(401)
    expect(bodyOf(wrong).code).toBe(40101)

    const right = handle('POST', '/api/v1/jwxt/session', {
      username: mockStudentNo,
      password: mockPassword,
    })
    expect(right?.status).toBe(200)
    expect(bodyOf(right).data).toEqual({ authenticated: true })
  })

  it('登录后可以登出', () => {
    const handle = loggedInHandler()
    expect(bodyOf(handle('DELETE', '/api/v1/jwxt/session', undefined)).data).toEqual({
      authenticated: false,
    })
    expect(handle('GET', '/api/v1/jwxt/profile', undefined)?.status).toBe(401)
  })

  it('返回个人信息与三个学期', () => {
    const handle = loggedInHandler()

    expect(bodyOf(handle('GET', '/api/v1/jwxt/profile', undefined)).data).toMatchObject({
      StudentNo: mockStudentNo,
      Name: '演示同学',
      // 个人信息页会用它算年级，必须是能转成数字的入学年份。
      Grade: '2024',
    })

    const semesters = bodyOf(handle('GET', '/api/v1/jwxt/semesters', undefined)).data as unknown[]
    expect(semesters).toHaveLength(3)
  })

  it('当前学期有课，其他学期返回空课表', () => {
    const handle = loggedInHandler()

    const current = bodyOf(
      handle('GET', `/api/v1/jwxt/course-table?semester_id=${currentSemesterID}`, undefined),
    ).data as { Courses: unknown[]; WeekCount: number }
    expect(current.Courses.length).toBeGreaterThan(0)
    expect(current.WeekCount).toBe(18)

    const other = bodyOf(
      handle('GET', '/api/v1/jwxt/course-table?semester_id=2025-2026-1', undefined),
    ).data as { Courses: unknown[] }
    expect(other.Courses).toHaveLength(0)
  })

  it('成绩按学期区分', () => {
    const handle = loggedInHandler()

    const current = bodyOf(
      handle('GET', `/api/v1/jwxt/grades?semester_id=${currentSemesterID}`, undefined),
    ).data as unknown[]
    expect(current).toHaveLength(3)

    const previous = bodyOf(
      handle('GET', '/api/v1/jwxt/grades?semester_id=2025-2026-1', undefined),
    ).data as { CourseName: string; MakeupScore: string }[]
    expect(previous).toHaveLength(3)
    expect(previous.some((grade) => grade.MakeupScore !== '')).toBe(true)
  })

  it('考试按类型过滤', () => {
    const handle = loggedInHandler()

    const finals = bodyOf(
      handle('GET', `/api/v1/jwxt/exams?semester_id=${currentSemesterID}&exam_type=final`, undefined),
    ).data as { ExamType: string }[]
    expect(finals.length).toBeGreaterThan(0)
    expect(finals.every((exam) => exam.ExamType === 'final')).toBe(true)

    const makeups = bodyOf(
      handle(
        'GET',
        `/api/v1/jwxt/exams?semester_id=${currentSemesterID}&exam_type=makeup`,
        undefined,
      ),
    ).data as { ExamType: string }[]
    expect(makeups.every((exam) => exam.ExamType === 'makeup')).toBe(true)
  })

  it('空教室与教室占用有数据', () => {
    const handle = loggedInHandler()

    const options = bodyOf(
      handle('GET', `/api/v1/jwxt/classroom-options?semester_id=${currentSemesterID}`, undefined),
    ).data as { Campuses: unknown[] }
    expect(options.Campuses.length).toBeGreaterThan(0)

    const rooms = bodyOf(
      handle(
        'GET',
        `/api/v1/jwxt/available-classrooms?semester_id=${currentSemesterID}&week=4&weekday=1&sections=1,2&campus_id=demo-campus-1`,
        undefined,
      ),
    ).data as unknown[]
    expect(rooms.length).toBeGreaterThan(0)

    const schedule = bodyOf(
      handle(
        'GET',
        `/api/v1/jwxt/classroom-schedule?semester_id=${currentSemesterID}&campus_id=demo-campus-1`,
        undefined,
      ),
    ).data as { Rooms: unknown[] }
    expect(schedule.Rooms.length).toBeGreaterThan(0)
  })

  it('当前教学周固定，方便复现', () => {
    const handle = createMockHandler()
    expect(bodyOf(handle('GET', '/api/v1/schedule/current-week', undefined)).data).toEqual({
      CurrentWeek: mockCurrentWeek,
    })
  })

  it('没有演示数据的接口返回 null，继续走真实代理', () => {
    const handle = loggedInHandler()

    // 非 jwxt 接口
    expect(handle('GET', '/api/v1/ratings/boards', undefined)).toBeNull()
    // jwxt 下未覆盖的接口（例如图书馆）
    expect(handle('GET', '/api/v1/jwxt/library/capabilities', undefined)).toBeNull()
    // 完全无关的路径
    expect(handle('GET', '/past-exams/index.json', undefined)).toBeNull()
  })

  it('响应体符合前端约定的 code/message/data 结构', () => {
    const handle = loggedInHandler()
    const body = bodyOf(handle('GET', '/api/v1/jwxt/profile', undefined))

    expect(body.code).toBe(0)
    expect(typeof body.message).toBe('string')
    expect(body.data).toBeTypeOf('object')
  })
})
