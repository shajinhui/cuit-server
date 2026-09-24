import { describe, expect, it } from 'vitest'

import { detectIosMajorVersion, shouldApplyIosTopScrim } from './iosTopScrim'

const iPhoneUA = (major: number) =>
  `Mozilla/5.0 (iPhone; CPU iPhone OS ${major}_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148`
const iPadUA = (major: number) =>
  `Mozilla/5.0 (iPad; CPU OS ${major}_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148`

describe('iOS top scrim detection', () => {
  it('reads the major version from iPhone and iPad user agents', () => {
    expect(detectIosMajorVersion(iPhoneUA(27))).toBe(27)
    expect(detectIosMajorVersion(iPadUA(26))).toBe(26)
    expect(
      detectIosMajorVersion(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1',
      ),
    ).toBe(27)
    expect(detectIosMajorVersion('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)')).toBeUndefined()
    expect(detectIosMajorVersion('Mozilla/5.0 (Linux; Android 15; SM-S9280)')).toBeUndefined()
  })

  it('applies to installed web apps and the native shell on iOS 27 and later', () => {
    expect(
      shouldApplyIosTopScrim({ userAgent: iPhoneUA(27), installedWebApp: true, nativeIos: false }),
    ).toBe(true)
    expect(
      shouldApplyIosTopScrim({ userAgent: iPhoneUA(28), installedWebApp: true, nativeIos: false }),
    ).toBe(true)
    expect(
      shouldApplyIosTopScrim({ userAgent: iPadUA(27), installedWebApp: false, nativeIos: true }),
    ).toBe(true)
  })

  it('stays off in Safari tabs, on iOS 26 and on other platforms', () => {
    expect(
      shouldApplyIosTopScrim({ userAgent: iPhoneUA(27), installedWebApp: false, nativeIos: false }),
    ).toBe(false)
    expect(
      shouldApplyIosTopScrim({ userAgent: iPhoneUA(26), installedWebApp: true, nativeIos: false }),
    ).toBe(false)
    expect(
      shouldApplyIosTopScrim({
        userAgent: 'Mozilla/5.0 (Linux; Android 15; SM-S9280)',
        installedWebApp: true,
        nativeIos: true,
      }),
    ).toBe(false)
  })
})
