<script setup lang="ts">
import { computed, ref } from 'vue'

import { GlassMode, LiquidGlass } from '@wxperia/liquid-glass-vue'

import { ratioFromPointer, snapIndex, thumbOffset } from './glassSegmented'

/**
 * 玻璃分段开关。
 *
 * 交互：点选任意一段，或者按住滑块（拇指）左右拖动，松手吸附到最近的一段。
 *
 * 实现要点：
 *  1. LiquidGlass 只当底板，且 --glass-fill / --glass-rim 都刻意压到很低的
 *     不透明度，避免在设置行里"抢戏"；
 *  2. 拖动逻辑挂在一层独立的透明覆盖层（.glass-segmented__track）上，不用去动
 *     玻璃组件内部的指针事件；松手后再开启过渡，让滑块吸附回弹；
 *  3. 拖到位与点选都走同一套 select()，越界位置会被夹到 [0, count - 1]。
 */

defineOptions({ name: 'GlassSegmented' })

const props = defineProps<{
  /** 每一项的取值，v-model 用 */
  options: { value: string; label: string; shortLabel?: string }[]
  modelValue: string
  /** 无障碍名称 */
  ariaLabel?: string
  /** 底板的圆角与单个滑块圆角 */
  cornerRadius?: number
  thumbRadius?: number
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  change: [value: string]
}>()

const activeIndex = computed(() => {
  const index = props.options.findIndex((option) => option.value === props.modelValue)
  return index < 0 ? 0 : index
})

const count = computed(() => props.options.length)
const cornerRadius = computed(() => props.cornerRadius ?? 12)
const thumbRadius = computed(() => props.thumbRadius ?? 9)

/** 拖动中的滑块偏移，单位是"整条轨道的百分比"；null 表示跟随选中项。 */
const dragOffset = ref<number | null>(null)

const switchStyle = computed(() => ({
  '--glass-segmented-count': count.value,
  '--glass-segmented-index': activeIndex.value,
  '--glass-segmented-offset':
    dragOffset.value === null ? 'calc(var(--glass-segmented-index) * 100%)' : `${dragOffset.value}%`,
  '--glass-segmented-corner': `${cornerRadius.value}px`,
  '--glass-segmented-thumb-corner': `${thumbRadius.value}px`,
}))

function select(index: number) {
  const next = props.options[Math.min(count.value - 1, Math.max(0, index))]
  if (!next || next.value === props.modelValue) return

  emit('update:modelValue', next.value)
  emit('change', next.value)
}

let dragging = false
let dragStartX = 0
let movedDuringDrag = false

function handlePointerDown(event: PointerEvent) {
  if (event.button !== 0 && event.pointerType === 'mouse') return

  // 阻止按住时的文字选中与图片拖拽：拖动只应该移动滑块。
  event.preventDefault()
  dragging = true
  movedDuringDrag = false
  dragStartX = event.clientX
  dragOffset.value = activeIndex.value * 100
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function handlePointerMove(event: PointerEvent) {
  if (!dragging) return

  const ratio = ratioFromPointer(event.clientX, event.currentTarget as HTMLElement)
  if (ratio === null) return

  if (Math.abs(event.clientX - dragStartX) > 3) movedDuringDrag = true
  dragOffset.value = thumbOffset(ratio, count.value)
}

function handlePointerUp(event: PointerEvent) {
  if (!dragging) return

  dragging = false
  const ratio = ratioFromPointer(event.clientX, event.currentTarget as HTMLElement)
  const target = ratio === null ? activeIndex.value : snapIndex(ratio, count.value)
  // 先清掉拖动偏移，让滑块回到"选中项坐标"；这样松手后的位移始终是吸附动画。
  dragOffset.value = null
  if (movedDuringDrag || target !== activeIndex.value) select(target)
}

function handlePointerCancel() {
  dragging = false
  dragOffset.value = null
}

function handleKeydown(event: KeyboardEvent, index: number) {
  const keys = ['ArrowLeft', 'ArrowRight', 'Home', 'End']
  if (!keys.includes(event.key)) return

  event.preventDefault()
  if (event.key === 'Home') return select(0)
  if (event.key === 'End') return select(count.value - 1)
  select(index + (event.key === 'ArrowRight' ? 1 : -1))
}
</script>

<template>
  <div
    class="glass-segmented"
    :class="{ 'is-dragging': dragOffset !== null }"
    :style="switchStyle"
  >
    <span class="glass-segmented__glass" aria-hidden="true">
      <!-- LiquidGlass 的根元素自带 relative 布局，位置交给外层容器控制 -->
      <LiquidGlass
        :mode="GlassMode.standard"
        :displacement-scale="36"
        :blur-amount="0.06"
        :saturation="112"
        :aberration-intensity="0.8"
        :elasticity="0.05"
        :corner-radius="cornerRadius"
        padding="0"
      >
        <span class="glass-segmented__glass-fill" />
      </LiquidGlass>
    </span>

    <span class="glass-segmented__thumb" aria-hidden="true" />

    <div
      class="glass-segmented__track"
      role="radiogroup"
      :aria-label="ariaLabel"
      @pointerdown="handlePointerDown"
      @pointermove="handlePointerMove"
      @pointerup="handlePointerUp"
      @pointercancel="handlePointerCancel"
    >
      <button
        v-for="(option, index) in options"
        :key="option.value"
        type="button"
        class="glass-segmented__option"
        :class="{ 'is-selected': index === activeIndex }"
        role="radio"
        :aria-label="option.label"
        :aria-checked="index === activeIndex"
        :tabindex="index === activeIndex ? 0 : -1"
        @click="select(index)"
        @keydown="handleKeydown($event, index)"
      >
        {{ option.shortLabel ?? option.label }}
      </button>
    </div>
  </div>
</template>
