import { describe, expect, it } from 'vitest'

import {
  businessDate,
  buildClubScheduleEvents,
  clubProbeKey,
  dueClubProbes,
  inClubProbeWindow,
  normalizeBusinessDate,
  parseClubEventTime,
  resolveClubSignType,
} from './club'
import type { AutoRunClubActivity, AutoRunClubSignTask } from './api'

describe('校园跑俱乐部时间和定时计算', () => {
  const activity: AutoRunClubActivity = {
    clubActivityId: 123,
    activityName: 'track',
    signInStudent: 0,
    maxStudent: 20,
    cancelSign: '0',
    startTime: '19:00',
    endTime: '20:00',
    optionStatus: '1',
  }

  it('按 Asia/Shanghai 解析活动时间和业务日期', () => {
    const parsed = parseClubEventTime('2026-05-13', '19:00')
    expect(parsed?.toISOString()).toBe('2026-05-13T11:00:00.000Z')
    expect(businessDate(new Date('2026-05-13T16:30:00.000Z'))).toBe('2026-05-14')
    expect(normalizeBusinessDate(undefined, new Date('2026-05-13T16:30:00.000Z'))).toBe('2026-05-14')
    expect(inClubProbeWindow(new Date('2026-05-13T10:51:00.000Z'), parsed ?? new Date(0))).toBe(true)
  })

  it('只为未完成的活动边界生成试探任务', () => {
    const now = new Date('2026-05-13T10:51:00.000Z')
    expect(dueClubProbes(now, '2026-05-13', [activity], {})).toEqual([
      { activityId: 123, signType: '1', key: clubProbeKey('2026-05-13', 123, '1') },
    ])
    expect(
      dueClubProbes(now, '2026-05-13', [activity], {
        lastSignInKey: clubProbeKey('2026-05-13', 123, '1'),
      }),
    ).toEqual([])
  })

  it('仅为已报名活动建立签到和签退时间窗口', () => {
    const events = buildClubScheduleEvents('2026-05-13', 22, [
      activity,
      { ...activity, clubActivityId: 124, optionStatus: '0' },
    ])
    expect(events.map(({ activityId, signType, actionKey }) => ({ activityId, signType, actionKey }))).toEqual([
      { activityId: 123, signType: '1', actionKey: '2026-05-13:123:1' },
      { activityId: 123, signType: '2', actionKey: '2026-05-13:123:2' },
    ])
  })

  it('根据签到任务状态选择下一步动作', () => {
    const task: AutoRunClubSignTask = {
      activityId: 8,
      signStatus: '1',
      signInStatus: '0',
      signBackStatus: '0',
    }
    expect(resolveClubSignType(task)).toBe('1')
    expect(
      resolveClubSignType({ ...task, signStatus: '2', signInStatus: '1' }),
    ).toBe('2')
    expect(resolveClubSignType(null)).toBe('')
  })
})
