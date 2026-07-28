import { describe, expect, it } from 'vitest'

import { isClassroomLocalCacheFresh } from './cache'

describe('classroom local cache lifetime', () => {
  const now = new Date('2026-07-28T12:00:00+08:00').getTime()
  const day = 24 * 60 * 60 * 1000

  it('accepts snapshots younger than 24 hours', () => {
    expect(isClassroomLocalCacheFresh(now - day + 1, now)).toBe(true)
  })

  it('expires snapshots at 24 hours', () => {
    expect(isClassroomLocalCacheFresh(now - day, now)).toBe(false)
  })

  it('rejects snapshots with a future timestamp', () => {
    expect(isClassroomLocalCacheFresh(now + 1, now)).toBe(false)
  })
})
