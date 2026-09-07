import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  AutoRunApiError,
  DEFAULT_AUTORUN_API_BASE_URL,
  getAutoRunInfo,
  loginToAutoRun,
} from './api'

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('校园跑 API 客户端', () => {
  it('登录只发送手机号和密码', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      Response.json({
        code: 10000,
        msg: 'ok',
        response: {
          userId: 1,
          studentId: 2,
          schoolId: 3,
          tokenSrc: 'login',
          sessionKey: 'session-example',
        },
      }),
    )
    vi.stubGlobal('fetch', fetchMock)

    await loginToAutoRun('13800000000', 'example-password')

    expect(fetchMock).toHaveBeenCalledWith(
      `${DEFAULT_AUTORUN_API_BASE_URL}/api/login`,
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ phone: '13800000000', password: 'example-password' }),
      }),
    )
    const request = fetchMock.mock.calls[0]?.[1] as RequestInit
    expect(request.headers).not.toHaveProperty('Authorization')
  })

  it('后续业务请求通过 Bearer 请求头发送会话密钥', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      Response.json({
        code: 10000,
        msg: 'ok',
        response: { runStandard: {}, runInfo: {} },
      }),
    )
    vi.stubGlobal('fetch', fetchMock)

    await getAutoRunInfo('session-example')

    const request = fetchMock.mock.calls[0]?.[1] as RequestInit
    expect(request.headers).toMatchObject({ Authorization: 'Bearer session-example' })
    expect(request.body).toBe('{}')
  })

  it('拒绝非 JSON 响应和业务错误响应', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(new Response('<html>error</html>', { status: 502 }))
      .mockResolvedValueOnce(
        Response.json({ code: 40100, msg: '登录态已过期', response: {} }, { status: 401 }),
      )
    vi.stubGlobal('fetch', fetchMock)

    await expect(getAutoRunInfo('expired')).rejects.toMatchObject({
      message: '服务响应格式异常',
      status: 502,
    })
    await expect(getAutoRunInfo('expired')).rejects.toEqual(
      new AutoRunApiError('登录态已过期', 401, 40100),
    )
  })
})
