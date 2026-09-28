/**
 * 玻璃分段开关的几何换算。
 *
 * 单独成模块的原因有两个：`<script setup>` 里不能写导出语句；这两个函数决定
 * 手感且最容易在改动中被破坏，需要直接单测。
 */

/**
 * 指针位置换算成"第几段"。
 *
 * 落在某一段的中心附近即吸附到该段（而不是"越过边界才切换"），越界夹到首尾。
 * @param ratio 指针在轨道内的相对位置（0~1）
 * @param count 段数
 */
export function snapIndex(ratio: number, count: number) {
  if (count <= 1) return 0
  const raw = ratio * count - 0.5
  return Math.min(count - 1, Math.max(0, Math.round(raw)))
}

/**
 * 拖动中的滑块偏移（百分比，100% 表示一段的宽度）。
 *
 * 滑块中心跟随指针，但两端各留半个滑块的行程，使"拖到最左/最右"与
 * "第一段/最后一段被选中"落在同一位置，避免差半个滑块的手感。
 */
export function thumbOffset(ratio: number, count: number) {
  const travel = count - 1
  if (travel <= 0) return 0

  const thumbShare = 1 / count
  const min = thumbShare / 2
  const max = 1 - thumbShare / 2
  const clamped = Math.min(max, Math.max(min, ratio))
  return ((clamped - min) / (max - min)) * travel * 100
}

/** 由指针事件换算出轨道内的相对位置；轨道宽度为 0 时返回 null。 */
export function ratioFromPointer(clientX: number, track: HTMLElement) {
  const rect = track.getBoundingClientRect()
  if (rect.width <= 0) return null
  return (clientX - rect.left) / rect.width
}
