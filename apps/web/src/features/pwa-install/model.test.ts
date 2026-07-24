import { describe, expect, it } from 'vitest'

import { isInstalledDisplay, resolveInstallGuide } from './model'

describe('PWA install guidance', () => {
  it('sends embedded browsers to a system browser first', () => {
    expect(resolveInstallGuide('Mozilla/5.0 MicroMessenger/8.0').kind).toBe('embedded')
    expect(resolveInstallGuide('Mozilla/5.0 DingTalk/7.6').kind).toBe('embedded')
  })

  it('provides browser-specific Android guidance', () => {
    expect(resolveInstallGuide('Mozilla/5.0 SamsungBrowser/27.0 Chrome/125.0').kind).toBe(
      'samsung',
    )
    expect(resolveInstallGuide('Mozilla/5.0 Firefox/128.0').kind).toBe('firefox')
    expect(resolveInstallGuide('Mozilla/5.0 MiuiBrowser/19.0 Chrome/125.0').kind).toBe(
      'chromium',
    )
  })

  it('uses the share-menu flow for Safari on iPhone and iPad', () => {
    const iphoneSafari =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Version/18.5 Mobile/15E148 Safari/604.1'
    const ipadDesktopSafari =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 Version/18.5 Mobile/15E148 Safari/604.1'

    expect(resolveInstallGuide(iphoneSafari)).toMatchObject({
      kind: 'ios',
      browserName: 'Safari',
    })
    expect(resolveInstallGuide(ipadDesktopSafari).kind).toBe('ios')
  })

  it('falls back to generic menu instructions for unknown browsers', () => {
    expect(resolveInstallGuide('Unknown Mobile Browser').kind).toBe('generic')
  })

  it('recognizes standalone, fullscreen, minimal UI, and Android TWA launches', () => {
    expect(isInstalledDisplay({ displayModes: ['standalone'], referrer: '' })).toBe(true)
    expect(isInstalledDisplay({ displayModes: ['fullscreen'], referrer: '' })).toBe(true)
    expect(isInstalledDisplay({ displayModes: ['minimal-ui'], referrer: '' })).toBe(true)
    expect(
      isInstalledDisplay({ displayModes: [], referrer: 'android-app://com.example.app' }),
    ).toBe(true)
    expect(isInstalledDisplay({ displayModes: [], referrer: '', standalone: true })).toBe(true)
    expect(isInstalledDisplay({ displayModes: [], referrer: '' })).toBe(false)
  })
})
