import { afterEach, describe, expect, it, vi } from 'vitest'

import { ApiError, request } from './client'

describe('API client', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
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
