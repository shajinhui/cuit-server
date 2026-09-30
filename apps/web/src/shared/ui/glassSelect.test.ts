import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { selectPopoverPosition, semesterLabel, semesterSelectOptions, type SelectOption } from './glassSelect'

const viewport = { left: 0, top: 0, width: 390, height: 844 }
const read = (name: string) => readFileSync(new URL(name, import.meta.url), 'utf8')

describe('选择器弹层定位', () => {
  it('正常情况下在入口下方展开，并保留手机两侧边距', () => {
    expect(selectPopoverPosition({ left: 22, top: 90, bottom: 134, width: 346 }, viewport, 144))
      .toEqual({ left: 22, top: 141, width: 300, maxHeight: 360, origin: 'top' })
  })

  it('靠近底部时向上展开，不挡住底部导航', () => {
    expect(selectPopoverPosition({ left: 250, top: 740, bottom: 784, width: 100 }, viewport, 188))
      .toEqual({ left: 188, top: 545, width: 190, maxHeight: 360, origin: 'bottom' })
  })

  it('超窄屏仍不溢出，长列表在弹层内滚动', () => {
    const placement = selectPopoverPosition({ left: 100, top: 60, bottom: 104, width: 400 }, { ...viewport, width: 180, height: 280 }, 2000)
    expect(placement.left).toBe(12)
    expect(placement.width).toBe(156)
    expect(placement.top).toBe(111)
    expect(placement.maxHeight).toBe(157)
  })

  it('软键盘和缩放后的可视视口包含偏移，不按整屏高度放置', () => {
    const visible = { left: 35, top: 120, width: 280, height: 300 }
    const placement = selectPopoverPosition({ left: 290, top: 335, bottom: 379, width: 150 }, visible, 200)
    expect(placement).toEqual({ left: 113, top: 132, width: 190, maxHeight: 196, origin: 'bottom' })
    expect(placement.top + placement.maxHeight).toBeLessThanOrEqual(visible.top + visible.height - 12)
  })

  it('入口超出视口时夹紧坐标，避免负高度或溢出', () => {
    const placement = selectPopoverPosition({ left: -10, top: -50, bottom: -6, width: 44 }, viewport, 90)
    expect(placement.top).toBe(12)
    expect(placement.left).toBe(12)
    expect(placement.maxHeight).toBeGreaterThan(0)
  })
})

describe('学期与选择器公共契约', () => {
  const semesters = [{ ID: '2026-1', SchoolYear: '2026-2027', Term: '1', Current: true }]
  it('学期选择入口统一文案，并保持后端 ID 和选项顺序', () => {
    expect(semesterLabel(semesters[0]!)).toBe('2026-2027 · 第1学期')
    expect(semesterSelectOptions(semesters)).toEqual([{ value: '2026-1', label: '2026-2027 · 第1学期' }])
    expect(semesterSelectOptions([])).toEqual([])
  })

  it('数字值和字符串值可以区分，零也不是占位符', () => {
    const options: SelectOption[] = [{ value: 0, label: '不提醒' }, { value: '0', label: '字符串编号' }]
    expect(options.find(option => Object.is(option.value, 0))?.label).toBe('不提醒')
    expect(options.find(option => Object.is(option.value, '0'))?.label).toBe('字符串编号')
    expect(read('GlassSelect.vue')).toContain("emit('update:modelValue', option.value)")
    expect(read('GlassSelect.vue')).not.toContain('String(option.value)')
  })

  it('课表嵌入选择器复用菜单材质，其他入口直接使用公共玻璃底座', () => {
    const component = read('GlassSelect.vue')
    expect(component).toContain('v-if="variant !== \'menu\'"')
    expect(component).toContain(":is=\"embedded ? 'div' : GlassPopover\"")
    expect(component).toContain(':disabled="embedded"')
    for (const page of ['GradesPage', 'ExamsPage', 'ClassroomsPage', 'SchedulePage']) {
      const source = read(`../../pages/${page}.vue`)
      expect(source, page).toContain('<SemesterSelect')
      expect(source, page).not.toContain('semesterOptions')
      expect(source, page).not.toContain('semesterListOpen')
    }
  })

  it('迁移完实际选择入口，不留下页面自定义材质覆盖', () => {
    for (const page of ['LibraryPage', 'MarketplaceEditorPage']) {
      expect(read(`../../pages/${page}.vue`), page).not.toMatch(/<select\b/)
    }
    for (const name of ['grades', 'exams', 'classrooms', 'schedule', 'admin-stats']) {
      expect(read(`../../styles/${name}.css`), name).not.toContain('app-select__')
      expect(read(`../../styles/${name}.css`), name).not.toContain('glass-select__trigger')
    }
    expect(read('../../styles/main.css')).toContain("@import './glass-select.css'")
  })

  it('关闭、焦点、禁用和退后台行为由公共控件处理', () => {
    const source = read('GlassSelect.vue')
    expect(source).toContain("triggerRef.value?.matches(':disabled')")
    expect(source).toContain("event.key === 'Tab'")
    expect(source).toContain("event.key === 'Escape'")
    expect(source).toContain('event.stopPropagation()')
    expect(source).toContain('onDeactivated')
    expect(source).toContain('removeOpenListeners()')
    expect(source).toContain("document.visibilityState === 'hidden'")
  })
})
