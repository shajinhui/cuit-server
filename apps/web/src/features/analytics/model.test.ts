import { describe, expect, it } from 'vitest'

import {
  chartCoordinates,
  chartPoints,
  compactDate,
  percentage,
  platformDeviceDistribution,
  timelineLabel,
} from './model'

describe('analytics model', () => {
  it('calculates safe percentages', () => {
    expect(percentage(5, 20)).toBe(25)
    expect(percentage(1, 0)).toBe(0)
  })

  it('builds chart points across the available width', () => {
    expect(chartPoints([0, 10], 10, 100, 50, 10, 5)).toBe('10.0,45.0 90.0,5.0')
    expect(chartCoordinates([0, 10], 10, 100, 50, 10, 5)).toEqual([
      { x: 10, y: 45, value: 0 },
      { x: 90, y: 5, value: 10 },
    ])
  })

  it('formats compact chart dates', () => {
    expect(compactDate('2026-07-26')).toBe('7/26')
    expect(timelineLabel('2026-07-26T04:00:00Z', 'hour')).toBe('12:00')
    expect(timelineLabel('2026-07-26T04:00:00Z', '6_hours')).toBe('7/26 12:00')
    expect(timelineLabel('2026-07-26T04:05:00Z', '5_minutes')).toBe('12:05')
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
