import { describe, expect, it } from 'vitest'

import {
  getAnnouncementViewCount,
  recordAnnouncementPresentation,
  shouldAutoPresentAnnouncement,
} from './model'

describe('announcement presentation state', () => {
  it('没有展示记录时需要自动展示', () => {
    expect(shouldAutoPresentAnnouncement(null, 'announcement-2')).toBe(true)
  })

  it('同一公告展示一次后仍会再次自动展示', () => {
    const state = { id: 'announcement-2', viewCount: 1 }
    expect(shouldAutoPresentAnnouncement(state, 'announcement-2')).toBe(true)
  })

  it('同一公告展示两次后停止自动展示', () => {
    const state = { id: 'announcement-2', viewCount: 2 }
    expect(shouldAutoPresentAnnouncement(state, 'announcement-2')).toBe(false)
  })

  it('公告 ID 更新后重新从零计数', () => {
    const state = { id: 'announcement-1', viewCount: 2 }
    expect(getAnnouncementViewCount(state, 'announcement-2')).toBe(0)
    expect(shouldAutoPresentAnnouncement(state, 'announcement-2')).toBe(true)
  })

  it('记录展示次数且不超过上限', () => {
    const once = recordAnnouncementPresentation(null, 'announcement-2')
    const twice = recordAnnouncementPresentation(once, 'announcement-2')
    const capped = recordAnnouncementPresentation(twice, 'announcement-2')

    expect(once).toEqual({ id: 'announcement-2', viewCount: 1 })
    expect(twice).toEqual({ id: 'announcement-2', viewCount: 2 })
    expect(capped).toEqual({ id: 'announcement-2', viewCount: 2 })
  })
})
