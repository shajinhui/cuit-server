import { afterEach, describe, expect, it, vi } from 'vitest'

import { onRequestGet, onRequestHead } from '../../../functions/downloads/android'

import { ANDROID_DOWNLOAD_URL, LATEST_ANDROID_APK_URL } from './downloads'

describe('安卓最新版固定下载入口', () => {
  afterEach(() => {
    vi.doUnmock('./downloads')
    vi.resetModules()
  })

  it.each([onRequestGet, onRequestHead])('GET 和 HEAD 都跳转到最新 APK，且不缓存结果', (handler) => {
    const response = handler()

    expect(response.status).toBe(302)
    expect(response.headers.get('Location')).toBe(LATEST_ANDROID_APK_URL)
    expect(response.headers.get('Cache-Control')).toBe('no-store, max-age=0')
    expect(response.body).toBeNull()
    expect(LATEST_ANDROID_APK_URL).toBe(
      'https://gitee.com/fanxiaogao05/cuit-server/releases/download/1.0.0/chengxin-youyou-android-layout-fix2.apk',
    )
  })

  it('服务器换包后，旧页面保留的固定入口无需更新', async () => {
    const cachedPageDownloadURL = ANDROID_DOWNLOAD_URL
    const newAPK = 'https://packages.example.com/android-new.apk'
    vi.doMock('./downloads', () => ({ LATEST_ANDROID_APK_URL: newAPK }))
    vi.resetModules()
    const { onRequestGet: updatedDownload } = await import('../../../functions/downloads/android')

    expect(cachedPageDownloadURL).toBe('https://fanxiaogao05.dpdns.org/downloads/android')
    expect(updatedDownload().headers.get('Location')).toBe(newAPK)
    expect(updatedDownload().headers.get('Cache-Control')).toContain('no-store')
  })
})
