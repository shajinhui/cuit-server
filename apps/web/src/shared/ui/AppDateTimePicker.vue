<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'

type PickerMode = 'date' | 'time'
type WheelKind = 'hour' | 'minute'

interface CalendarDay {
  value: string
  label: number
  inMonth: boolean
  disabled: boolean
  selected: boolean
  today: boolean
}

const props = withDefaults(
  defineProps<{
    modelValue: string
    mode: PickerMode
    title: string
    min?: string
    max?: string
    step?: number
    disabled?: boolean
  }>(),
  {
    min: '',
    max: '',
    step: 60,
    disabled: false,
  },
)

const emit = defineEmits<{
  'update:modelValue': [value: string]
  change: [value: string]
}>()

const open = ref(false)
const initialValue = ref('')
const pendingValue = ref('')
const visibleMonth = ref(startOfMonth(new Date()))
const triggerRef = ref<HTMLButtonElement | null>(null)
const dialogRef = ref<HTMLElement | null>(null)
const hourWheelRef = ref<HTMLElement | null>(null)
const minuteWheelRef = ref<HTMLElement | null>(null)
const previousBodyOverflow = ref('')
const wheelItemHeight = 48
const weekdayLabels = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
const hourOptions = Array.from({ length: 24 }, (_, index) => index)

const minuteStep = computed(() => {
  const minutes = Math.round(props.step / 60)
  if (!Number.isFinite(minutes)) return 1
  return Math.min(60, Math.max(1, minutes))
})

const minuteOptions = computed(() => {
  const options: number[] = []
  for (let minute = 0; minute < 60; minute += minuteStep.value) options.push(minute)
  return options.length ? options : [0]
})

const displayValue = computed(() => {
  if (props.mode === 'date') {
    const date = parseDate(props.modelValue)
    if (!date) return '请选择日期'
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`
  }
  const time = parseTime(props.modelValue)
  return time ? formatTime(time.hour, time.minute) : '请选择时间'
})

const visibleMonthLabel = computed(
  () => `${visibleMonth.value.getFullYear()}年${visibleMonth.value.getMonth() + 1}月`,
)

const selectedTime = computed(() => parseTime(pendingValue.value) ?? { hour: 0, minute: 0 })

const calendarDays = computed<CalendarDay[]>(() => {
  const year = visibleMonth.value.getFullYear()
  const month = visibleMonth.value.getMonth()
  const firstVisible = new Date(year, month, 1, 12)
  firstVisible.setDate(firstVisible.getDate() - firstVisible.getDay())
  const today = formatDate(new Date())

  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(firstVisible)
    date.setDate(firstVisible.getDate() + index)
    const value = formatDate(date)
    return {
      value,
      label: date.getDate(),
      inMonth: date.getMonth() === month,
      disabled: !dateWithinBounds(value),
      selected: value === pendingValue.value,
      today: value === today,
    }
  })
})

const canGoPreviousMonth = computed(() => monthIntersectsBounds(addMonths(visibleMonth.value, -1)))
const canGoNextMonth = computed(() => monthIntersectsBounds(addMonths(visibleMonth.value, 1)))

async function openPicker() {
  if (props.disabled) return
  const value = normalizedValue(props.modelValue)
  initialValue.value = value
  pendingValue.value = value
  if (props.mode === 'date') {
    visibleMonth.value = startOfMonth(parseDate(value) ?? new Date())
  }
  previousBodyOverflow.value = document.body.style.overflow
  document.body.style.overflow = 'hidden'
  open.value = true
  await nextTick()
  dialogRef.value?.focus({ preventScroll: true })
  if (props.mode === 'time') scrollTimeWheels('auto')
}

async function closePicker(restoreFocus = true) {
  if (!open.value) return
  open.value = false
  document.body.style.overflow = previousBodyOverflow.value
  if (!restoreFocus) return
  await nextTick()
  triggerRef.value?.focus({ preventScroll: true })
}

async function restoreValue() {
  pendingValue.value = initialValue.value
  if (props.mode === 'date') {
    visibleMonth.value = startOfMonth(parseDate(initialValue.value) ?? new Date())
    return
  }
  await nextTick()
  scrollTimeWheels('auto')
}

function confirmValue() {
  const value = normalizedValue(pendingValue.value)
  emit('update:modelValue', value)
  emit('change', value)
  void closePicker()
}

function chooseDate(day: CalendarDay) {
  if (!day.inMonth || day.disabled) return
  pendingValue.value = day.value
}

function changeMonth(offset: number) {
  const next = addMonths(visibleMonth.value, offset)
  if (!monthIntersectsBounds(next)) return
  visibleMonth.value = next
}

function chooseWheelValue(kind: WheelKind, value: number) {
  const current = selectedTime.value
  pendingValue.value =
    kind === 'hour'
      ? formatTime(value, current.minute)
      : formatTime(current.hour, value)
  const options = kind === 'hour' ? hourOptions : minuteOptions.value
  const index = Math.max(0, options.indexOf(value))
  scrollWheel(kind, index, 'auto')
}

function handleWheelScroll(kind: WheelKind, event: Event) {
  const element = event.currentTarget as HTMLElement
  const options = kind === 'hour' ? hourOptions : minuteOptions.value
  const index = Math.min(options.length - 1, Math.max(0, Math.round(element.scrollTop / wheelItemHeight)))
  const value = options[index]
  if (value === undefined) return
  const current = selectedTime.value
  const next = kind === 'hour' ? formatTime(value, current.minute) : formatTime(current.hour, value)
  if (next !== pendingValue.value) pendingValue.value = next
}

function scrollTimeWheels(behavior: ScrollBehavior) {
  const time = selectedTime.value
  scrollWheel('hour', hourOptions.indexOf(time.hour), behavior)
  scrollWheel('minute', minuteOptions.value.indexOf(time.minute), behavior)
}

function scrollWheel(kind: WheelKind, index: number, behavior: ScrollBehavior) {
  const element = kind === 'hour' ? hourWheelRef.value : minuteWheelRef.value
  if (!element) return
  element.scrollTo({ top: Math.max(0, index) * wheelItemHeight, behavior })
}

function handleDialogKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    void closePicker()
    return
  }
  if (event.key !== 'Tab' || !dialogRef.value) return
  const focusable = [
    ...dialogRef.value.querySelectorAll<HTMLElement>(
      'button:not(:disabled), [tabindex]:not([tabindex="-1"])',
    ),
  ]
  if (!focusable.length) return
  const first = focusable[0]
  const last = focusable.at(-1)
  if (!first || !last) return
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}

function normalizedValue(value: string) {
  if (props.mode === 'date') {
    const fallback = formatDate(new Date())
    return clampDate(parseDate(value) ? value : fallback)
  }
  const parsed = parseTime(value) ?? currentTime()
  const minute = closestMinute(parsed.minute, minuteOptions.value)
  return clampTime(formatTime(parsed.hour, minute))
}

function dateWithinBounds(value: string) {
  if (props.min && value < props.min) return false
  if (props.max && value > props.max) return false
  return true
}

function clampDate(value: string) {
  if (props.min && value < props.min) return props.min
  if (props.max && value > props.max) return props.max
  return value
}

function clampTime(value: string) {
  if (props.min && value < props.min) return props.min
  if (props.max && value > props.max) return props.max
  return value
}

function monthIntersectsBounds(month: Date) {
  const first = formatDate(startOfMonth(month))
  const last = formatDate(new Date(month.getFullYear(), month.getMonth() + 1, 0, 12))
  if (props.min && last < props.min) return false
  if (props.max && first > props.max) return false
  return true
}

function currentTime() {
  const now = new Date()
  return { hour: now.getHours(), minute: now.getMinutes() }
}

function closestMinute(value: number, options: readonly number[]) {
  return options.reduce((closest, option) =>
    Math.abs(option - value) < Math.abs(closest - value) ? option : closest,
  )
}

function parseDate(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (!match) return null
  const year = Number(match[1])
  const month = Number(match[2]) - 1
  const day = Number(match[3])
  const date = new Date(year, month, day, 12)
  if (date.getFullYear() !== year || date.getMonth() !== month || date.getDate() !== day) return null
  return date
}

function parseTime(value: string) {
  const match = /^(\d{2}):(\d{2})$/.exec(value)
  if (!match) return null
  const hour = Number(match[1])
  const minute = Number(match[2])
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null
  return { hour, minute }
}

function formatDate(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function formatTime(hour: number, minute: number) {
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`
}

function startOfMonth(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), 1, 12)
}

function addMonths(date: Date, offset: number) {
  return new Date(date.getFullYear(), date.getMonth() + offset, 1, 12)
}

watch(
  () => props.disabled,
  (disabled) => {
    if (disabled) void closePicker(false)
  },
)

onBeforeUnmount(() => {
  if (open.value) document.body.style.overflow = previousBodyOverflow.value
})
</script>

<template>
  <div class="app-date-time-picker">
    <button
      ref="triggerRef"
      type="button"
      class="app-date-time-picker__trigger"
      :aria-label="title"
      aria-haspopup="dialog"
      :aria-expanded="open"
      :disabled="disabled"
      @click="openPicker"
    >
      <span>{{ displayValue }}</span>
      <svg aria-hidden="true" viewBox="0 0 16 16">
        <path d="m4.5 6 3.5 3.5L11.5 6" />
      </svg>
    </button>

    <Teleport to="body">
      <Transition name="app-date-time-picker-dialog" appear>
        <div v-if="open" class="app-date-time-picker__backdrop" @pointerdown.self="closePicker()">
          <section
            ref="dialogRef"
            class="app-date-time-picker__dialog"
            :class="`app-date-time-picker__dialog--${mode}`"
            role="dialog"
            aria-modal="true"
            :aria-label="title"
            tabindex="-1"
            @keydown="handleDialogKeydown"
          >
            <template v-if="mode === 'date'">
              <header class="app-date-time-picker__calendar-header">
                <div class="app-date-time-picker__month-label">
                  <strong>{{ visibleMonthLabel }}</strong>
                  <svg aria-hidden="true" viewBox="0 0 12 18"><path d="m3 2 6 7-6 7" /></svg>
                </div>
                <div class="app-date-time-picker__month-actions">
                  <button
                    type="button"
                    aria-label="上个月"
                    :disabled="!canGoPreviousMonth"
                    @click="changeMonth(-1)"
                  >
                    <svg aria-hidden="true" viewBox="0 0 18 28"><path d="M15 2 4 14l11 12" /></svg>
                  </button>
                  <button
                    type="button"
                    aria-label="下个月"
                    :disabled="!canGoNextMonth"
                    @click="changeMonth(1)"
                  >
                    <svg aria-hidden="true" viewBox="0 0 18 28"><path d="m3 2 11 12L3 26" /></svg>
                  </button>
                </div>
              </header>

              <div class="app-date-time-picker__weekdays" aria-hidden="true">
                <span v-for="weekday in weekdayLabels" :key="weekday">{{ weekday }}</span>
              </div>

              <div class="app-date-time-picker__calendar" role="grid" :aria-label="visibleMonthLabel">
                <button
                  v-for="day in calendarDays"
                  :key="day.value"
                  type="button"
                  role="gridcell"
                  :class="{
                    'is-outside': !day.inMonth,
                    'is-selected': day.selected,
                    'is-today': day.today,
                  }"
                  :aria-label="`${day.value}${day.today ? '，今天' : ''}`"
                  :aria-selected="day.selected"
                  :disabled="day.disabled || !day.inMonth"
                  @click="chooseDate(day)"
                >
                  {{ day.label }}
                </button>
              </div>
            </template>

            <div v-else class="app-date-time-picker__time" aria-label="选择时间">
              <div class="app-date-time-picker__wheel-selection" aria-hidden="true" />
              <div
                ref="hourWheelRef"
                class="app-date-time-picker__wheel"
                role="listbox"
                aria-label="小时"
                @scroll="handleWheelScroll('hour', $event)"
              >
                <button
                  v-for="hour in hourOptions"
                  :key="hour"
                  type="button"
                  role="option"
                  :aria-selected="selectedTime.hour === hour"
                  :class="{ 'is-selected': selectedTime.hour === hour }"
                  @click="chooseWheelValue('hour', hour)"
                >
                  {{ String(hour).padStart(2, '0') }}
                </button>
              </div>
              <span class="app-date-time-picker__time-separator" aria-hidden="true">:</span>
              <div
                ref="minuteWheelRef"
                class="app-date-time-picker__wheel"
                role="listbox"
                aria-label="分钟"
                @scroll="handleWheelScroll('minute', $event)"
              >
                <button
                  v-for="minute in minuteOptions"
                  :key="minute"
                  type="button"
                  role="option"
                  :aria-selected="selectedTime.minute === minute"
                  :class="{ 'is-selected': selectedTime.minute === minute }"
                  @click="chooseWheelValue('minute', minute)"
                >
                  {{ String(minute).padStart(2, '0') }}
                </button>
              </div>
            </div>

            <footer class="app-date-time-picker__footer">
              <button type="button" class="app-date-time-picker__restore" @click="restoreValue">
                还原
              </button>
              <button
                type="button"
                class="app-date-time-picker__confirm"
                aria-label="确认选择"
                @click="confirmValue"
              >
                <svg aria-hidden="true" viewBox="0 0 32 32"><path d="m5 17 7 7L27 7" /></svg>
              </button>
            </footer>
          </section>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
