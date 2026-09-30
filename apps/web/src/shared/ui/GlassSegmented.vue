<script setup lang="ts" generic="T extends string = string">
import { computed, nextTick, ref } from 'vue'
import { RouterLink, type RouteLocationRaw } from 'vue-router'

import GlassSurface from './GlassSurface.vue'
import type { GlassMaterial } from './glassMaterial'
import { useCapsuleGesture } from './useCapsuleGesture'

const props = withDefaults(defineProps<{
  options: readonly { value: T; label: string; shortLabel?: string; disabled?: boolean; to?: RouteLocationRaw }[]
  modelValue: T
  ariaLabel?: string
  cornerRadius?: number
  thumbRadius?: number
  material?: GlassMaterial
  /** Ordinary switches keep native clicks; opt in only for a draggable capsule. */
  draggable?: boolean
}>(), { cornerRadius: 12, thumbRadius: 9, material: 'control', draggable: false })

const emit = defineEmits<{
  'update:modelValue': [value: T]
  change: [value: T]
}>()

const containerRef = ref<HTMLElement | null>(null)
const trackRef = ref<HTMLElement | null>(null)
const thumbRef = ref<HTMLElement | null>(null)
const activeIndex = computed(() => Math.max(0, props.options.findIndex(option => option.value === props.modelValue)))
const hasLinks = computed(() => props.options.some(option => option.to))
const dragEnabled = computed(() => props.draggable && !hasLinks.value)
const {
  position, isDragging, handlePointerDown, handlePointerMove, handlePointerUp,
  handlePointerCancel, handleLostPointerCapture, handlePointerLeave, handleClick,
} = useCapsuleGesture({
  activeIndex,
  itemCount: () => props.options.length,
  navigation: containerRef,
  content: trackRef,
  selection: thumbRef,
  rim: 3,
  select,
})

const switchStyle = computed(() => ({
  '--glass-segmented-count': Math.max(1, props.options.length),
  '--glass-segmented-offset': `${position.value * 100}%`,
  '--glass-segmented-corner': `${props.cornerRadius}px`,
  '--glass-segmented-thumb-corner': `${props.thumbRadius}px`,
}))

function select(index: number) {
  const option = props.options[index]
  if (!option || option.disabled || option.to || option.value === props.modelValue) return
  emit('update:modelValue', option.value)
  emit('change', option.value)
}

async function handleKeydown(event: KeyboardEvent, index: number) {
  if (hasLinks.value || !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()
  const enabled = props.options.map((option, i) => option.disabled ? -1 : i).filter(i => i >= 0)
  if (!enabled.length) return
  const current = enabled.indexOf(index)
  const delta = event.key === 'ArrowLeft' ? -1 : 1
  const target = event.key === 'Home' ? enabled[0] : event.key === 'End' ? enabled.at(-1)!
    : enabled[(current + delta + enabled.length) % enabled.length]!
  select(target)
  await nextTick()
  trackRef.value?.querySelector<HTMLElement>(`[data-navigation-index="${target}"]`)?.focus()
}
</script>

<template>
  <div ref="containerRef" class="glass-segmented" :class="{ 'is-dragging': isDragging, 'is-draggable': dragEnabled }" :style="switchStyle">
    <GlassSurface :preset="material" :corner-radius="cornerRadius" />
    <span ref="thumbRef" class="glass-segmented__thumb" aria-hidden="true" />
    <component
      :is="hasLinks ? 'nav' : 'div'"
      ref="trackRef"
      class="glass-segmented__track"
      :role="hasLinks ? undefined : 'radiogroup'"
      :aria-label="ariaLabel"
      @pointerdown="dragEnabled && handlePointerDown($event)"
      @pointermove="dragEnabled && handlePointerMove($event)"
      @pointerup="dragEnabled && handlePointerUp($event)"
      @pointercancel="handlePointerCancel"
      @lostpointercapture="handleLostPointerCapture"
      @pointerleave="handlePointerLeave"
      @click.capture="handleClick"
    >
      <component
        :is="option.to && !option.disabled ? RouterLink : 'button'"
        v-for="(option, index) in options"
        :key="option.value"
        :to="option.to && !option.disabled ? option.to : undefined"
        :type="option.to && !option.disabled ? undefined : 'button'"
        class="glass-segmented__option"
        :class="{ 'is-selected': index === activeIndex }"
        :data-navigation-index="index"
        :role="hasLinks ? undefined : 'radio'"
        :aria-label="option.label"
        :aria-checked="hasLinks ? undefined : index === activeIndex"
        :aria-current="hasLinks && index === activeIndex ? 'page' : undefined"
        :tabindex="hasLinks || index === activeIndex ? 0 : -1"
        :disabled="option.disabled || undefined"
        @click="select(index)"
        @keydown="handleKeydown($event, index)"
      >{{ option.shortLabel ?? option.label }}</component>
    </component>
  </div>
</template>
