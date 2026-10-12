import { afterEach, describe, expect, it, vi } from 'vitest'

import { ApiError, request, resolveApiBaseURL } from './client'

describe('API client', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('生产构建缺少地址时使用正式 API，保留显式配置和开发代理', () => {
    expect(resolveApiBaseURL(undefined, true)).toBe('https://api.fanxiaogao05.dpdns.org')
    expect(resolveApiBaseURL('', true)).toBe('https://api.fanxiaogao05.dpdns.org')
    expect(resolveApiBaseURL('  ', true)).toBe('https://api.fanxiaogao05.dpdns.org')
    expect(resolveApiBaseURL('https://api.example.com/', true)).toBe('https://api.example.com')
    expect(resolveApiBaseURL(undefined, false)).toBe('')
    expect(resolveApiBaseURL('http://localhost:8888/', false)).toBe('http://localhost:8888')
  })

  it('生产登录请求实际发往 API 域名，而不是静态官网', async () => {
    vi.stubEnv('PROD', true)
    vi.stubEnv('VITE_API_BASE_URL', '')
    vi.resetModules()
    const { request: productionRequest } = await import('./client')
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ code: 0, message: 'success', data: { authenticated: true } })),
    )
    vi.stubGlobal('fetch', fetchMock)

    await expect(productionRequest('/api/v1/jwxt/session', { method: 'POST' })).resolves.toEqual({
      authenticated: true,
    })
    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.fanxiaogao05.dpdns.org/api/v1/jwxt/session',
      expect.objectContaining({ method: 'POST', credentials: 'include' }),
    )
  })

  it('preserves Retry-After from a busy response', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            code: 50301,
            message: '当前登录人数较多，请稍后重试',
            data: null,
          }),
          {
            status: 503,
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': '5',
            },
          },
        ),
      ),
    )

    const error = await request('/api/v1/jwxt/session', { method: 'POST' }).catch(
      (reason: unknown) => reason,
    )

    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({
      status: 503,
      code: 50301,
      retryAfterSeconds: 5,
    })
  })
})
