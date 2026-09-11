import { describe, expect, it } from 'vitest'

import { isIOSWebDevice } from './download'

describe('历年试卷文件下载平台识别', () => {
  it('识别 iPhone、iPad 桌面模式并排除安卓', () => {
    expect(isIOSWebDevice('Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)', 'iPhone', 5)).toBe(true)
    expect(isIOSWebDevice('Mozilla/5.0 (Macintosh)', 'MacIntel', 5)).toBe(true)
    expect(isIOSWebDevice('Mozilla/5.0 (Linux; Android 16)', 'Linux armv8l', 5)).toBe(false)
  })
})
