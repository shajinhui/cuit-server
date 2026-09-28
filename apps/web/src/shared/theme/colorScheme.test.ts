import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  COLOR_SCHEME_STORAGE_KEY,
  DEFAULT_COLOR_SCHEME_PREFERENCE,
  normalizeColorSchemePreference,
  readColorSchemePreference,
  resolveColorScheme,
  writeColorSchemePreference,
} from './colorScheme'

function stubStorage(initial: Record<string, string> = {}) {
  const values = new Map(Object.entries(initial))
  vi.stubGlobal('window', {
    localStorage: {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
      removeItem: (key: string) => values.delete(key),
    },
  })
  return values
}

describe('theme color scheme preference', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('只接受 light / dark / system，其余回落到跟随系统', () => {
    expect(normalizeColorSchemePreference('dark')).toBe('dark')
    expect(normalizeColorSchemePreference('light')).toBe('light')
    expect(normalizeColorSchemePreference('system')).toBe('system')
    expect(normalizeColorSchemePreference('DARK')).toBe(DEFAULT_COLOR_SCHEME_PREFERENCE)
    expect(normalizeColorSchemePreference(null)).toBe(DEFAULT_COLOR_SCHEME_PREFERENCE)
    expect(normalizeColorSchemePreference(undefined)).toBe(DEFAULT_COLOR_SCHEME_PREFERENCE)
  })

  it('读取失败时回落到跟随系统', () => {
    vi.stubGlobal('window', {
      localStorage: {
        getItem: () => {
          throw new Error('storage disabled')
        },
      },
    })

    expect(readColorSchemePreference()).toBe(DEFAULT_COLOR_SCHEME_PREFERENCE)
  })

  it('跟随系统时按系统配色解析，显式选择优先于系统', () => {
    vi.stubGlobal('window', { matchMedia: () => ({ matches: true }) })
    expect(resolveColorScheme('system')).toBe('dark')
    expect(resolveColorScheme('light')).toBe('light')

    vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
    expect(resolveColorScheme('system')).toBe('light')
    expect(resolveColorScheme('dark')).toBe('dark')
  })

  it('没有 matchMedia 时按浅色处理', () => {
    vi.stubGlobal('window', {})
    expect(resolveColorScheme('system')).toBe('light')
  })

  it('显式偏好写入 localStorage，回到跟随系统时清除该键', () => {
    const values = stubStorage()

    writeColorSchemePreference('dark')
    expect(values.get(COLOR_SCHEME_STORAGE_KEY)).toBe('dark')
    expect(readColorSchemePreference()).toBe('dark')

    writeColorSchemePreference('system')
    expect(values.has(COLOR_SCHEME_STORAGE_KEY)).toBe(false)
    expect(readColorSchemePreference()).toBe('system')
  })

  it('存储不可用时不抛错', () => {
    vi.stubGlobal('window', {
      localStorage: {
        setItem: () => {
          throw new Error('quota exceeded')
        },
      },
    })

    expect(() => writeColorSchemePreference('dark')).not.toThrow()
  })
})
