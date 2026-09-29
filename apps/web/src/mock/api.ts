import type { ExamType } from '@/features/exams/api'

import {
  currentSemesterID,
  mockAvailableClassrooms,
  mockClassroomOptions,
  mockClassroomSchedule,
  mockCourseTable,
  mockCurrentWeek,
  mockExams,
  mockGrades,
  mockPassword,
  mockPlanCompletion,
  mockProfile,
  mockSemesters,
  mockStudentNo,
} from './fixtures'

export interface MockResponse {
  status: number
  body: unknown
}

/** 与 Go 端 apiresponse.Success 一致：code 为 0 表示成功。 */
function ok(data: unknown): MockResponse {
  return { status: 200, body: { code: 0, message: '', data } }
}

function fail(status: number, code: number, message: string): MockResponse {
  return { status, body: { code, message, data: null } }
}

function parseExamType(value: string | null): ExamType | null {
  return value === 'final' || value === 'makeup' ? value : null
}

function readLoginBody(body: unknown): { username: string; password: string } {
  if (typeof body !== 'object' || body === null) return { username: '', password: '' }
  const record = body as Record<string, unknown>
  return {
    username: typeof record.username === 'string' ? record.username.trim() : '',
    password: typeof record.password === 'string' ? record.password : '',
  }
}

/**
 * 创建 mock 处理器。
 *
 * 返回 null 表示"这个请求不归我管"，由 dev server 继续走正常代理，
 * 所以评分、校园跑这些接口仍然连真实后端。
 *
 * authenticated 是 dev server 进程内的状态：刷新页面不会掉登录，
 * 重启 dev server 才会。演示账号见 fixtures.ts。
 */
export function createMockHandler() {
  let authenticated = false

  return function handle(method: string, rawURL: string, body: unknown): MockResponse | null {
    const url = new URL(rawURL, 'http://mock.local')
    const path = url.pathname

    if (path === '/api/v1/schedule/current-week') {
      return ok({ CurrentWeek: mockCurrentWeek })
    }

    if (!path.startsWith('/api/v1/jwxt/')) return null

    if (path === '/api/v1/jwxt/session') {
      if (method === 'POST') {
        const { username, password } = readLoginBody(body)
        if (username === mockStudentNo && password === mockPassword) {
          authenticated = true
          return ok({ authenticated: true })
        }
        return fail(401, 40101, '学号或密码不正确')
      }
      if (method === 'DELETE') {
        authenticated = false
        return ok({ authenticated: false })
      }
      return ok({ authenticated })
    }

    // 其余 jwxt 接口都要求先登录，和真实后端行为保持一致。
    if (!authenticated) {
      return fail(401, 40100, '登录已过期，请重新登录')
    }

    switch (path) {
      case '/api/v1/jwxt/profile':
        return ok(mockProfile)
      case '/api/v1/jwxt/semesters':
        return ok(mockSemesters)
      case '/api/v1/jwxt/plan-completion':
        return ok(mockPlanCompletion)
      case '/api/v1/jwxt/course-table':
        return ok(mockCourseTable(url.searchParams.get('semester_id') ?? currentSemesterID))
      case '/api/v1/jwxt/grades':
        return ok(mockGrades(url.searchParams.get('semester_id') ?? currentSemesterID))
      case '/api/v1/jwxt/exams':
        return ok(
          mockExams(
            url.searchParams.get('semester_id') ?? currentSemesterID,
            parseExamType(url.searchParams.get('exam_type')),
          ),
        )
      case '/api/v1/jwxt/classroom-options':
        return ok(mockClassroomOptions)
      case '/api/v1/jwxt/available-classrooms':
        return ok(mockAvailableClassrooms())
      case '/api/v1/jwxt/classroom-schedule':
        return ok(
          mockClassroomSchedule(
            url.searchParams.get('semester_id') ?? currentSemesterID,
            url.searchParams.get('campus_id') ?? '',
          ),
        )
      default:
        // 没有演示数据的接口（图书馆等）继续走真实代理。
        return null
    }
  }
}
