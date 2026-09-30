import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const stylesheet = [
  readFileSync(new URL('../../styles/main.css', import.meta.url), 'utf8'),
  readFileSync(new URL('../../styles/glass-material.css', import.meta.url), 'utf8'),
].join('\n').replace(/\/\*[\s\S]*?\*\//g, '')
const rules = [...stylesheet.matchAll(/([^{}]+)\{([^{}]*)\}/g)]
const component = readFileSync(new URL('./BottomNavigation.vue', import.meta.url), 'utf8')

function declarationsFor(selector: string) {
  return rules
    .filter(match => match[1].split(',').some(part => part.trim() === selector))
    .map(match => match[2]).join('\n')
}

describe('共用玻璃材质的背景采样边界', () => {
  it('布局和按压祖先不隔断页面背景，只裁剪真正的滤镜面', () => {
    for (const selector of [
      '.bottom-navigation__glass', '.bottom-navigation__content',
      '.bottom-navigation__selection', '.bottom-navigation__selection.is-lifted',
      '.glass-surface', '.glass-surface > .relative',
      '.glass-popover', '.glass-toolbar', '.glass-icon-button',
    ]) {
      const declarations = declarationsFor(selector)
      expect(declarations, selector).not.toMatch(/(?:^|[;\n])\s*(?:-webkit-)?(?:clip-path|filter|mask(?:-image)?)\s*:/)
      expect(declarations, selector).not.toMatch(/contain\s*:\s*paint|isolation\s*:\s*isolate/)
    }
    expect(declarationsFor('.glass-surface .glass__warp')).toMatch(/clip-path\s*:/)
  })

  it('全部库图层使用百分比布局尺寸，避免缩放后高光重复放大', () => {
    expect(declarationsFor('.glass-surface > *')).toMatch(/width\s*:\s*100%\s*!important/)
    expect(declarationsFor('.glass-surface > *')).toMatch(/height\s*:\s*100%\s*!important/)
    expect(declarationsFor('.glass-surface .glass')).toMatch(/min-height\s*:\s*100%/)
  })

  it('主题薄膜位于滤镜之后，不给滤镜父层叠加不透明底板', () => {
    expect(declarationsFor('.glass-surface .glass')).toMatch(/background\s*:\s*transparent/)
    expect(declarationsFor('.glass-surface__fill')).toMatch(/background\s*:\s*var\(--glass-fill\)/)
    expect(declarationsFor('.glass-surface')).toMatch(/pointer-events\s*:\s*none/)
  })

  it('保留库边缘高光，统一处理混合模式和 WebKit 降级', () => {
    expect(declarationsFor('.glass-surface > span')).toMatch(/mix-blend-mode\s*:\s*normal\s*!important/)
    expect(stylesheet).toContain('@supports (background: -webkit-named-image(i))')
    expect(declarationsFor('.glass-surface .glass__warp')).toMatch(/-webkit-backdrop-filter\s*:/)
    expect(stylesheet).toContain('prefers-reduced-transparency: reduce')
    expect(stylesheet).toContain('prefers-contrast: more')
  })

  it('导航的栏和胶囊共用底座，布局圆角仍由原导航负责', () => {
    expect(component).toContain('preset="navigation"')
    expect(component).toContain('preset="selection"')
    expect(component).toContain('--bottom-navigation-outer-radius')
    expect(component).toContain('--bottom-navigation-inner-radius')
    expect(component).not.toContain('@wxperia/liquid-glass-vue')
    expect(declarationsFor('.bottom-navigation__selection')).toMatch(/top\s*:\s*5px/)
    expect(declarationsFor('.bottom-navigation__selection')).toMatch(/bottom\s*:\s*5px/)
  })
})
