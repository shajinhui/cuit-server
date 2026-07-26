import { describe, expect, it } from 'vitest'

import { chartPoints, compactDate, percentage } from './model'

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
})
