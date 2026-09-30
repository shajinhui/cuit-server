import { computed, onScopeDispose, ref, watch, type Ref } from 'vue'

interface NavigationGestureOptions {
  activeIndex: Readonly<Ref<number>>
  itemCount: () => number
  navigation: Ref<HTMLElement | null>
  content: Ref<HTMLElement | null>
  selection: Ref<HTMLElement | null>
  select: (index: number) => void
}

/** 点击仍交给原始链接；只有确认拖动后才把指针捕获到导航容器。 */
export function useNavigationGesture(options: NavigationGestureOptions) {
  const dragPosition = ref<number | null>(null)
  const settledPosition = ref<number | null>(null)
  const isPressed = ref(false)
  const isLifted = ref(false)
  const isDragging = ref(false)
  const position = computed(() => dragPosition.value ?? settledPosition.value ?? options.activeIndex.value)

  let holdTimer: ReturnType<typeof setTimeout> | undefined
  let settleTimer: ReturnType<typeof setTimeout> | undefined
  let pointerId: number | undefined
  let suppressedPointerId: number | undefined
  let startX = 0
  let startPosition = 0
  let itemWidth = 1

  function clearTimers() {
    clearTimeout(holdTimer)
    clearTimeout(settleTimer)
    holdTimer = undefined
    settleTimer = undefined
  }

  function releasePointer(id: number | undefined) {
    if (id !== undefined && options.content.value?.hasPointerCapture(id)) {
      options.content.value.releasePointerCapture(id)
    }
  }

  function reset() {
    const id = pointerId
    pointerId = undefined
    suppressedPointerId = undefined
    clearTimers()
    isPressed.value = false
    isLifted.value = false
    isDragging.value = false
    dragPosition.value = null
    settledPosition.value = null
    releasePointer(id)
  }

  function handlePointerDown(event: PointerEvent) {
    if (!event.isPrimary || (event.pointerType === 'mouse' && event.button !== 0)) return
    if (pointerId !== undefined) return
    // WebKit 不一定会在拖动后生成 click。新一轮按下必须清掉上一轮的屏蔽，
    // 包括按在非选中项上的情况，否则正常切页会被吞掉。
    suppressedPointerId = undefined
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return

    const target = event.target as Element | null
    const item = target?.closest<HTMLElement>('[data-navigation-index]')
    if (!item) return
    const navigation = options.navigation.value
    const selection = options.selection.value
    if (!navigation || !selection) return
    const selectedBounds = selection.getBoundingClientRect()
    const onCapsule = event.clientX >= selectedBounds.left && event.clientX <= selectedBounds.right
      && event.clientY >= selectedBounds.top && event.clientY <= selectedBounds.bottom
    // 移动中的胶囊仍可被接住；普通点按的目标始终是原始链接，不以胶囊覆盖范围决定。
    if (Number(item.dataset.navigationIndex) !== options.activeIndex.value && !onCapsule) return

    clearTimers()
    const bounds = navigation.getBoundingClientRect()
    const scale = bounds.width / navigation.clientWidth
    itemWidth = (bounds.width - 10 * scale) / Math.max(options.itemCount(), 1)
    // 接住尚在移动的胶囊，而不是跳到动画的逻辑终点。
    startPosition = (selectedBounds.left + selectedBounds.width / 2 - bounds.left - 5 * scale) / itemWidth - 0.5
    startX = event.clientX
    pointerId = event.pointerId
    dragPosition.value = startPosition
    settledPosition.value = null
    isPressed.value = true
    isLifted.value = false
    isDragging.value = false
    // 不 preventDefault、不捕获普通按下：原始 RouterLink/button 仍能收到 click。
    holdTimer = setTimeout(() => {
      if (pointerId === event.pointerId) isLifted.value = true
    }, 160)
  }

  function handlePointerMove(event: PointerEvent) {
    if (pointerId !== event.pointerId || dragPosition.value === null) return
    const delta = event.clientX - startX
    if (!isDragging.value && Math.abs(delta) < 6) return
    if (!isDragging.value) options.content.value?.setPointerCapture(event.pointerId)
    isDragging.value = true
    isLifted.value = true
    const raw = startPosition + delta / itemWidth
    const max = Math.max(options.itemCount() - 1, 0)
    const clamped = Math.min(Math.max(raw, 0), max)
    const overshoot = raw - clamped
    dragPosition.value = clamped + (overshoot * 0.18) / (1 + Math.abs(overshoot) * 0.18)
    event.preventDefault()
  }

  function handlePointerUp(event: PointerEvent) {
    if (pointerId !== event.pointerId) return
    const dragged = isDragging.value
    const target = Math.min(Math.max(Math.round(position.value), 0), Math.max(options.itemCount() - 1, 0))
    clearTimers()
    // 先结束手势，再释放捕获；lostpointercapture 不应取消已经提交的选择。
    pointerId = undefined
    isPressed.value = false
    isLifted.value = false
    isDragging.value = false
    if (dragged) {
      suppressedPointerId = event.pointerId
      dragPosition.value = target
      settledPosition.value = target
      if (target !== options.activeIndex.value) options.select(target)
      settleTimer = setTimeout(() => {
        dragPosition.value = null
        settledPosition.value = null
      }, 460)
    } else {
      dragPosition.value = null
      settledPosition.value = null
    }
    releasePointer(event.pointerId)
  }

  function handlePointerCancel(event: PointerEvent) {
    if (pointerId === event.pointerId) reset()
  }

  function handleLostPointerCapture(event: PointerEvent) {
    // 触屏按下时链接会隐式捕获；把捕获转给 nav 时，旧链接的 lost 事件会冒泡。
    // 那只是正常交接，不是 nav 丢失手势。
    if (event.target === options.content.value) handlePointerCancel(event)
  }

  function handlePointerLeave(event: PointerEvent) {
    if (!isDragging.value && pointerId === event.pointerId) reset()
  }

  function handleClick(event: MouseEvent) {
    // detail=0 是键盘/辅助技术激活，不能被触摸手势屏蔽。
    if (suppressedPointerId === undefined || event.detail === 0) return
    if ('pointerId' in event && event.pointerId !== suppressedPointerId) return
    suppressedPointerId = undefined
    event.preventDefault()
    event.stopPropagation()
  }

  function handleVisibilityChange() {
    if (document.visibilityState === 'hidden') reset()
  }

  watch(options.activeIndex, (index) => {
    if (pointerId !== undefined) reset()
    if (settledPosition.value !== null && settledPosition.value !== index) {
      clearTimers()
      settledPosition.value = null
      dragPosition.value = null
    }
  })
  window.addEventListener('blur', reset)
  document.addEventListener('visibilitychange', handleVisibilityChange)
  onScopeDispose(() => {
    reset()
    window.removeEventListener('blur', reset)
    document.removeEventListener('visibilitychange', handleVisibilityChange)
  })

  return {
    position, isPressed, isLifted, isDragging,
    handlePointerDown, handlePointerMove, handlePointerUp,
    handlePointerCancel, handleLostPointerCapture, handlePointerLeave, handleClick,
  }
}
