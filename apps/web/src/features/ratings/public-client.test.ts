import { beforeEach, expect, it, vi } from 'vitest'
import { publicRatingsRequest } from './client'
import { getRatingAccessToken } from './auth'

vi.mock('./auth', () => ({ getRatingAccessToken: vi.fn(), clearRatingAccessToken: vi.fn(), currentRatingSessionGeneration: vi.fn() }))
const fetchMock = vi.fn()
beforeEach(() => { vi.stubGlobal('fetch', fetchMock); fetchMock.mockReset() })
it('公告公开请求禁用浏览器缓存，不申请凭证、不发送 Cookie 或 Authorization', async () => {
  fetchMock.mockResolvedValue(new Response(JSON.stringify({ code: 0, data: { items: [] } }), { status: 200 }))
  expect(await publicRatingsRequest('/api/v1/ratings/announcements?platform=android')).toEqual({ items: [] })
  const options = fetchMock.mock.calls[0]?.[1] as RequestInit
  expect(options.credentials).toBe('omit')
  expect(options.cache).toBe('no-store')
  expect(options.redirect).toBe('error')
  expect(options.headers).not.toHaveProperty('Authorization')
  expect(getRatingAccessToken).not.toHaveBeenCalled()
})
it('公告业务错误和 HTML 错误页均不当作成功数据', async () => {
  fetchMock.mockResolvedValue(new Response(JSON.stringify({ code: 50000, message: 'safe error', data: null }), { status: 500 }))
  await expect(publicRatingsRequest('/api/v1/ratings/announcements')).rejects.toThrow()
  fetchMock.mockResolvedValue(new Response('<html>temporary error</html>', { status: 502 }))
  await expect(publicRatingsRequest('/api/v1/ratings/announcements')).rejects.toThrow('响应格式异常')
})
