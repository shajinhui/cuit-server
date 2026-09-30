import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const stylesheet = readFileSync(new URL('../../styles/main.css', import.meta.url), 'utf8')
  .replace(/\/\*[\s\S]*?\*\//g, '')
const rules = [...stylesheet.matchAll(/([^{}]+)\{([^{}]*)\}/g)]

function declarationsFor(selector: string) {
  return rules
    .filter((match) => match[1].split(',').some((part) => part.trim() === selector))
    .map((match) => match[2])
    .join('\n')
}

describe('底部导航材质的背景采样边界', () => {
  it('布局和按压祖先不使用会隔断页面背景的 clip-path 或 filter', () => {
    for (const selector of [
      '.bottom-navigation__glass',
      '.bottom-navigation__content',
      '.bottom-navigation__selection',
      '.bottom-navigation__glass > .relative',
      '.bottom-navigation__selection > .relative',
      '.bottom-navigation__selection.is-lifted',
    ]) {
      const declarations = declarationsFor(selector)
      expect(declarations, selector).not.toMatch(/(?:^|[;\n])\s*(?:-webkit-)?(?:clip-path|filter|mask(?:-image)?)\s*:/)
      expect(declarations, selector).not.toMatch(/contain\s*:\s*paint/)
    }
    expect(declarationsFor('.bottom-navigation__glass .glass__warp')).toMatch(/clip-path\s*:/)
    expect(declarationsFor('.bottom-navigation__selection .glass__warp')).toMatch(/clip-path\s*:/)
  })

  it('外栏和选中胶囊的全部库图层用布局百分比尺寸，避免重复放大高光', () => {
    for (const selector of ['.bottom-navigation__glass > *', '.bottom-navigation__selection > *']) {
      const declarations = declarationsFor(selector)
      expect(declarations, selector).toMatch(/width\s*:\s*100%\s*!important/)
      expect(declarations, selector).toMatch(/height\s*:\s*100%\s*!important/)
    }
  })

  it('深浅色薄膜位于滤镜之后，不给滤镜父层叠加不透明底板', () => {
    expect(declarationsFor('.bottom-navigation__glass .glass')).toMatch(/background\s*:\s*transparent/)
    expect(declarationsFor('.bottom-navigation__selection .glass')).toMatch(/background\s*:\s*transparent/)
    expect(declarationsFor('.bottom-navigation__glass-fill')).toMatch(/background\s*:\s*var\(--bg-glass-faint\)/)
    expect(declarationsFor('.bottom-navigation__selection-fill')).toMatch(/background\s*:\s*var\(--control-track-soft\)/)
  })

  it('保留库的边缘高光，但不让混合模式干扰背景合成', () => {
    for (const selector of ['.bottom-navigation__glass > span', '.bottom-navigation__selection > span']) {
      expect(declarationsFor(selector), selector).toMatch(/mix-blend-mode\s*:\s*normal\s*!important/)
    }
  })
})
