import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  DEFAULT_NON_CURRENT_WEEK_OPACITY,
  normalizeNonCurrentWeekOpacity,
  readNonCurrentWeekOpacity,
  writeNonCurrentWeekOpacity,
} from './displayPreferences'

describe('schedule display preferences', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('clamps non-current-week opacity to the supported range', () => {
    expect(normalizeNonCurrentWeekOpacity(0.05)).toBe(0.2)
    expect(normalizeNonCurrentWeekOpacity(0.65)).toBe(0.65)
    expect(normalizeNonCurrentWeekOpacity(1.5)).toBe(1)
    expect(normalizeNonCurrentWeekOpacity(Number.NaN)).toBe(DEFAULT_NON_CURRENT_WEEK_OPACITY)
  })

  it('restores and writes the preference in local storage', () => {
    const values = new Map<string, string>([['schedule-non-current-week-opacity', '0.7']])
    vi.stubGlobal('window', {
      localStorage: {
        getItem: (key: string) => values.get(key) ?? null,
        setItem: (key: string, value: string) => values.set(key, value),
      },
    })

    expect(readNonCurrentWeekOpacity()).toBe(0.7)
    expect(writeNonCurrentWeekOpacity(0.9)).toBe(0.9)
    expect(values.get('schedule-non-current-week-opacity')).toBe('0.9')
  })
})
