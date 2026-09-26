import { describe, expect, it } from 'vitest'

import { calculateDistance, generateTrack, loadTrackMap, parseTrackMap } from './track'

describe('校园跑轨迹计算', () => {
  const map = parseTrackMap([
    { id: 0, location: '103.000000,30.000000', edge: [1] },
    { id: 1, location: '103.001000,30.000000', edge: [0] },
  ])

  it('加载并校验内置校园轨迹地图', () => {
    const locations = loadTrackMap()
    expect(locations.length).toBeGreaterThan(300)
    expect(locations[0]).toMatchObject({ id: 0, edge: [1] })
  })

  it('生成格式正确且时间单调递增的轨迹点', () => {
    let counter = 0
    const random = (): number => {
      counter += 1
      return (counter % 10) / 10
    }
    const now = new Date('2026-05-13T10:00:00.000Z')
    const points = JSON.parse(generateTrack(100, map, random, now)) as unknown

    expect(Array.isArray(points)).toBe(true)
    if (!Array.isArray(points)) return
    expect(points.length).toBeGreaterThan(2)
    const timestamps = points.map((point) => {
      expect(typeof point).toBe('string')
      const pieces = String(point).split('-')
      return Number(pieces.at(-2))
    })
    for (let index = 1; index < timestamps.length; index += 1) {
      expect(timestamps[index] ?? 0).toBeGreaterThanOrEqual(timestamps[index - 1] ?? 0)
    }
    expect(String(points.at(-1))).toMatch(/103\.00[01]000-30\.000000-\d+-\d+\.\d$/)
  })

  it('计算 Haversine 距离并拒绝格式错误的地图', () => {
    expect(calculateDistance([103, 30], [103.001, 30])).toBeGreaterThan(0)
    expect(() => parseTrackMap([{ id: 0, location: 'bad', edge: [] }])).toThrow()
    expect(() => parseTrackMap([{ id: 0, location: '103,30', edge: [2] }])).toThrow()
    expect(() => generateTrack(0, map, () => 0.5)).toThrow('跑步距离无效')
  })
})
