<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, useId, watch, type CSSProperties } from 'vue'

type SelectValue = string | number

interface SelectOption {
  value: SelectValue
  label: string
  disabled?: boolean
}

const props = withDefaults(
  defineProps<{
    modelValue: SelectValue
    options: readonly SelectOption[]
    title: string
    ariaLabel?: string
    disabled?: boolean
    placeholder?: string
  }>(),
  {
    ariaLabel: '',
    disabled: false,
    placeholder: '请选择',
  },
)

const emit = defineEmits<{
  'update:modelValue': [value: SelectValue]
  change: [value: SelectValue]
}>()

const open = ref(false)
const triggerRef = ref<HTMLButtonElement | null>(null)
const listRef = ref<HTMLElement | null>(null)
const popoverRef = ref<HTMLElement | null>(null)
const listID = `${useId()}-list`
const popoverStyle = ref<CSSProperties>({})
const listStyle = ref<CSSProperties>({})

const selectedOption = computed(() =>
  props.options.find((option) => Object.is(option.value, props.modelValue)),
)

async function openList() {
  if (props.disabled || props.options.length === 0) return
  if (open.value) {
    await closeList()
    return
  }

  updatePosition()
  open.value = true
  await nextTick()
  updatePosition()
  addOpenListeners()
  const selected = listRef.value?.querySelector<HTMLElement>('.is-selected:not(:disabled)')
  const first = listRef.value?.querySelector<HTMLElement>('button:not(:disabled)')
  ;(selected || first)?.focus({ preventScroll: true })
}

async function closeList(restoreFocus = true) {
  if (!open.value) return
  open.value = false
  removeOpenListeners()
  if (!restoreFocus) return
  await nextTick()
  triggerRef.value?.focus({ preventScroll: true })
}

function updatePosition() {
  const trigger = triggerRef.value
  if (!trigger) return

  const viewportPadding = 12
  const gap = 7
  const viewportWidth = document.documentElement.clientWidth
  const viewportHeight = window.innerHeight
  const triggerRect = trigger.getBoundingClientRect()
  const width = Math.min(Math.max(triggerRect.width, 190), 300, viewportWidth - viewportPadding * 2)
  const left = Math.min(
    Math.max(triggerRect.left, viewportPadding),
    viewportWidth - width - viewportPadding,
  )
  const availableBelow = viewportHeight - triggerRect.bottom - gap - viewportPadding
  const availableAbove = triggerRect.top - gap - viewportPadding
  const maxHeight = Math.max(108, Math.min(360, Math.max(availableBelow, availableAbove)))
  const measuredHeight = Math.min(popoverRef.value?.offsetHeight || maxHeight, maxHeight)
  const placeBelow = availableBelow >= measuredHeight || availableBelow >= availableAbove
  const top = placeBelow
    ? triggerRect.bottom + gap
    : Math.max(viewportPadding, triggerRect.top - measuredHeight - gap)

  popoverStyle.value = {
    top: `${Math.round(top)}px`,
    left: `${Math.round(left)}px`,
    width: `${Math.round(width)}px`,
  }
  listStyle.value = { maxHeight: `${Math.round(maxHeight - 10)}px` }
}

function handleOutsidePointer(event: PointerEvent) {
  const target = event.target as Node
  if (triggerRef.value?.contains(target) || popoverRef.value?.contains(target)) return
  void closeList(false)
}

function handleViewportChange(event: Event) {
  if (popoverRef.value?.contains(event.target as Node)) return
  updatePosition()
}

function addOpenListeners() {
  document.addEventListener('pointerdown', handleOutsidePointer)
  window.addEventListener('resize', updatePosition)
  window.addEventListener('scroll', handleViewportChange, true)
}

function removeOpenListeners() {
  document.removeEventListener('pointerdown', handleOutsidePointer)
  window.removeEventListener('resize', updatePosition)
  window.removeEventListener('scroll', handleViewportChange, true)
}

function choose(option: SelectOption) {
  if (option.disabled) return
  emit('update:modelValue', option.value)
  emit('change', option.value)
  void closeList()
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    void closeList()
    return
  }
  if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return

  const items = [...(listRef.value?.querySelectorAll<HTMLButtonElement>('button:not(:disabled)') || [])]
  if (items.length === 0) return
  event.preventDefault()
  const activeIndex = items.findIndex((item) => item === document.activeElement)
  const offset = event.key === 'ArrowDown' ? 1 : -1
  const nextIndex = activeIndex < 0 ? 0 : (activeIndex + offset + items.length) % items.length
  items[nextIndex]?.focus({ preventScroll: true })
}

watch(
  () => props.disabled,
  (disabled) => {
    if (disabled) void closeList(false)
  },
)

onBeforeUnmount(() => {
  removeOpenListeners()
})
</script>

<template>
  <div class="app-select">
    <button
      ref="triggerRef"
      type="button"
      class="app-select__trigger"
      aria-haspopup="listbox"
      :aria-label="ariaLabel || title"
      :aria-expanded="open"
      :aria-controls="listID"
      :disabled="disabled || options.length === 0"
      @click="openList"
      @keydown.down.prevent="openList"
      @keydown.up.prevent="openList"
    >
      <span class="app-select__value">{{ selectedOption?.label || placeholder }}</span>
      <svg class="app-select__chevron" aria-hidden="true" viewBox="0 0 12 12">
        <path d="m3 4.5 3 3 3-3" />
      </svg>
    </button>

    <Teleport to="body">
      <Transition name="app-select-popover" appear>
        <div
          v-if="open"
          :id="listID"
          ref="popoverRef"
          class="app-select-popover"
          role="listbox"
          :aria-label="ariaLabel || title"
          :style="popoverStyle"
          @keydown="handleKeydown"
        >
          <div ref="listRef" class="app-select-popover__list" :style="listStyle">
            <button
              v-for="option in options"
              :key="`${typeof option.value}-${option.value}`"
              type="button"
              role="option"
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
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
