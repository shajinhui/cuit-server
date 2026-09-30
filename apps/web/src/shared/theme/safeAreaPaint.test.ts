import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

import { describe, expect, it } from 'vitest'

const html = readFileSync(new URL('../../../index.html', import.meta.url), 'utf8')
const stylesheet = readFileSync(new URL('../../styles/main.css', import.meta.url), 'utf8')
const bootScript = html.match(/<script>([\s\S]*?)<\/script>/)?.[1]

function boot(path: string, stored: string | null, systemDark = false) {
  const values = new Map<string, string>()
  const root = { dataset: {} as Record<string, string>, style: { setProperty: (key: string, value: string) => values.set(key, value) } }
  const meta = { content: '', setAttribute: (_key: string, value: string) => { meta.content = value } }
  runInNewContext(bootScript ?? '', {
    location: { pathname: path },
    document: { documentElement: root, querySelector: () => meta },
    window: {
      localStorage: { getItem: () => stored },
      matchMedia: () => ({ matches: systemDark }),
    },
  })
  return { values, root, meta }
}

describe('安全区从启动首帧开始与页面共用底色', () => {
  it.each(['/', '/schedule'])('异步模块/会话尚未加载时 %s 已有课表底色', path => {
    const { values, meta } = boot(path, null)
    expect(values.get('--page-bg')).toBe('var(--bg-page-schedule, var(--launch-page))')
    expect(values.get('--launch-page')).toBe('#c9d5e7')
    expect(meta.content).toBe('#c9d5e7')
  })

  it.each(['/login', '/tools', '/profile', '/ratings'])('%s 启动使用分组底色而非白色画布', path => {
    const { values, meta } = boot(path, null)
    expect(values.get('--page-bg')).toBe('var(--bg-page, var(--launch-page))')
    expect(values.get('--launch-page')).toBe('#f2f2f7')
    expect(meta.content).toBe('#f2f2f7')
  })

  it('显式主题优先，跟随系统也能在首帧解析深色', () => {
    expect(boot('/schedule', 'dark').meta.content).toBe('#0f141c')
    expect(boot('/schedule', null, true).meta.content).toBe('#0f141c')
    expect(boot('/schedule', 'light', true).meta.content).toBe('#c9d5e7')
    expect(boot('/profile', 'dark').meta.content).toBe('#1c1c1e')
  })

  it('主样式不把 html/body 改回独立的画布色', () => {
    const source = stylesheet.replace(/\/\*[\s\S]*?\*\//g, '').replace(/@import[^;]+;/g, '')
    for (const selector of [':root', 'html', 'body']) {
      const declarations = [...source.matchAll(/([^{}]+)\{([^{}]*)\}/g)]
        .filter(match => match[1].split(',').some(part => part.trim() === selector))
        .map(match => match[2]).join('\n')
      expect(declarations, selector).toMatch(/background\s*:\s*var\(--page-bg\)/)
      expect(declarations, selector).not.toMatch(/background\s*:\s*var\(--app-canvas\)/)
    }
  })

  it('启动路径的高优先级样式也读实时底色，不永久锁死课表色', () => {
    const initialRule = html.match(/html\[data-initial-page='schedule'\],[\s\S]*?\{([^}]*)\}/)?.[1]
    expect(initialRule).toContain('background: var(--page-bg, var(--launch-page))')
  })
})
