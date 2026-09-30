import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8')

describe('校园顶部轻量导航', () => {
  it('评分与二手保留原生路由切换，共用一层导航玻璃材质', () => {
    const component = read('./CampusHeader.vue')
    expect(component).toContain('material="navigation"')
    expect(component.match(/<GlassSegmented\b/g)).toHaveLength(1)
    expect(component).toContain("to: { name: 'ratings' }")
    expect(component).toContain("to: { name: 'marketplace' }")
    expect(component).toContain('aria-label="校园栏目"')
    expect(component).not.toContain('draggable')
  })

  it('缩小可见玻璃，不缩小点击区域，选中态使用主题中性色', () => {
    const css = read('../../styles/marketplace.css')
    expect(css).toContain('grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr)')
    expect(css).toMatch(/\.campus-tabs\.glass-segmented\s*\{[^}]*height: 44px/)
    expect(css).toMatch(/\.campus-tabs > \.glass-surface\s*\{\s*inset: 4px 0/)
    expect(css).toMatch(/\.campus-tabs \.glass-segmented__track\s*\{\s*padding-block: 0/)
    expect(css).toMatch(/\.campus-tabs \.glass-segmented__option\.is-selected\s*\{\s*color: var\(--text-primary\)/)
    expect(css).toMatch(/\.campus-tabs \.glass-segmented__thumb\s*\{[^}]*background: var\(--control-track-soft\)/)
  })

  it('材质为可选参数，不影响其他分段控件的默认外观', () => {
    const component = read('../../shared/ui/GlassSegmented.vue')
    expect(component).toContain('material?: GlassMaterial')
    expect(component).toContain("material: 'control'")
    expect(component).toContain('<GlassSurface :preset="material"')
  })
})
