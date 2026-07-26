import { describe, expect, it } from 'vitest'

import {
  parseAndroidUpdateManifest,
  shouldDownloadAndroidUpdate,
  type AndroidUpdateManifest,
} from './model'

const manifestURL =
  'https://fanxiaogao05.dpdns.org/app-updates/android/latest.json'
const validManifest: AndroidUpdateManifest = {
  schema: 1,
  platform: 'android',
  channel: 'stable',
  version: '0.2.0-web.abc123',
  nativeVersion: '0.2.0',
  title: '新版本已准备好',
  releaseNotes: '新增历年试卷功能。',
  url: 'https://fanxiaogao05.dpdns.org/app-updates/android/bundles/update.zip',
  fallbackUrl:
    'https://abc123.cuit-server.pages.dev/app-updates/android/bundles/update.zip',
  checksum: 'a'.repeat(64),
  publishedAt: '2026-07-25T08:00:00.000Z',
}

describe('parseAndroidUpdateManifest', () => {
  it('accepts a valid Cloudflare Pages bundle', () => {
    expect(parseAndroidUpdateManifest(validManifest, manifestURL)).toEqual(
      validManifest,
    )
  })

  it('rejects insecure or unrelated bundle origins', () => {
    expect(
      parseAndroidUpdateManifest(
        { ...validManifest, url: 'http://example.com/update.zip' },
        manifestURL,
      ),
    ).toBeNull()
    expect(
      parseAndroidUpdateManifest(
        { ...validManifest, url: 'https://example.com/update.zip' },
        manifestURL,
      ),
    ).toBeNull()
  })

  it('rejects malformed checksums and non-semver versions', () => {
    expect(
      parseAndroidUpdateManifest(
        { ...validManifest, checksum: 'not-a-sha256' },
        manifestURL,
      ),
    ).toBeNull()
    expect(
      parseAndroidUpdateManifest(
        { ...validManifest, version: 'web-latest' },
        manifestURL,
      ),
    ).toBeNull()
  })

  it('rejects empty or oversized update copy', () => {
    expect(
      parseAndroidUpdateManifest(
        { ...validManifest, title: '   ' },
        manifestURL,
      ),
    ).toBeNull()
    expect(
      parseAndroidUpdateManifest(
        { ...validManifest, releaseNotes: 'a'.repeat(501) },
        manifestURL,
      ),
    ).toBeNull()
  })
})

describe('shouldDownloadAndroidUpdate', () => {
  it('only updates the matching native shell', () => {
    expect(
      shouldDownloadAndroidUpdate(validManifest, '0.2.0', '0.2.0'),
    ).toBe(true)
    expect(
      shouldDownloadAndroidUpdate(validManifest, '0.1.0', '0.1.0'),
    ).toBe(false)
  })

  it('does not redownload the active or already queued version', () => {
    expect(
      shouldDownloadAndroidUpdate(
        validManifest,
        '0.2.0',
        validManifest.version,
      ),
    ).toBe(false)
    expect(
      shouldDownloadAndroidUpdate(
        validManifest,
        '0.2.0',
        '0.2.0',
        validManifest.version,
      ),
    ).toBe(false)
  })
})
