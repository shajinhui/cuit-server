import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import { glassMaterials } from './glassMaterial'

const read = (name: string) => readFileSync(new URL(name, import.meta.url), 'utf8')

describe('公共玻璃组件契约', () => {
  it.each(Object.entries(glassMaterials))('%s 使用有界材质参数和主题薄膜', (_, material) => {
    expect(material.displacementScale).toBeGreaterThan(0)
    expect(material.displacementScale).toBeLessThanOrEqual(18)
    expect(material.blurAmount).toBeGreaterThan(0)
    expect(material.fallbackBlur).toBeGreaterThan(0)
    expect(material.fill).toMatch(/^var\(--/)
  })

  it('只有材质底座调用库，其他控件共用底座而不复制内部 DOM 修补', () => {
    expect(read('GlassSurface.vue')).toContain("from '@wxperia/liquid-glass-vue'")
    for (const name of ['GlassSegmented.vue', 'GlassPopover.vue', 'GlassToolbar.vue', 'GlassIconButton.vue', 'GlassSelect.vue']) {
      expect(read(name), name).toContain('<GlassSurface')
      expect(read(name), name).not.toContain('@wxperia/liquid-glass-vue')
    }
  })

  it('普通分段控件默认不捕获指针，链接保留原生 RouterLink', () => {
    const source = read('GlassSegmented.vue')
    expect(source).toContain('draggable: false')
    expect(source).toContain('props.draggable && !hasLinks.value')
    expect(source).toContain('dragEnabled && handlePointerDown($event)')
    expect(source).toContain("option.to && !option.disabled ? RouterLink : 'button'")
    expect(source).toContain("hasLinks ? undefined : 'radiogroup'")
    expect(source).toContain("@keydown=\"handleKeydown($event, index)\"")
  })

  it('工具栏保留 form 语义，图标按钮不会意外提交所在表单', () => {
    expect(read('GlassToolbar.vue')).toContain("'div' | 'form' | 'nav'")
    expect(read('GlassToolbar.vue')).toContain(':is="as"')
    expect(read('GlassIconButton.vue')).toContain("!to && !href ? 'button' : undefined")
    expect(read('GlassIconButton.vue')).not.toContain('preventDefault')
  })

  it('下拉选择器仍暴露实际元素，供尺寸计算、外部点击与焦点恢复使用', () => {
    expect(read('GlassPopover.vue')).toContain('defineExpose({ element })')
    expect(read('GlassSelect.vue')).toContain('listRef.value?.scrollHeight')
    expect(read('GlassSelect.vue')).toContain('popoverElement()?.contains')
    expect(read('GlassSelect.vue')).toContain('triggerRef.value?.focus')
    expect(read('AppSelect.vue')).toContain('<GlassSelect')
    expect(read('AppSelect.vue')).not.toContain('addEventListener')
  })

  it('已接入的弹层和工具栏不保留另一套背景滤镜，防止隔断公共材质采样', () => {
    for (const [file, selector] of [
      ['glass-select.css', '.glass-select-popover'],
      ['schedule.css', '.schedule-more-menu'],
      ['calendar.css', '.calendar-toolbar'],
      ['campus-map.css', '.campus-map-zoom'],
      ['ratings.css', '.ratings-bottom-action'],
      ['ratings.css', '.rating-comment-composer'],
      ['marketplace.css', '.marketplace-buy-bar'],
    ]) {
      const css = read(`../../styles/${file}`)
      const start = css.indexOf(`${selector} {`)
      expect(start, selector).toBeGreaterThanOrEqual(0)
      const declarations = css.slice(start, css.indexOf('}', start))
      expect(declarations, selector).not.toMatch(/(?:backdrop-filter|clip-path|isolation)\s*:/)
      expect(declarations, selector).toMatch(/background\s*:\s*transparent/)
    }
  })
})
