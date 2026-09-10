import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  AUTORUN_LOGIN_TIMEOUT_MS,
  AutoRunApiError,
  DEFAULT_AUTORUN_API_BASE_URL,
  getAutoRunInfo,
  isAutoRunAuthExpiredError,
  loginToAutoRun,
  prepareAutoRun,
  signAutoRunClub,
  submitAutoRun,
} from './api'

afterEach(() => {
  vi.useRealTimers()
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

  it('跑步轨迹由前端生成后作为 record 交给服务端签名转发', async () => {
    const fetchMock = vi
      .fn()
      .mockImplementation(() =>
        Promise.resolve(Response.json({ code: 10000, msg: 'ok', response: { success: true } })),
      )
    vi.stubGlobal('fetch', fetchMock)
    await prepareAutoRun('session-example')
    const record = {
      againRunStatus: '0',
      againRunTime: 0,
      appVersions: '1.8.5',
      brand: 'Xiaomi',
      mobileType: 'Mi 11',
      sysVersions: 'Android 11',
      trackPoints: '30,103,1',
      distanceTimeStatus: '1',
      innerSchool: '1',
      runDistance: 5000,
      runTime: 33,
      userId: 1,
      vocalStatus: '1',
      yearSemester: '2026-2027-1',
      recordDate: '2026-09-10',
      realityTrackPoints: '30,103--',
    }
    await submitAutoRun('session-example', record)

    expect(fetchMock.mock.calls[0]?.[0]).toBe(`${DEFAULT_AUTORUN_API_BASE_URL}/api/run_prepare`)
    const submit = fetchMock.mock.calls[1]?.[1] as RequestInit
    expect(submit.body).toBe(JSON.stringify({ record }))
  })

  it('俱乐部手动签到把当前活动和坐标直接交给服务端', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      Response.json({ code: 10000, msg: 'ok', response: { success: true } }),
    )
    vi.stubGlobal('fetch', fetchMock)
    await signAutoRunClub('session-example', {
      activityId: 12,
      latitude: '30.1',
      longitude: '103.9',
      signType: '1',
    })
    const request = fetchMock.mock.calls[0]?.[1] as RequestInit
    expect(request.body).toBe(
      JSON.stringify({ activityId: 12, latitude: '30.1', longitude: '103.9', signType: '1' }),
    )
  })

  it('能识别被 502 包装的上游登录失效错误', () => {
    expect(
      isAutoRunAuthExpiredError(
        new AutoRunApiError('加载校园跑进度失败：token 已失效，请重新登录', 502, 50200),
      ),
    ).toBe(true)
    expect(
      isAutoRunAuthExpiredError(
        new AutoRunApiError('加载校园跑进度失败：上游网络请求失败', 502, 50200),
      ),
    ).toBe(false)
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

  it('登录请求超过 20 秒后中断并返回超时提示', async () => {
    vi.useFakeTimers()
    const fetchMock = vi.fn().mockImplementation(
      (_input: RequestInfo | URL, init?: RequestInit) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener('abort', () => reject(new Error('aborted')))
        }),
    )
    vi.stubGlobal('fetch', fetchMock)

    const loginRequest = loginToAutoRun('13800000000', 'example-password')
    const rejection = expect(loginRequest).rejects.toMatchObject({
      message: '请求超时，请检查网络后重试',
      status: 0,
      code: 40800,
    })

    await vi.advanceTimersByTimeAsync(AUTORUN_LOGIN_TIMEOUT_MS)
    await rejection

    const request = fetchMock.mock.calls[0]?.[1] as RequestInit
    expect(request.signal?.aborted).toBe(true)
  })

  it('网络连接失败时返回可读提示', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))

    await expect(loginToAutoRun('13800000000', 'example-password')).rejects.toMatchObject({
      message: '无法连接校园跑服务，请检查网络后重试',
      status: 0,
      code: 50300,
    })
  })
})
