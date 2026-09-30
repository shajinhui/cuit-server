import { readFileSync } from 'node:fs'
import { effectScope, nextTick, ref, shallowRef, type EffectScope } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useCapsuleGesture as useNavigationGesture } from '@/shared/ui/useCapsuleGesture'

let scope: EffectScope

function setup(active = 0, presented = active, rim = 5) {
  scope = effectScope()
  const captured = new Set<number>()
  const content = {
    hasPointerCapture: (id: number) => captured.has(id),
    setPointerCapture: vi.fn((id: number) => captured.add(id)),
    releasePointerCapture: vi.fn((id: number) => captured.delete(id)),
  }
  const activeIndex = ref(active)
  const select = vi.fn((index: number) => { activeIndex.value = index })
  const itemWidth = (410 - rim * 2) / 4
  const gesture = scope.run(() => useNavigationGesture({
    activeIndex,
    itemCount: () => 4,
    navigation: shallowRef({ clientWidth: 410, getBoundingClientRect: () => ({ left: 0, width: 410 }) } as HTMLElement),
    selection: shallowRef({ getBoundingClientRect: () => ({ left: rim + presented * itemWidth, right: rim + (presented + 1) * itemWidth, top: 5, bottom: 59, width: itemWidth }) } as HTMLElement),
    content: shallowRef(content as unknown as HTMLElement),
    select,
    rim,
  }))
  if (!gesture) throw new Error('gesture scope did not start')
  return { gesture, content, select, activeIndex }
}

function pointer(index = 0, x = 55, overrides: Partial<PointerEvent> = {}) {
  return {
    isPrimary: true, pointerId: 1, pointerType: 'touch', button: 0,
    clientX: x, clientY: 30,
    target: { closest: () => ({ dataset: { navigationIndex: String(index) } }) },
    preventDefault: vi.fn(), stopPropagation: vi.fn(), ...overrides,
  } as unknown as PointerEvent
}

function click(detail = 1, pointerId?: number) {
  return {
    detail, ...(pointerId === undefined ? {} : { pointerId }),
    preventDefault: vi.fn(), stopPropagation: vi.fn(),
  } as unknown as MouseEvent
}

function drag(gesture: ReturnType<typeof useNavigationGesture>) {
  gesture.handlePointerDown(pointer())
  gesture.handlePointerMove(pointer(0, 155))
  gesture.handlePointerUp(pointer(0, 155))
}

describe('导航点按与胶囊拖动互不抢占', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('window', new EventTarget())
    vi.stubGlobal('document', Object.assign(new EventTarget(), { visibilityState: 'visible' }))
  })
  afterEach(() => {
    scope?.stop()
    vi.unstubAllGlobals()
    vi.useRealTimers()
  })

  it('普通按下即时反馈，但不阻止链接默认事件或捕获到容器', () => {
    const { gesture, content, select } = setup()
    const down = pointer()
    gesture.handlePointerDown(down)
    expect(gesture.isPressed.value).toBe(true)
    expect(down.preventDefault).not.toHaveBeenCalled()
    expect(content.setPointerCapture).not.toHaveBeenCalled()
    gesture.handlePointerUp(pointer())
    expect(gesture.isPressed.value).toBe(false)
    expect(select).not.toHaveBeenCalled()
    const tap = click()
    gesture.handleClick(tap)
    expect(tap.preventDefault).not.toHaveBeenCalled()
  })

  it('关闭链接的原生 HTML 拖拽，否则浏览器会 cancel 自定义胶囊手势', () => {
    const component = readFileSync(new URL('./BottomNavigation.vue', import.meta.url), 'utf8')
    expect(component).toMatch(/<nav\s[\s\S]*?@dragstart\.prevent[\s\S]*?>/)
  })

  it('长按仍放大，微小抖动不误判为拖动', () => {
    const { gesture, content } = setup()
    gesture.handlePointerDown(pointer())
    vi.advanceTimersByTime(160)
    expect(gesture.isLifted.value).toBe(true)
    gesture.handlePointerMove(pointer(0, 59))
    expect(gesture.isDragging.value).toBe(false)
    expect(content.setPointerCapture).not.toHaveBeenCalled()
    gesture.handlePointerUp(pointer())
    expect(gesture.isLifted.value).toBe(false)
  })

  it('小型分段控件的 3px 内边距不会使胶囊吸附坐标偏移', () => {
    const { gesture, select } = setup(0, 0, 3)
    gesture.handlePointerDown(pointer())
    gesture.handlePointerMove(pointer(0, 156))
    expect(gesture.position.value).toBeCloseTo(1)
    gesture.handlePointerUp(pointer(0, 156))
    expect(select).toHaveBeenCalledExactlyOnceWith(1)
  })

  it('确认拖动后捕获、跟随，并且只提交一次目标', async () => {
    const { gesture, content, select } = setup()
    drag(gesture)
    expect(content.setPointerCapture).toHaveBeenCalledExactlyOnceWith(1)
    expect(content.releasePointerCapture).toHaveBeenCalledExactlyOnceWith(1)
    expect(select).toHaveBeenCalledExactlyOnceWith(1)
    gesture.handlePointerCancel(pointer()) // 已正常释放后产生的 lostpointercapture
    await nextTick()
    expect(gesture.position.value).toBe(1)
    const syntheticClick = click(1, 1)
    gesture.handleClick(syntheticClick)
    expect(syntheticClick.preventDefault).toHaveBeenCalledOnce()
    expect(select).toHaveBeenCalledTimes(1)
  })

  it('拖动后没有合成 click，下一次非选中项点按仍立即生效', async () => {
    const { gesture } = setup()
    drag(gesture)
    await nextTick()
    vi.advanceTimersByTime(500)
    const nextDown = pointer(3, 355)
    gesture.handlePointerDown(nextDown)
    const nextClick = click(1, 1)
    gesture.handleClick(nextClick)
    expect(nextDown.preventDefault).not.toHaveBeenCalled()
    expect(nextClick.preventDefault).not.toHaveBeenCalled()
  })

  it('胶囊动画途经未选中按钮，不劫持该按钮的点按', () => {
    const { gesture, content, select } = setup(3, 0)
    const down = pointer(0)
    gesture.handlePointerDown(down)
    expect(content.setPointerCapture).not.toHaveBeenCalled()
    expect(down.preventDefault).not.toHaveBeenCalled()
    gesture.handlePointerUp(pointer(0))
    const tap = click()
    gesture.handleClick(tap)
    expect(tap.preventDefault).not.toHaveBeenCalled()
    expect(select).not.toHaveBeenCalled()
  })

  it('可以从动画途经的位置接住胶囊并继续拖动，不要求按在逻辑终点', () => {
    const { gesture, select } = setup(3, 0.2)
    gesture.handlePointerDown(pointer(0, 55))
    expect(gesture.position.value).toBeCloseTo(0.2)
    gesture.handlePointerMove(pointer(0, 255))
    expect(gesture.position.value).toBeCloseTo(2.2)
    gesture.handlePointerUp(pointer(0, 255))
    expect(select).toHaveBeenCalledExactlyOnceWith(2)
  })

  it('接住移动中的胶囊时从屏幕上的当前位置继续', () => {
    const { gesture } = setup(3, 2.4)
    gesture.handlePointerDown(pointer(3, 355))
    expect(gesture.position.value).toBeCloseTo(2.4)
    gesture.handlePointerMove(pointer(3, 305))
    expect(gesture.position.value).toBeCloseTo(1.9)
  })

  it('触摸拖动不能吞掉键盘激活或另一个指针的点击', () => {
    const { gesture } = setup()
    drag(gesture)
    const keyboard = click(0)
    const otherPointer = click(1, 2)
    gesture.handleClick(keyboard)
    gesture.handleClick(otherPointer)
    expect(keyboard.preventDefault).not.toHaveBeenCalled()
    expect(otherPointer.preventDefault).not.toHaveBeenCalled()
  })

  it('取消/丢失捕获时清理状态，不再提交或继续放大', () => {
    const { gesture, content, select } = setup()
    gesture.handlePointerDown(pointer())
    gesture.handlePointerMove(pointer(0, 100))
    gesture.handlePointerCancel(pointer())
    vi.runAllTimers()
    gesture.handlePointerUp(pointer(0, 100))
    expect(gesture.isLifted.value).toBe(false)
    expect(gesture.isDragging.value).toBe(false)
    expect(gesture.position.value).toBe(0)
    expect(content.releasePointerCapture).toHaveBeenCalledOnce()
    expect(select).not.toHaveBeenCalled()
  })

  it('触屏从链接转交捕获到 nav 的冒泡 lost 事件不能取消拖动', () => {
    const { gesture, content } = setup()
    gesture.handlePointerDown(pointer())
    gesture.handlePointerMove(pointer(0, 155))
    gesture.handleLostPointerCapture(pointer())
    expect(gesture.isDragging.value).toBe(true)
    gesture.handleLostPointerCapture(pointer(0, 155, { target: content as unknown as EventTarget }))
    expect(gesture.isDragging.value).toBe(false)
  })

  it('鼠标离开尚未确认拖动的导航时取消按压', () => {
    const { gesture } = setup()
    gesture.handlePointerDown(pointer())
    gesture.handlePointerLeave(pointer())
    vi.runAllTimers()
    expect(gesture.isLifted.value).toBe(false)
    expect(gesture.isPressed.value).toBe(false)
  })

  it('切后台或窗口失焦会释放手势，不会留下拦截状态', () => {
    const { gesture, content } = setup()
    gesture.handlePointerDown(pointer())
    gesture.handlePointerMove(pointer(0, 155))
    window.dispatchEvent(new Event('blur'))
    expect(gesture.isDragging.value).toBe(false)
    expect(content.releasePointerCapture).toHaveBeenCalledOnce()
    gesture.handlePointerDown(pointer())
    Object.assign(document, { visibilityState: 'hidden' })
    document.dispatchEvent(new Event('visibilitychange'))
    vi.runAllTimers()
    expect(gesture.isLifted.value).toBe(false)
  })

  it('忽略第二根手指和修改键，不破坏原生链接操作', () => {
    const { gesture } = setup()
    gesture.handlePointerDown(pointer(0, 55, { isPrimary: false }))
    gesture.handlePointerDown(pointer(0, 55, { metaKey: true }))
    expect(gesture.isPressed.value).toBe(false)
  })
})
