import { describe, expect, it, vi } from 'vitest'

import { formatRatingTime, ratingCountLabel, ratingPercentage, scoreLabel } from './model'

describe('ratings presentation model', () => {
  it('distinguishes an unrated item from a zero score', () => {
    expect(scoreLabel(null)).toBe('暂无评分')
    expect(scoreLabel(8)).toBe('8.0')
    expect(ratingCountLabel(0)).toBe('等待第一份评分')
    expect(ratingCountLabel(12)).toBe('12 人评分')
  })

  it('calculates distribution percentages without dividing by zero', () => {
    expect(ratingPercentage(0, 0)).toBe(0)
    expect(ratingPercentage(2, 3)).toBe(67)
  })

  it('formats recent rating activity for the local user', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-09-21T12:00:00+08:00'))

    expect(formatRatingTime('2026-09-21T11:59:45+08:00')).toBe('刚刚')
    expect(formatRatingTime('2026-09-21T11:40:00+08:00')).toBe('20 分钟前')
    expect(formatRatingTime('2026-09-21T09:00:00+08:00')).toBe('3 小时前')

    vi.useRealTimers()
  })
})
