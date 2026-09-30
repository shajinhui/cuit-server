import { createMockHandler, type MockResponse } from './api'
import { mockPassword, mockStudentNo } from './fixtures'

const demoSessionStorageKey = 'cuit-demo-jwxt-session'

/**
 * 浏览器端演示账号开关。
 *
 * 生产构建默认开启，方便官网直接体验；设置 VITE_DEMO_ACCOUNT_ENABLED=false
 * 可在需要时完全关闭。开发期则由 VITE_MOCK_API=true 或显式 true 开启。
 */
export function isDemoAccountEnabled() {
  const configured = import.meta.env.VITE_DEMO_ACCOUNT_ENABLED
  if (configured === 'false') return false
  return configured === 'true' || import.meta.env.PROD || import.meta.env.VITE_MOCK_API === 'true'
}

function readBody(options: RequestInit): unknown {
  if (typeof options.body !== 'string') return undefined
  try {
    return JSON.parse(options.body)
  } catch {
    return undefined
  }
}

function hasStoredDemoSession() {
  if (typeof window === 'undefined') return false
  try {
    return window.sessionStorage.getItem(demoSessionStorageKey) === '1'
  } catch {
    return false
  }
}

function setStoredDemoSession(active: boolean) {
  if (typeof window === 'undefined') return
  try {
    if (active) window.sessionStorage.setItem(demoSessionStorageKey, '1')
    else window.sessionStorage.removeItem(demoSessionStorageKey)
  } catch {
    // 存储不可用时仍允许当前页面内的演示会话继续工作。
  }
}

function readCredentials(body: unknown) {
  if (typeof body !== 'object' || body === null) return { username: '', password: '' }
  const record = body as Record<string, unknown>
  return {
    username: typeof record.username === 'string' ? record.username.trim() : '',
    password: typeof record.password === 'string' ? record.password : '',
  }
}

/**
 * 创建浏览器端演示请求路由。
 *
 * 返回 null 表示交给真实 API。除虚构演示账号外，不会吞掉任何真实登录或业务请求。
 */
export function createDemoRequestRouter(enabled: boolean) {
  let handler = enabled && hasStoredDemoSession() ? createMockHandler() : undefined
  let active = false

  if (handler) {
    const restored = handler('POST', '/api/v1/jwxt/session', {
      username: mockStudentNo,
      password: mockPassword,
    })
    active = restored?.status === 200
    if (!active) handler = undefined
  }

  return function route(path: string, options: RequestInit = {}): MockResponse | null {
    if (!enabled) return null

    const method = (options.method ?? 'GET').toUpperCase()
    const body = readBody(options)

    if (path === '/api/v1/jwxt/session' && method === 'POST') {
      const { username, password } = readCredentials(body)
      if (username !== mockStudentNo || password !== mockPassword) {
        // 切换到真实账号时先结束当前演示会话，后续请求继续走真实服务。
        handler = undefined
        active = false
        setStoredDemoSession(false)
        return null
      }

      handler = createMockHandler()
      const response = handler(method, path, body)
      active = response?.status === 200
      setStoredDemoSession(active)
      return response
    }

    if (!active || !handler) return null

    if (path === '/api/v1/jwxt/session' && method === 'DELETE') {
      const response = handler(method, path, body)
      handler = undefined
      active = false
      setStoredDemoSession(false)
      return response
    }

    if (!path.startsWith('/api/v1/jwxt/') && path !== '/api/v1/schedule/current-week') return null
    return handler(method, path, body)
  }
}

const browserDemoRequestRouter = createDemoRequestRouter(isDemoAccountEnabled())

export function requestDemoResponse(path: string, options: RequestInit = {}) {
  return browserDemoRequestRouter(path, options)
}
