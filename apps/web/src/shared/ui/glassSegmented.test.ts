import { describe, expect, it } from 'vitest'

import { snapIndex, thumbOffset } from './glassSegmented'

/**
 * 玻璃分段开关的拖动换算。
 *
 * 这两条规则决定手感，最容易在改动中被破坏：
 *  - 指针落在某一段的中心附近就吸附到那一段（而不是"越过边界才切换"）；
 *  - 拖到两端时滑块恰好停在第一段/最后一段的选中位置，不会差半个滑块。
 */
describe('玻璃分段开关的拖动换算', () => {
  const COUNT = 3

  describe('snapIndex', () => {
    it('指针落在各段中心时吸附到对应段', () => {
      for (let index = 0; index < COUNT; index += 1) {
        expect(snapIndex((index + 0.5) / COUNT, COUNT)).toBe(index)
      }
    })

    it('跨过段边界才切换，边界附近归属更近的一段', () => {
      // 第 1、2 段的分界在 2/3：略偏左仍属第 1 段，略偏右属第 2 段
      expect(snapIndex(2 / 3 - 0.02, COUNT)).toBe(1)
      expect(snapIndex(2 / 3 + 0.02, COUNT)).toBe(2)
    })

    it('越界位置夹到首尾段', () => {
      expect(snapIndex(-0.4, COUNT)).toBe(0)
      expect(snapIndex(1.6, COUNT)).toBe(COUNT - 1)
    })

    it('只有一段时恒为 0', () => {
      expect(snapIndex(0, 1)).toBe(0)
      expect(snapIndex(1, 1)).toBe(0)
    })
  })

  describe('thumbOffset', () => {
    it('第一段偏移为 0，最后一段为 (段数-1) 个整段宽', () => {
      expect(thumbOffset(1 / 6, COUNT)).toBe(0)
      expect(thumbOffset(5 / 6, COUNT)).toBe(200)
    })

    it('中间段落在整段位置', () => {
      expect(thumbOffset(0.5, COUNT)).toBe(100)
    })

    it('越界后仍停在可视行程端点', () => {
      expect(thumbOffset(-1, COUNT)).toBe(0)
      expect(thumbOffset(2, COUNT)).toBe(200)
    })

    it('偏移始终落在 [0, (段数-1)*100] 区间内', () => {
      for (const ratio of [0, 0.2, 1 / 3, 0.5, 2 / 3, 0.8, 1]) {
        const index = snapIndex(ratio, COUNT)
        const offset = thumbOffset(ratio, COUNT)
        expect(offset).toBeGreaterThanOrEqual(0)
        expect(offset).toBeLessThanOrEqual((COUNT - 1) * 100)
        expect(index).toBeGreaterThanOrEqual(0)
        expect(index).toBeLessThanOrEqual(COUNT - 1)
      }
    })

    it('只有一段时不产生位移', () => {
      expect(thumbOffset(0.5, 1)).toBe(0)
    })
  })
})
