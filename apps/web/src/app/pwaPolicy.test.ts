import { describe, expect, it } from 'vitest'

import { freshNavigationPatterns, freshSiteRuntimeCaching, isOfficialPagePath } from './pwaPolicy'

describe('官网与应用的 PWA 缓存边界', () => {
  it('官网路径不注册新的应用 Service Worker', () => {
    expect(isOfficialPagePath('/official')).toBe(true)
    expect(isOfficialPagePath('/official/')).toBe(true)
    expect(isOfficialPagePath('/schedule')).toBe(false)
    expect(isOfficialPagePath('/official-other')).toBe(false)
  })

  it.each(['/official', '/official/', '/official?source=app', '/downloads/android', '/downloads/android?source=app'])(
    '%s 不使用缓存的应用入口',
    (path) => {
      expect(freshNavigationPatterns.some((pattern) => pattern.test(path))).toBe(true)
      const rule = freshSiteRuntimeCaching[0]
      expect(rule.urlPattern({ url: new URL(path, 'https://example.com') })).toBe(true)
      expect(rule.handler).toBe('NetworkOnly')
      expect(rule.options.fetchOptions.cache).toBe('no-store')
    },
  )

  it.each(['/schedule', '/tools', '/profile', '/login'])(
    '%s 保留原有应用离线策略',
    (path) => {
      expect(freshNavigationPatterns.some((pattern) => pattern.test(path))).toBe(false)
      expect(freshSiteRuntimeCaching[0].urlPattern({ url: new URL(path, 'https://example.com') })).toBe(false)
    },
  )
})
