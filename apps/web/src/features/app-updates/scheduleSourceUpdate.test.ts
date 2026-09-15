import { describe, expect, it } from 'vitest'

import {
  SCHEDULE_SOURCE_UPDATE_ID,
  shouldPromptScheduleSourceUpdate,
} from './scheduleSourceUpdate'

describe('schedule source update prompt', () => {
  it('新提示尚未展示时需要弹出', () => {
    expect(shouldPromptScheduleSourceUpdate(null)).toBe(true)
    expect(shouldPromptScheduleSourceUpdate('older-update')).toBe(true)
  })

  it('同一提示已经展示后不再重复弹出', () => {
    expect(shouldPromptScheduleSourceUpdate(SCHEDULE_SOURCE_UPDATE_ID)).toBe(false)
  })
})
