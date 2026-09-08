import { describe, expect, it } from 'vitest'

import { requiresAndroidAppDownload } from './androidDownload'

describe('Android app download prompt', () => {
  it('prompts Android browsers and older native apps', () => {
    expect(requiresAndroidAppDownload({ android: true, native: false })).toBe(true)
    expect(
      requiresAndroidAppDownload({ android: true, native: true, version: '0.2.1' }),
    ).toBe(true)
    expect(requiresAndroidAppDownload({ android: true, native: true })).toBe(true)
  })

  it('allows supported Android app versions to continue', () => {
    expect(
      requiresAndroidAppDownload({ android: true, native: true, version: '0.2.2' }),
    ).toBe(false)
    expect(
      requiresAndroidAppDownload({ android: true, native: true, version: '0.3.0' }),
    ).toBe(false)
    expect(
      requiresAndroidAppDownload({
        android: true,
        native: true,
        version: '0.2.0',
        build: '4',
      }),
    ).toBe(false)
  })

  it('does not affect iOS or desktop users', () => {
    expect(requiresAndroidAppDownload({ android: false, native: false })).toBe(false)
    expect(
      requiresAndroidAppDownload({ android: false, native: true, version: '0.1.0' }),
    ).toBe(false)
  })
})
