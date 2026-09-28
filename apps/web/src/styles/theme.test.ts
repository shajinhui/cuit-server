import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

/**
 * 样式层守卫测试。
 *
 * 深色模式全靠 theme.css 的令牌切换：样式里写死的色值在深色下不会跟随。
 * 这个测试把"颜色必须来自令牌"变成可执行的约束：
 *
 *  1. 字面量总量不得超过基线（BASELINE_LITERALS）。剩余的都是内容色与装饰色
 *     （课程分类色、评分色板、SVG 示意图、一次性高光/阴影），固化基线后
 *     新增写死色值会立刻失败。
 *  2. 字面量种类也不能增加——只允许基线内继续收敛，不允许换一批新的。
 *  3. var() 引用的令牌必须有定义（拼写错误会在这里暴露）。
 *  4. theme.css 的浅色块与深色块键集合必须一致（漏一个深色值就会在深色下留白）。
 *
 * 迁移完成后收紧基线：node scripts/color-audit.mjs 看当前数字，改下面的常量。
 */

const stylesDir = fileURLToPath(new URL('./', import.meta.url))
const appRoot = fileURLToPath(new URL('../../', import.meta.url))

/**
 * 颜色字面量基线。当前 26 个样式表里只剩 94 处 / 88 种，全部是内容色与装饰色：
 * 课程分类色、校园跑与落地页的专属色板、插画与渐变、一次性投影与蒙层。
 * 这两个数字只允许变小——新增写死色值会立刻失败。
 */
const BASELINE_LITERALS = 94
const BASELINE_LITERAL_KINDS = 88

// 排除 rgb(var(--token) / .93) 这类写法：里面的 var() 不是颜色字面量。
const COLOR_LITERAL = /#[0-9a-fA-F]{3,8}\b|(?<!var\()\brgba?\([^)]*\)/g
const COMMENT = /\/\*[\s\S]*?\*\//g
const MASK_DECLARATION = /(?:-webkit-)?mask(?:-image)?\s*:[^;}]*/g
const TOKEN_DEFINITION = /^[ \t]*(--[a-z0-9-]+)[ \t]*:/gm
const TOKEN_USAGE = /var\(\s*(--[a-z0-9-]+)/g

/** 令牌定义处允许出现字面量；其余样式表按基线约束。 */
const TOKEN_FILES = new Set(['theme.css'])

function readStylesheet(name: string) {
  return readFileSync(`${stylesDir}${name}`, 'utf8')
}

function stripNonColorContext(source: string) {
  return source.replace(MASK_DECLARATION, ' ').replace(COMMENT, ' ')
}

const stylesheets = readdirSync(stylesDir).filter((name) => name.endsWith('.css'))

/** 读取 src 下的 .vue/.ts 源码，用于判断令牌是否真的被消费。 */
function readSourceTree(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = `${dir}/${entry.name}`
    if (entry.isDirectory()) return readSourceTree(path)
    if (!/\.(vue|ts)$/.test(entry.name)) return []
    return [readFileSync(path, 'utf8')]
  })
}
const themeStylesheets = stylesheets.filter((name) => !TOKEN_FILES.has(name))

describe('样式层颜色约束', () => {
  it('颜色字面量不超过基线（不新增写死色值）', () => {
    let total = 0
    const kinds = new Set<string>()
    const perFile: string[] = []

    for (const name of themeStylesheets) {
      const matches = stripNonColorContext(readStylesheet(name)).match(COLOR_LITERAL) ?? []
      if (matches.length === 0) continue
      total += matches.length
      for (const value of matches) kinds.add(value.toLowerCase().replace(/\s+/g, ''))
      perFile.push(`${name}: ${matches.length}`)
    }

    expect(
      { total: total > BASELINE_LITERALS, kinds: kinds.size > BASELINE_LITERAL_KINDS },
      `颜色字面量 ${total} 处 / ${kinds.size} 种，超过基线 ${BASELINE_LITERALS} / ${BASELINE_LITERAL_KINDS}。\n` +
        '新颜色请登记到 scripts/color-map.mjs，然后 node scripts/migrate-colors.mjs --write。\n' +
        `分布：${perFile.join('，')}`,
    ).toEqual({ total: false, kinds: false })
  })

  it('var() 引用的令牌都有定义（含 index.html 与运行期变量）', () => {
    const defined = new Set<string>()
    const used = new Map<string, Set<string>>()

    const sources: [string, string][] = stylesheets.map((name) => [name, readStylesheet(name)])
    sources.push(['index.html', readFileSync(`${appRoot}index.html`, 'utf8')])

    for (const [name, source] of sources) {
      for (const match of source.matchAll(TOKEN_DEFINITION)) defined.add(match[1])
      for (const match of source.matchAll(TOKEN_USAGE)) {
        const owners = used.get(match[1]) ?? new Set<string>()
        owners.add(name)
        used.set(match[1], owners)
      }
    }

    // 由 WebView 安全区或运行时代码提供，不在样式表里定义。
    const runtimeProvided = new Set([
      '--safe-area-inset-top',
      '--safe-area-inset-right',
      '--safe-area-inset-bottom',
      '--safe-area-inset-left',
      '--active-index',
      '--navigation-item-count',
      '--nav-icon',
      '--schedule-muted-opacity',
      '--schedule-section-count',
    ])

    const missing = [...used]
      .filter(([token]) => !defined.has(token) && !runtimeProvided.has(token))
      .map(([token, owners]) => `${token} ← ${[...owners].join(', ')}`)

    expect(missing, '存在没有定义的令牌引用（多半是拼写错误）').toEqual([])
  })

  it('没有无人消费的令牌（新增令牌必须真的被用上）', () => {
    const themeSource = readStylesheet('theme.css')
    const defined = new Set([...themeSource.matchAll(TOKEN_DEFINITION)].map((match) => match[1]))

    // 旧别名与成体系的阴影刻度是刻意保留的兼容层，允许暂时没有消费者。
    const intentional = new Set([
      // 迁移期保留的旧令牌别名
      '--green',
      '--green-deep',
      '--green-soft',
      '--muted',
      '--surface',
      '--shadow',
      // 整条阴影刻度：成体系提供，供 box-shadow 直接引用
      '--shadow-sm',
      '--shadow-md',
      '--shadow-lg',
      '--shadow-popover',
      '--shadow-card',
      '--shadow-ambient',
      // 由 usePageTheme 在运行时写入，不在静态样式里出现
      '--page-bg',
    ])

    const sources = [
      ...stylesheets.filter((name) => name !== 'theme.css').map((name) => readStylesheet(name)),
      readFileSync(`${appRoot}index.html`, 'utf8'),
      ...readSourceTree(`${appRoot}src`),
    ]

    const unused = [...defined].filter(
      (token) =>
        !intentional.has(token) &&
        !sources.some((source) => new RegExp(`${token}(?![a-z0-9-])`).test(source)),
    )

    expect(unused, 'theme.css 里存在没有任何消费者的令牌，请删除或说明保留原因').toEqual([])
  })

  it('theme.css 的浅色令牌与深色令牌键集合一致', () => {
    const source = readStylesheet('theme.css')
    const lightBlock = source.slice(
      source.indexOf(':root,'),
      source.indexOf('.theme-dark,'),
    )
    const darkBlock = source.slice(
      source.indexOf('.theme-dark,'),
      source.indexOf('@media (prefers-color-scheme: dark)'),
    )
    expect(lightBlock.length, 'theme.css 结构变化，请同步更新本测试').toBeGreaterThan(0)
    expect(darkBlock.length, 'theme.css 结构变化，请同步更新本测试').toBeGreaterThan(0)

    const names = (block: string) =>
      new Set([...block.matchAll(TOKEN_DEFINITION)].map((match) => match[1]))
    const light = names(lightBlock)
    const dark = names(darkBlock)

    expect({
      missingInDark: [...light].filter((token) => !dark.has(token)),
      extraInDark: [...dark].filter((token) => !light.has(token)),
    }).toEqual({ missingInDark: [], extraInDark: [] })
  })
})
