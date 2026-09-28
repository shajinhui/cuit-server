import { describe, expect, it } from 'vitest'

import {
  ACTIVE_ANNOUNCEMENT,
  getAnnouncementViewCount,
  recordAnnouncementPresentation,
  shouldAutoPresentAnnouncement,
} from './model'

describe('announcement presentation state', () => {
  it('没有展示记录时需要自动展示', () => {
    expect(shouldAutoPresentAnnouncement(null, 'announcement-2')).toBe(true)
  })

  it('同一公告展示两次后停止自动展示', () => {
    const state = { id: 'announcement-2', viewCount: 1 }
    expect(shouldAutoPresentAnnouncement(state, 'announcement-2')).toBe(true)
    expect(shouldAutoPresentAnnouncement({ ...state, viewCount: 2 }, 'announcement-2')).toBe(false)
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

describe('当前公告内容', () => {
  it('推广位使用 HTTPS 专属链接并补齐按钮文案', () => {
    const { promotion } = ACTIVE_ANNOUNCEMENT
    expect(promotion).toBeDefined()
    if (!promotion) return

    expect(promotion.url.startsWith('https://')).toBe(true)
    expect(promotion.tag.trim().length).toBeGreaterThan(0)
    expect(promotion.headline.trim().length).toBeGreaterThan(0)
    expect(promotion.actionLabel.trim().length).toBeGreaterThan(0)
  })

  it('公告文案不含占位内容', () => {
    expect(ACTIVE_ANNOUNCEMENT.id.trim().length).toBeGreaterThan(0)
    expect(ACTIVE_ANNOUNCEMENT.title.trim().length).toBeGreaterThan(0)
    expect(ACTIVE_ANNOUNCEMENT.description.trim().length).toBeGreaterThan(0)
  })
})
