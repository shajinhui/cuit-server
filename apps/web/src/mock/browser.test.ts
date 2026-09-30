import { describe, expect, it } from 'vitest'

import { createDemoRequestRouter } from './browser'

describe('浏览器端演示账号路由', () => {
  it('只接管演示账号并返回虚拟教务数据', () => {
    const route = createDemoRequestRouter(true)

    expect(
      route('/api/v1/jwxt/session', {
        method: 'POST',
        body: JSON.stringify({ username: '20240000', password: 'demo' }),
      }),
    ).toMatchObject({ status: 200 })

    const profile = route('/api/v1/jwxt/profile')
    expect(profile).toMatchObject({ status: 200 })
    expect((profile?.body as { data: { StudentNo: string } }).data.StudentNo).toBe('20240000')
  })

  it('真实账号不被拦截', () => {
    const route = createDemoRequestRouter(true)
    expect(
      route('/api/v1/jwxt/session', {
        method: 'POST',
        body: JSON.stringify({ username: 'real-user', password: 'real-password' }),
      }),
    ).toBeNull()
  })

  it('退出后不再拦截教务请求', () => {
    const route = createDemoRequestRouter(true)
    route('/api/v1/jwxt/session', {
      method: 'POST',
      body: JSON.stringify({ username: '20240000', password: 'demo' }),
    })
    expect(route('/api/v1/jwxt/session', { method: 'DELETE' })).toMatchObject({ status: 200 })
    expect(route('/api/v1/jwxt/profile')).toBeNull()
  })
})
