import { describe, expect, it } from 'vitest'

import { buildAutoRunRecordBody, randomRange } from './run'
import { parseTrackMap } from './track'

describe('校园跑请求体计算', () => {
  const map = parseTrackMap([
    { id: 0, location: '103.000000,30.000000', edge: [1] },
    { id: 1, location: '103.001000,30.000000', edge: [0] },
  ])

  it('在前端生成轨迹、距离和设备字段', () => {
    const body = buildAutoRunRecordBody({
      identity: { userId: 11, schoolId: 33 },
      standard: { semesterYear: '2026-1' },
      bounds: [{ siteBound: '103.9,30.6' }],
      now: new Date('2026-09-07T00:00:00.000Z'),
      random: () => 0.5,
      locations: map,
      runDistance: 100,
      runTime: 32,
    })

    expect(body).toMatchObject({
      appVersions: '1.8.5',
      brand: 'Xiaomi',
      mobileType: 'Mi 11',
      sysVersions: 'Android 11',
      distanceTimeStatus: '1',
      innerSchool: '1',
      runDistance: 100,
      runTime: 32,
      userId: 11,
      yearSemester: '2026-1',
      recordDate: '2026-09-07',
      realityTrackPoints: '103.9,30.6--',
    })
    expect(JSON.parse(body.trackPoints)).toEqual(expect.any(Array))
  })

  it('按中国时区计算记录日期并为空围栏提供兼容值', () => {
    const body = buildAutoRunRecordBody({
      identity: { userId: 11, schoolId: 33 },
      standard: { semesterYear: 2026 },
      bounds: [],
      now: new Date('2026-09-07T16:30:00.000Z'),
      random: () => 0,
      locations: map,
      runDistance: 1,
      runTime: 31,
    })

    expect(body.recordDate).toBe('2026-09-08')
    expect(body.realityTrackPoints).toBe('00.000,00.000--')
    expect(body.yearSemester).toBe('2026')
  })

  it('随机范围包含两端整数', () => {
    expect(randomRange(4_675, 5_174, () => 0)).toBe(4_675)
    expect(randomRange(4_675, 5_174, () => 0.999999)).toBe(5_174)
  })
})
