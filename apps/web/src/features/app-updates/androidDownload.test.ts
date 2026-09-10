import { describe, expect, it } from 'vitest'

import { requiresAndroidAppDownload, requiresAndroidFirstVisitDownload } from './androidDownload'

describe('Android app download prompt', () => {
  it('prompts Android browsers and older native apps', () => {
    expect(requiresAndroidAppDownload({ android: true, native: false })).toBe(true)
    expect(
      requiresAndroidAppDownload({ android: true, native: true, version: '0.2.2' }),
    ).toBe(true)
    expect(requiresAndroidAppDownload({ android: true, native: true })).toBe(true)
  })

  it('allows supported Android app versions to continue', () => {
    expect(
      requiresAndroidAppDownload({ android: true, native: true, version: '0.2.3' }),
    ).toBe(false)
    expect(
      requiresAndroidAppDownload({ android: true, native: true, version: '0.3.0' }),
    ).toBe(false)
    expect(
      requiresAndroidAppDownload({
        android: true,
        native: true,
        version: '0.2.2',
        build: '6',
      }),
    ).toBe(false)
  })

  it('keeps build 5 on the update path', () => {
    expect(
      requiresAndroidAppDownload({
        android: true,
        native: true,
        version: '0.2.2',
        build: '5',
      }),
    ).toBe(true)
  })

  it('does not affect iOS or desktop users', () => {
    expect(requiresAndroidAppDownload({ android: false, native: false })).toBe(false)
    expect(
      requiresAndroidAppDownload({ android: false, native: true, version: '0.1.0' }),
    ).toBe(false)
  })

  it('prompts an Android browser only on its first website visit', () => {
    expect(
      requiresAndroidFirstVisitDownload({ android: true, native: false, promptSeen: false }),
    ).toBe(true)
    expect(
      requiresAndroidFirstVisitDownload({ android: true, native: false, promptSeen: true }),
    ).toBe(false)
    expect(
      requiresAndroidFirstVisitDownload({ android: true, native: true, promptSeen: false }),
    ).toBe(false)
    expect(
      requiresAndroidFirstVisitDownload({ android: false, native: false, promptSeen: false }),
    ).toBe(false)
  })
})
