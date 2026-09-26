import { describe, expect, it } from 'vitest'

import {
  autoRunProgressPercent,
  buildAutoRunProgressCards,
  createAutoRunWeekDates,
  normalizeAutoRunClubActivities,
  normalizeAutoRunClubSignTask,
  resolveAutoRunClubSignAction,
} from './model'

describe('校园跑数据展示', () => {
  it('优先展示有效次数和有效距离，并把米转换为公里', () => {
    const cards = buildAutoRunProgressCards({
      runInfo: {
        runCount: 8,
        runValidCount: 6,
        runDistance: 18_000,
        runValidDistance: 12_500,
      },
      runStandard: {
        allRunTime: 20,
        allRunDistance: 60_000,
      },
    })

    expect(cards[0]).toMatchObject({ current: 6, target: 20, unit: '次' })
    expect(cards[1]).toMatchObject({ current: 12.5, target: 60, unit: 'km' })
    expect(autoRunProgressPercent(12.5, 60)).toBe(21)
  })

  it('缺少目标字段时使用稳定的默认目标', () => {
    const cards = buildAutoRunProgressCards({ runInfo: {}, runStandard: {} })

    expect(cards.map(({ current, target }) => ({ current, target }))).toEqual([
      { current: 0, target: 20 },
      { current: 0, target: 60 },
    ])
  })
})

describe('俱乐部数据展示', () => {
  it('根据上游状态转换报名和满员状态', () => {
    const activities = normalizeAutoRunClubActivities([
      {
        clubActivityId: 12,
        activityName: '夜跑训练',
        signInStudent: 20,
        maxStudent: 20,
        cancelSign: '1',
        startTime: '18:30',
        endTime: '20:00',
        addressDetail: '东操场',
        optionStatus: '1',
      },
    ])

    expect(activities[0]).toMatchObject({
      activityId: 12,
      title: '夜跑训练',
      address: '东操场',
      isJoined: true,
      isFull: true,
      isUnavailable: false,
    })
  })

  it('不会把用户报名后的限制状态误报为活动满员', () => {
    const activities = normalizeAutoRunClubActivities([
      {
        clubActivityId: 13,
        activityName: '体能锻炼',
        signInStudent: 198,
        maxStudent: 10_000,
        cancelSign: '0',
        startTime: '18:00',
        endTime: '18:30',
        optionStatus: '3',
        fullActivity: '1',
      },
    ])

    expect(activities[0]).toMatchObject({
      isJoined: false,
      isFull: false,
      isUnavailable: true,
    })
  })

  it('只在上游状态允许时提供签到或签退操作', () => {
    const signInTask = normalizeAutoRunClubSignTask({
      activityId: 8,
      activityName: '晨跑',
      signStatus: '1',
      signInStatus: '0',
      signBackStatus: '0',
    })
    const waitingSignBackTask = normalizeAutoRunClubSignTask({
      activityId: 8,
      signStatus: '1',
      signInStatus: '1',
      signBackStatus: '0',
    })

    expect(resolveAutoRunClubSignAction(signInTask)).toMatchObject({
      signType: '1',
      disabled: false,
    })
    expect(resolveAutoRunClubSignAction(waitingSignBackTask)).toMatchObject({
      signType: '2',
      disabled: true,
    })
  })

  it('按本地日期生成连续七天', () => {
    const dates = createAutoRunWeekDates(new Date(2026, 8, 7, 12))

    expect(dates.map((item) => item.full)).toEqual([
      '2026-09-07',
      '2026-09-08',
      '2026-09-09',
      '2026-09-10',
      '2026-09-11',
      '2026-09-12',
      '2026-09-13',
    ])
  })
})
