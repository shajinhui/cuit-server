import { describe, expect, it } from 'vitest'

import { chartPoints, compactDate, percentage, platformDeviceDistribution } from './model'

describe('analytics model', () => {
  it('calculates safe percentages', () => {
    expect(percentage(5, 20)).toBe(25)
    expect(percentage(1, 0)).toBe(0)
  })

  it('builds chart points across the available width', () => {
    expect(chartPoints([0, 10], 10, 100, 50, 10, 5)).toBe('10.0,45.0 90.0,5.0')
  })

  it('formats compact chart dates', () => {
    expect(compactDate('2026-07-26')).toBe('7/26')
  })

  it('fills both platforms in the all-user device distribution', () => {
    const distribution = platformDeviceDistribution({
      tracked_users: 3,
      untracked_users: 2,
      platforms: [
        { name: 'ios', count: 2 },
        { name: 'android', count: 1 },
      ],
      brands: [],
    })

    expect(distribution[0]).toMatchObject({ platform: 'ios', label: 'iOS', count: 2 })
    expect(distribution[0]?.share).toBeCloseTo(66.7, 1)
    expect(distribution[1]).toMatchObject({ platform: 'android', label: 'Android', count: 1 })
    expect(distribution[1]?.share).toBeCloseTo(33.3, 1)
  })
})
