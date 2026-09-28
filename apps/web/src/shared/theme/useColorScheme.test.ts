import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { clearPageColor, applyPageColor } from '@/shared/composables/usePageTheme'
import { COLOR_SCHEME_STORAGE_KEY, resolveColorScheme } from './colorScheme'
import { clearThemeTokenCache } from './tokens'
import {
  registerColorSchemeRuntime,
  resetColorSchemeStateForTests,
  setColorSchemePreference,
  useColorScheme,
} from './useColorScheme'

/**
 * 主题运行时的行为约束：
 *  - 跟随系统时不写 data-theme，让 CSS 的 prefers-color-scheme 分支接管；
 *  - 显式选择时写 data-theme，并落盘到 localStorage；
 *  - 主题变化后令牌缓存必须失效，否则 meta theme-color 会停留在上一套配色。
 */

/** 每个令牌在浅色/深色下的解析结果，模拟真实 CSS 变量的计算值。 */
const TOKEN_VALUES: Record<string, { light: string; dark: string }> = {
  '--app-canvas': { light: '#fbfcf9', dark: '#000000' },
  '--bg-page': { light: '#f2f2f7', dark: '#1c1c1e' },
  '--bg-page-schedule': { light: '#c9d5e7', dark: '#0f141c' },
}

function resolvedToken(name: string) {
  const entry = TOKEN_VALUES[name]
  if (!entry) return ''
  return document.documentElement.dataset.theme === 'dark' ? entry.dark : entry.light
}

function installDom({ systemDark = false, stored }: { systemDark?: boolean; stored?: string } = {}) {
  const attributes = new Map<string, string>()
  const storage = new Map<string, string>(stored ? [[COLOR_SCHEME_STORAGE_KEY, stored]] : [])
  const styleValues = new Map<string, string>()

  const metaTheme = {
    content: '',
    setAttribute: (name: string, value: string) => {
      if (name === 'content') metaTheme.content = value
    },
  }

  const documentElement = {
    dataset: {} as Record<string, string>,
    style: {
      setProperty: (name: string, value: string) => styleValues.set(name, value),
      removeProperty: (name: string) => styleValues.delete(name),
    },
  }

  vi.stubGlobal('document', {
    documentElement,
    querySelector: (selector: string) => (selector.includes('theme-color') ? metaTheme : null),
  })
  vi.stubGlobal('window', {
    localStorage: {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => storage.set(key, value),
      removeItem: (key: string) => storage.delete(key),
    },
    matchMedia: () => ({
      matches: systemDark,
      addEventListener: () => undefined,
      removeEventListener: () => undefined,
    }),
  })
  vi.stubGlobal('getComputedStyle', () => ({
    getPropertyValue: (name: string) => resolvedToken(name),
  }))

  return { metaTheme, styleValues, storage, documentElement, attributes }
}

describe('主题运行时', () => {
  beforeEach(() => {
    clearThemeTokenCache()
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    clearThemeTokenCache()
  })

  it('跟随系统时不写 data-theme，交给 CSS 媒体查询', () => {
    const dom = installDom({ systemDark: true })

    resetColorSchemeStateForTests()
    const cleanup = registerColorSchemeRuntime()

    expect(dom.documentElement.dataset.theme).toBeUndefined()
    expect(resolveColorScheme('system')).toBe('dark')
    cleanup()
  })

  it('显式深色时写 data-theme=dark 并落盘', () => {
    const dom = installDom()

    resetColorSchemeStateForTests()
    setColorSchemePreference('dark')

    expect(dom.documentElement.dataset.theme).toBe('dark')
    expect(dom.storage.get(COLOR_SCHEME_STORAGE_KEY)).toBe('dark')
  })

  it('显式浅色时写 data-theme=light，切回跟随系统时移除该属性', () => {
    const dom = installDom()

    resetColorSchemeStateForTests()
    setColorSchemePreference('light')
    expect(dom.documentElement.dataset.theme).toBe('light')

    setColorSchemePreference('system')
    expect(dom.documentElement.dataset.theme).toBeUndefined()
    expect(dom.storage.has(COLOR_SCHEME_STORAGE_KEY)).toBe(false)
  })

  it('主题切换后重新解析令牌（令牌缓存失效）', () => {
    installDom()

    resetColorSchemeStateForTests()
    setColorSchemePreference('light')
    expect(resolvedToken('--app-canvas')).toBe('#fbfcf9')

    setColorSchemePreference('dark')
    expect(resolvedToken('--app-canvas')).toBe('#000000')
    expect(useColorScheme().resolved.value).toBe('dark')
  })
})

describe('页面底色与浏览器 UI 同步', () => {
  beforeEach(() => clearThemeTokenCache())
  afterEach(() => {
    vi.unstubAllGlobals()
    clearThemeTokenCache()
  })

  it('把令牌解析成具体色值写入 --page-bg、meta theme-color 与系统栏', () => {
    const dom = installDom()

    resetColorSchemeStateForTests()
    setColorSchemePreference('light')
    applyPageColor('bg-page-schedule', 'light')

    expect(dom.styleValues.get('--page-bg')).toBe('#c9d5e7')
    expect(dom.metaTheme.content).toBe('#c9d5e7')
  })

  it('深色下同一个令牌解析出深色值', () => {
    const dom = installDom()

    resetColorSchemeStateForTests()
    setColorSchemePreference('dark')
    applyPageColor('bg-page-schedule', 'dark')

    expect(dom.styleValues.get('--page-bg')).toBe('#0f141c')
    expect(dom.metaTheme.content).toBe('#0f141c')
  })

  it('清除页面底色后回落到画布色', () => {
    const dom = installDom()

    resetColorSchemeStateForTests()
    setColorSchemePreference('light')
    applyPageColor('bg-page', 'light')
    clearPageColor('light')

    expect(dom.styleValues.has('--page-bg')).toBe(false)
    expect(dom.metaTheme.content).toBe('#fbfcf9')
  })
})
