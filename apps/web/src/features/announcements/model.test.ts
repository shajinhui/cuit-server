import { describe, expect, it } from 'vitest'

import { isAnnouncementUnread } from './model'

describe('isAnnouncementUnread', () => {
  it('在设备没有阅读记录时展示公告', () => {
    expect(isAnnouncementUnread(null, 'announcement-2')).toBe(true)
  })

  it('公告 ID 更新后重新展示', () => {
    expect(isAnnouncementUnread('announcement-1', 'announcement-2')).toBe(true)
  })

  it('同一公告已经阅读后不再展示', () => {
    expect(isAnnouncementUnread('announcement-2', 'announcement-2')).toBe(false)
  })
})
