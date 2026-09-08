import { describe, expect, it } from 'vitest'

import { detectClientDevice, normalizeAndroidBrand } from './clientDevice'

describe('client device detection', () => {
  it('identifies Apple mobile devices', () => {
    expect(detectClientDevice('Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X)')).toEqual({
      platform: 'ios',
      brand: 'Apple',
    })
    expect(detectClientDevice('Mozilla/5.0 (Macintosh)', {
      platform: 'MacIntel',
      maxTouchPoints: 5,
    })).toEqual({ platform: 'ios', brand: 'Apple' })
  })

  it('identifies common Android brands', () => {
    expect(detectClientDevice('Mozilla/5.0 (Linux; Android 15; SM-S9280 Build/AP3A)')).toEqual({
      platform: 'android',
      brand: 'Samsung',
    })
    expect(detectClientDevice('Mozilla/5.0 (Linux; Android 14; CPH2607 Build/UKQ1)')).toEqual({
      platform: 'android',
      brand: 'OPPO',
    })
  })

  it('groups unrecognized Android devices without classifying desktop browsers', () => {
    expect(detectClientDevice('Mozilla/5.0 (Linux; Android 15; ABC123 Build/AP3A)')).toEqual({
      platform: 'android',
      brand: 'Other',
    })
    expect(detectClientDevice('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)')).toBeUndefined()
  })

  it('normalizes native manufacturer names', () => {
    expect(normalizeAndroidBrand('Xiaomi 23113RKC6C')).toBe('Xiaomi')
    expect(normalizeAndroidBrand('Google Pixel 9')).toBe('Google')
    expect(normalizeAndroidBrand('unknown ABC123')).toBe('Other')
  })
})
