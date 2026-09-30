<script setup lang="ts" generic="T extends SelectValue = SelectValue">
import { computed, nextTick, onBeforeUnmount, onDeactivated, ref, useId, watch, type CSSProperties } from 'vue'

import GlassPopover from './GlassPopover.vue'
import GlassSurface from './GlassSurface.vue'
import { selectPopoverPosition, type GlassSelectProps, type SelectOption, type SelectValue } from './glassSelect'

const props = withDefaults(defineProps<GlassSelectProps<T>>(), {
  ariaLabel: '', disabled: false, placeholder: '请选择', variant: 'field', size: 'md', embedded: false,
})

const emit = defineEmits<{
  'update:modelValue': [value: T]
  change: [value: T]
}>()

const open = ref(false)
const triggerRef = ref<HTMLButtonElement | null>(null)
const listRef = ref<HTMLElement | null>(null)
const popoverRef = ref<HTMLElement | InstanceType<typeof GlassPopover> | null>(null)
const listID = `${useId()}-list`
const valueID = `${useId()}-value`
const popoverStyle = ref<CSSProperties>({})
const cornerRadius = computed(() => props.variant === 'inline' ? 22 : props.size === 'lg' ? 18 : 14)
const selectStyle = computed(() => ({ '--glass-select-radius': `${cornerRadius.value}px` }))
const unavailable = computed(() => props.disabled || props.options.every(option => option.disabled))
let searchText = ''
let searchTime = 0

function popoverElement() {
  const popover = popoverRef.value
  return popover instanceof HTMLElement ? popover : popover?.element
}

const selectedOption = computed(() =>
  props.options.find((option) => Object.is(option.value, props.modelValue)),
)

async function openList(fromEnd = false) {
  if (unavailable.value || triggerRef.value?.matches(':disabled')) return
  if (open.value) {
    await closeList()
    return
  }

  searchText = ''
  open.value = true
  await nextTick()
  if (!open.value || !triggerRef.value || !listRef.value) return
  updatePosition()
  addOpenListeners()
  const selected = listRef.value?.querySelector<HTMLElement>('.is-selected:not(:disabled)')
  const items = [...(listRef.value?.querySelectorAll<HTMLElement>('button:not(:disabled)') ?? [])]
  const initial = selected || (fromEnd ? items.at(-1) : items[0])
  initial?.focus({ preventScroll: true })
  initial?.scrollIntoView({ block: 'nearest' })
}

async function closeList(restoreFocus = true) {
  if (!open.value) return
  open.value = false
  removeOpenListeners()
  searchText = ''
  if (!restoreFocus) return
  await nextTick()
  triggerRef.value?.focus({ preventScroll: true })
}

function updatePosition() {
  const trigger = triggerRef.value
  if (!trigger || props.embedded) return
  const viewport = window.visualViewport
  const placement = selectPopoverPosition(trigger.getBoundingClientRect(), {
    left: viewport?.offsetLeft ?? 0, top: viewport?.offsetTop ?? 0,
    width: viewport?.width ?? document.documentElement.clientWidth,
    height: viewport?.height ?? window.innerHeight,
  }, (listRef.value?.scrollHeight ?? props.options.length * 44) + 12)
  popoverStyle.value = {
    top: `${placement.top}px`, left: `${placement.left}px`, width: `${placement.width}px`,
    maxHeight: `${placement.maxHeight}px`, transformOrigin: `${placement.origin} center`,
  }
}

function handleOutsidePointer(event: PointerEvent) {
  const target = event.target as Node
  if (triggerRef.value?.contains(target) || popoverElement()?.contains(target)) return
  void closeList(false)
}

function handleViewportChange(event: Event) {
  if (event.target instanceof Node && popoverElement()?.contains(event.target)) return
  updatePosition()
}

function addOpenListeners() {
  document.addEventListener('pointerdown', handleOutsidePointer)
  window.addEventListener('resize', updatePosition)
  window.addEventListener('scroll', handleViewportChange, true)
  window.addEventListener('blur', handleWindowBlur)
  document.addEventListener('visibilitychange', handleVisibilityChange)
  window.visualViewport?.addEventListener('resize', updatePosition)
  window.visualViewport?.addEventListener('scroll', updatePosition)
}

function removeOpenListeners() {
  document.removeEventListener('pointerdown', handleOutsidePointer)
  window.removeEventListener('resize', updatePosition)
  window.removeEventListener('scroll', handleViewportChange, true)
  window.removeEventListener('blur', handleWindowBlur)
  document.removeEventListener('visibilitychange', handleVisibilityChange)
  window.visualViewport?.removeEventListener('resize', updatePosition)
  window.visualViewport?.removeEventListener('scroll', updatePosition)
}

function handleWindowBlur() { void closeList(false) }
function handleVisibilityChange() {
  if (document.visibilityState === 'hidden') void closeList(false)
}

function choose(option: SelectOption<T>) {
  if (unavailable.value || option.disabled || triggerRef.value?.matches(':disabled')) return
  emit('update:modelValue', option.value)
  emit('change', option.value)
  void closeList()
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    event.stopPropagation()
    void closeList()
    return
  }
  if (event.key === 'Tab') {
    // Let native Tab traversal continue from the trigger, not from a body portal.
    triggerRef.value?.focus({ preventScroll: true })
    void closeList(false)
    return
  }
  const items = [...(listRef.value?.querySelectorAll<HTMLButtonElement>('button:not(:disabled)') || [])]
  if (!items.length) return
  const index = items.findIndex(item => item === document.activeElement)
  let target: HTMLButtonElement | undefined
  if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
    const offset = event.key === 'ArrowUp' ? -1 : 1
    target = event.key === 'Home' ? items[0] : event.key === 'End' ? items.at(-1)
      : items[index < 0 ? (offset < 0 ? items.length - 1 : 0) : (index + offset + items.length) % items.length]
  } else if (event.key.length === 1 && event.key !== ' ' && !event.metaKey && !event.ctrlKey && !event.altKey) {
    const now = Date.now()
    searchText = now - searchTime > 700 ? event.key : searchText + event.key
    searchTime = now
    target = items.find(item => item.textContent?.trim().toLocaleLowerCase().startsWith(searchText.toLocaleLowerCase()))
  }
  if (target) {
    event.preventDefault()
    target.focus({ preventScroll: true })
    target.scrollIntoView({ block: 'nearest' })
  }
}

watch([() => props.disabled, () => props.options, () => props.modelValue], async () => {
  if (!open.value) return
  if (unavailable.value) { await closeList(false); return }
  await nextTick()
  if (!open.value) return
  updatePosition()
  const selected = listRef.value?.querySelector<HTMLElement>('.is-selected:not(:disabled)')
  const first = listRef.value?.querySelector<HTMLElement>('button:not(:disabled)')
  ;(selected || first)?.focus({ preventScroll: true })
}, { deep: true })

onDeactivated(() => void closeList(false))
onBeforeUnmount(removeOpenListeners)
defineExpose({ close: closeList, focus: () => triggerRef.value?.focus({ preventScroll: true }) })
</script>

<template>
  <div class="glass-select" :class="[`glass-select--${variant}`, `glass-select--${size}`, { 'is-open': open }]" :style="selectStyle">
    <button
      ref="triggerRef"
      type="button"
      class="glass-select__trigger"
      aria-haspopup="listbox"
      :aria-label="ariaLabel || title"
      :aria-describedby="valueID"
      :aria-expanded="open"
      :aria-controls="open ? listID : undefined"
      :disabled="unavailable"
      @click="openList()"
      @keydown.down.prevent="openList()"
      @keydown.up.prevent="openList(true)"
    >
      <GlassSurface v-if="variant !== 'menu'" preset="navigation" :corner-radius="cornerRadius" />
      <span class="glass-select__text">
        <span v-if="variant === 'menu'" class="glass-select__label">{{ title }}</span>
        <span :id="valueID" class="glass-select__value">{{ selectedOption?.label || placeholder }}</span>
      </span>
      <svg class="glass-select__chevron" aria-hidden="true" viewBox="0 0 12 12">
        <path d="m3 4.5 3 3 3-3" />
      </svg>
    </button>

    <Teleport to="body" :disabled="embedded">
      <Transition name="glass-select-popover">
        <component
          :is="embedded ? 'div' : GlassPopover"
          v-if="open"
          :corner-radius="embedded ? undefined : 18"
          :id="listID"
          ref="popoverRef"
          class="glass-select-popover"
          :class="{ 'glass-select-popover--embedded': embedded }"
          role="listbox"
          :aria-label="ariaLabel || title"
          :style="embedded ? undefined : popoverStyle"
          @keydown="handleKeydown"
        >
          <div ref="listRef" class="glass-select__options">
            <button
              v-for="option in options"
              :key="`${typeof option.value}-${option.value}`"
              type="button"
              role="option"
              tabindex="-1"
              :aria-selected="Object.is(option.value, modelValue)"
              :class="{ 'is-selected': Object.is(option.value, modelValue) }"
              :disabled="option.disabled"
              @click="choose(option)"
            >
              <span>{{ option.label }}</span>
              <svg
                v-if="Object.is(option.value, modelValue)"
                aria-hidden="true"
                viewBox="0 0 18 18"
              >
                <path d="m3.5 9.5 3.3 3.2 7.7-8" />
              </svg>
            </button>
          </div>
        </component>
      </Transition>
    </Teleport>
  </div>
</template>
