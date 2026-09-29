<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useRoute, useRouter, type RouteLocationRaw } from 'vue-router'
import { GlassMode, LiquidGlass } from '@wxperia/liquid-glass-vue'

import profileIcon from '@/assets/icons/nav-profile-tab.png'
import ratingsIcon from '@/assets/icons/nav-ratings.svg'
import scheduleIcon from '@/assets/icons/nav-schedule.png'
import toolsIcon from '@/assets/icons/nav-tools.png'
import { isRatingsConfigured } from '@/features/ratings'

defineOptions({ name: 'BottomNavigation' })

const route = useRoute()
const router = useRouter()
const defaultItems = [
  { name: 'schedule', label: '课表', icon: scheduleIcon, to: { name: 'schedule' } },
  { name: 'tools', label: '工具', icon: toolsIcon, to: { name: 'tools' } },
  ...(isRatingsConfigured()
    ? [{ name: 'ratings', label: '评分', icon: ratingsIcon, to: { name: 'ratings' } }]
    : []),
  { name: 'profile', label: '我的', icon: profileIcon, to: { name: 'profile' } },
] as const

interface NavigationItem {
  name: string
  label: string
  icon: string
  iconClass?: string
  to?: RouteLocationRaw
}

const props = withDefaults(
  defineProps<{
    items?: readonly NavigationItem[]
    activeName?: string
    ariaLabel?: string
    inline?: boolean
    compact?: boolean
  }>(),
  {
    ariaLabel: '主导航',
    inline: false,
    compact: false,
  },
)

const emit = defineEmits<{
  select: [name: string]
}>()

const resolvedItems = computed<readonly NavigationItem[]>(() => props.items ?? defaultItems)
const resolvedActiveName = computed(() => props.activeName ?? String(route.name ?? ''))
const activeIndex = computed(() => {
  const index = resolvedItems.value.findIndex((item) => item.name === resolvedActiveName.value)
  return index < 0 ? 0 : index
})

const navigationRef = ref<HTMLElement | null>(null)
const contentRef = ref<HTMLElement | null>(null)
const selectionRef = ref<HTMLElement | null>(null)
const dragPosition = ref<number | null>(null)
const settledPosition = ref<number | null>(null)
const isPressed = ref(false)
const isLifted = ref(false)
const isDragging = ref(false)

let holdTimer: number | undefined
let settleTimer: number | undefined
let pointerId: number | undefined
let pointerStartX = 0
let pointerStartPosition = 0
let itemWidth = 1
let suppressClick = false

const selectionPosition = computed(() =>
  dragPosition.value ?? settledPosition.value ?? activeIndex.value,
)

const selectionStyle = computed(() => ({
  '--selection-position': selectionPosition.value,
  // 按住时以胶囊自身为中心鼓起（对齐 iOS 导航栏的做法）：上下对称地鼓出导航栏，
  // 而不是整体上移——整体上移会让图标和文字偏离胶囊中心，看起来像没对齐。
  // 只留一点点上移保留「弹起」的手感，主体靠放大：上移多了胶囊会整体往上跑，
  // 下边缘鼓不出来，和导航栏就不对称了。
  '--selection-lift': isLifted.value ? '-2px' : '0px',
  // 胶囊比导航栏矮 10px（上下各留 5px），所以放大倍数要更大才能鼓出来。
  '--selection-scale': isLifted.value ? '1.36' : isPressed.value ? '1.02' : '1',
}))

function clearInteractionTimers() {
  if (holdTimer !== undefined) window.clearTimeout(holdTimer)
  if (settleTimer !== undefined) window.clearTimeout(settleTimer)
  holdTimer = undefined
  settleTimer = undefined
}

function resetInteraction() {
  clearInteractionTimers()
  pointerId = undefined
  isPressed.value = false
  isLifted.value = false
  isDragging.value = false
  dragPosition.value = null
}

function getItemWidth() {
  const navigation = navigationRef.value
  if (!navigation) return 1
  const count = Math.max(resolvedItems.value.length, 1)
  return (navigation.clientWidth - 10) / count
}

function selectItem(index: number) {
  const item = resolvedItems.value[index]
  if (!item) return

  if (item.to) {
    void router.push(item.to)
  } else {
    emit('select', item.name)
  }
}

function finishSelectionDrag() {
  if (dragPosition.value === null) {
    resetInteraction()
    return
  }

  if (holdTimer !== undefined) window.clearTimeout(holdTimer)
  holdTimer = undefined

  const lastPosition = dragPosition.value
  const targetIndex = Math.min(
    Math.max(Math.round(lastPosition), 0),
    Math.max(resolvedItems.value.length - 1, 0),
  )
  const wasDragging = isDragging.value

  dragPosition.value = targetIndex
  settledPosition.value = targetIndex
  isPressed.value = false
  isLifted.value = false
  isDragging.value = false
  suppressClick = wasDragging

  if (targetIndex !== activeIndex.value) selectItem(targetIndex)

  pointerId = undefined

  settleTimer = window.setTimeout(() => {
    if (!isDragging.value) {
      settledPosition.value = null
      dragPosition.value = null
    }
  }, 460)
}

function handleSelectionPointerDown(event: PointerEvent) {
  if (event.pointerType === 'mouse' && event.button !== 0) return

  const navigation = navigationRef.value
  if (!navigation) return

  event.preventDefault()
  contentRef.value?.setPointerCapture(event.pointerId)
  pointerId = event.pointerId
  pointerStartX = event.clientX
  pointerStartPosition = activeIndex.value
  itemWidth = getItemWidth()
  dragPosition.value = activeIndex.value
  isPressed.value = true
  isDragging.value = false
  isLifted.value = false

  clearInteractionTimers()
  holdTimer = window.setTimeout(() => {
    if (pointerId === event.pointerId) isLifted.value = true
  }, 160)
}

function handleSelectionPointerMove(event: PointerEvent) {
  if (pointerId !== event.pointerId || dragPosition.value === null) return

  const deltaX = event.clientX - pointerStartX
  if (!isDragging.value && Math.abs(deltaX) < 6) return

  isDragging.value = true
  isLifted.value = true
  const rawPosition = pointerStartPosition + deltaX / itemWidth
  const maxIndex = Math.max(resolvedItems.value.length - 1, 0)
  const clamped = Math.min(Math.max(rawPosition, 0), maxIndex)
  const overshoot = rawPosition - clamped
  const resistance = overshoot === 0 ? 0 : (overshoot * 0.18) / (1 + Math.abs(overshoot) * 0.18)
  dragPosition.value = clamped + resistance
  event.preventDefault()
}

function handleSelectionPointerUp(event: PointerEvent) {
  if (pointerId !== event.pointerId) return
  contentRef.value?.releasePointerCapture(event.pointerId)
  finishSelectionDrag()
}

function handleSelectionPointerCancel(event: PointerEvent) {
  if (pointerId !== event.pointerId) return
  contentRef.value?.releasePointerCapture(event.pointerId)
  resetInteraction()
}

function handleNavigationPointerDown(event: PointerEvent) {
  const selection = selectionRef.value
  if (!selection) return
  const bounds = selection.getBoundingClientRect()
  if (
    event.clientX < bounds.left ||
    event.clientX > bounds.right ||
    event.clientY < bounds.top ||
    event.clientY > bounds.bottom
  ) {
    return
  }
  suppressClick = false
  handleSelectionPointerDown(event)
}

function handleNavigationClick(event: MouseEvent) {
  if (!suppressClick) return
  event.preventDefault()
  event.stopPropagation()
  suppressClick = false
}

watch(activeIndex, (index) => {
  if (isDragging.value) return
  if (settledPosition.value !== null && settledPosition.value !== index) {
    settledPosition.value = null
    dragPosition.value = null
  }
})

onBeforeUnmount(() => {
  clearInteractionTimers()
})
</script>

<template>
  <div
    class="bottom-navigation"
    :class="{
      'bottom-navigation--inline': inline,
      'bottom-navigation--compact': compact,
    }"
    ref="navigationRef"
  >
    <!--
      LiquidGlass 的折射滤镜会把边缘高光渲染到容器之外，iOS 上会明显溢出胶囊、
      横贯整个页面，所以单独用一层 overflow: hidden 的容器把它裁住。
      交互内容必须放在这层之外：选中项拖动时会向上浮出胶囊，放进去会被裁掉。
    -->
    <span class="bottom-navigation__glass" aria-hidden="true">
      <LiquidGlass
        :mode="GlassMode.standard"
        :displacement-scale="64"
        :blur-amount="0.1"
        :saturation="135"
        :aberration-intensity="1.6"
        :elasticity="0.08"
        :corner-radius="32"
        padding="0"
      >
        <span class="bottom-navigation__glass-fill" />
      </LiquidGlass>
    </span>

    <nav
      class="bottom-navigation__content"
      ref="contentRef"
      :style="{ '--navigation-item-count': resolvedItems.length }"
      :aria-label="ariaLabel"
      @pointerdown="handleNavigationPointerDown"
      @pointermove="handleSelectionPointerMove"
      @pointerup="handleSelectionPointerUp"
      @pointercancel="handleSelectionPointerCancel"
      @click.capture="handleNavigationClick"
    >
      <span
        ref="selectionRef"
        class="bottom-navigation__selection"
        :class="{
          'is-pressed': isPressed,
          'is-lifted': isLifted,
          'is-dragging': isDragging,
        }"
        :style="selectionStyle"
        aria-hidden="true"
      />
      <template v-for="item in resolvedItems" :key="item.name">
        <RouterLink
          v-if="item.to"
          :to="item.to"
          class="bottom-navigation__item"
          :class="{ 'is-active': resolvedActiveName === item.name }"
        >
          <span
            class="bottom-navigation__icon"
            :class="`bottom-navigation__icon--${item.iconClass ?? item.name}`"
            :style="{ '--nav-icon': `url(${item.icon})` }"
            aria-hidden="true"
          />
          <span>{{ item.label }}</span>
        </RouterLink>
        <button
          v-else
          type="button"
          class="bottom-navigation__item"
          :class="{ 'is-active': resolvedActiveName === item.name }"
          :aria-current="resolvedActiveName === item.name ? 'page' : undefined"
          @click="emit('select', item.name)"
        >
          <span
            class="bottom-navigation__icon"
            :class="`bottom-navigation__icon--${item.iconClass ?? item.name}`"
            :style="{ '--nav-icon': `url(${item.icon})` }"
            aria-hidden="true"
          />
          <span>{{ item.label }}</span>
        </button>
      </template>
    </nav>
  </div>
</template>
