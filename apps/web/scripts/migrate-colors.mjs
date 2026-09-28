/**
 * 一次性迁移脚本：把 CSS 里写死的颜色替换成 theme.css 的语义令牌。
 *
 * 用法：
 *   node scripts/migrate-colors.mjs          # 预览（只报告，不写文件）
 *   node scripts/migrate-colors.mjs --write  # 实际写入
 *   node scripts/migrate-colors.mjs --write --files=schedule.css,grades.css
 *   node scripts/migrate-colors.mjs --write --report=white   # 只打印 #fff 的判定结果
 *
 * 映射表见 scripts/color-map.mjs；#fff 的上下文判定见 scripts/white-role.mjs。
 * 未命中的颜色会被列出来，需要人工决定去留：图标插画、课程分类色、
 * 页面专属色板属于"有意保留"或"由页面自己的深色覆盖处理"。
 */
import { readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { colorTokenMap } from './color-map.mjs'

const stylesDir = fileURLToPath(new URL('../src/styles', import.meta.url))
const write = process.argv.includes('--write')
const report = process.argv.find((arg) => arg.startsWith('--report='))?.slice('--report='.length)
const only = process.argv.find((arg) => arg.startsWith('--files='))?.slice('--files='.length).split(',')

// 排除 rgb(var(--token) / .93) 这类写法：里面的 var() 不是颜色字面量。
const COLOR = /#[0-9a-fA-F]{3,8}\b|(?<!var\()rgba?\([^)]*\)/g
const COMMENT = /\/\*[\s\S]*?\*\//g
// mask-image 渐变里的 #000 只是遮罩模板，不代表颜色，绝不能令牌化。
const MASK_DECLARATION = /(?:-webkit-)?mask(?:-image)?\s*:[^;}]*/g

const skipFiles = new Set(['theme.css'])

function normalize(value) {
  const normalized = value.toLowerCase().replace(/\s+/g, '')
  // #ffffff 与 #fff 等价，统一按三位写法查表
  if (/^#[0-9a-f]{6}$/.test(normalized)) {
    const [r1, r2, g1, g2, b1, b2] = normalized.slice(1)
    if (r1 === r2 && g1 === g2 && b1 === b2) return `#${r1}${g1}${b1}`
  }
  return normalized
}

/** 映射表的键也做同样的规范化，否则 #ffffff 这类写法会漏掉。 */
function buildTokenLookup(map) {
  const lookup = new Map()
  for (const [key, token] of Object.entries(map)) {
    const normalized = normalize(key)
    const existing = lookup.get(normalized)
    if (existing && existing !== token) {
      throw new Error(`映射表冲突：${normalized} 同时指向 ${existing} 与 ${token}`)
    }
    lookup.set(normalized, token)
  }
  return lookup
}

const tokenLookup = buildTokenLookup(colorTokenMap)

/** 判断某个色值在文件中的出现位置属于哪条声明、哪个选择器。 */
function describePosition(source, index) {
  const declarationStart = Math.max(
    source.lastIndexOf(';', index) + 1,
    source.lastIndexOf('{', index) + 1,
    source.lastIndexOf('}', index) + 1,
  )
  const declarationEnd = source.indexOf(';', index)
  const declaration = source.slice(declarationStart, declarationEnd === -1 ? undefined : declarationEnd)
  const property = /^\s*([a-z-]+)\s*:/i.exec(declaration)?.[1] ?? ''
  const selectorStart = Math.max(source.lastIndexOf('{', index), source.lastIndexOf('}', index)) + 1
  const selectorEnd = source.indexOf('{', selectorStart)
  const selector = source.slice(selectorStart, selectorEnd === -1 ? index : selectorEnd)
  return { property, declaration, selector }
}

/**
 * #fff 在深色下必须区分两种角色：
 *  - 彩色实底上的文字（color / fill / stroke，或选择器指向彩色元素）→ --text-on-accent，永远白色；
 *  - 卡片或弹层底色 → --bg-surface，深色下变深灰。
 * 判成文字的白色装饰层会变成深色斑点，判成表面的浅色文字会变成深灰，
 * 两种情况在深色下都一眼可见，便于回归时发现。
 */
const TEXT_PROPERTIES = new Set(['color', 'fill', 'stroke', 'caret-color', 'text-decoration-color'])
const SURFACE_PROPERTIES = new Set(['background', 'background-color', 'background-image'])
const HIGHLIGHT_PROPERTIES = new Set([
  'border',
  'border-color',
  'border-top',
  'border-bottom',
  'border-left',
  'border-right',
  'border-top-color',
  'border-bottom-color',
  'border-left-color',
  'border-right-color',
  'box-shadow',
  'outline',
  'outline-color',
  'text-shadow',
])
const ON_ACCENT_HINTS = [
  '--on-accent',
  '--blue',
  '--accent',
  '--green',
  '--danger',
  '--success',
  '--warning',
  '--chart',
  '--metric',
]

function resolveWhiteToken(source, index) {
  const { property, declaration, selector } = describePosition(source, index)
  const lowerProperty = property.toLowerCase()
  const context = `${selector} ${declaration}`.toLowerCase()

  if (TEXT_PROPERTIES.has(lowerProperty)) return 'text-on-accent'
  if (SURFACE_PROPERTIES.has(lowerProperty)) {
    return ON_ACCENT_HINTS.some((hint) => context.includes(hint)) ? 'text-on-accent' : 'bg-surface'
  }
  if (HIGHLIGHT_PROPERTIES.has(lowerProperty)) return 'edge-highlight'
  if (declaration.includes('gradient')) return 'edge-highlight'
  // 其它情况（自定义属性、简写）保持表面语义。
  return 'bg-surface'
}

const files = readdirSync(stylesDir)
  .filter((name) => name.endsWith('.css'))
  .filter((name) => !skipFiles.has(name))
  .filter((name) => !only || only.includes(name))
  .sort()

let totalReplaced = 0
const missed = new Map()
const whiteDecisions = []

for (const name of files) {
  const path = join(stylesDir, name)
  const source = readFileSync(path, 'utf8')
  // 注释与遮罩声明原样保留，避免把说明文字或遮罩模板里的色值替换掉。
  const preserved = []
  const keep = (match) => {
    preserved.push(match)
    // NUL 作为占位符：CSS 源码里不会出现该字符，不会与真实内容冲突。
    return `\u0000${preserved.length - 1}\u0000`
  }
  const masked = source.replace(MASK_DECLARATION, keep).replace(COMMENT, keep)

  let replaced = 0
  const withTokens = masked.replace(COLOR, (match, offset) => {
    const key = normalize(match)
    const isWhite = key === '#fff'
    const token = isWhite ? resolveWhiteToken(masked, offset) : tokenLookup.get(key)

    if (!token) {
      missed.set(key, (missed.get(key) ?? 0) + 1)
      return match
    }

    if (isWhite) {
      const { property } = describePosition(masked, offset)
      whiteDecisions.push(`${name}\t${property || '?'}\t${token}`)
      if (report === 'white' && token !== 'text-on-accent') return match
    }

    replaced += 1
    return `var(--${token})`
  })

  // eslint-disable-next-line no-control-regex -- 占位符就是 NUL，见上方 keep()
  const restored = withTokens.replace(/\u0000(\d+)\u0000/g, (_, index) => preserved[Number(index)])

  if (replaced > 0) {
    totalReplaced += replaced
    console.log(`${write ? '写入' : '预览'} ${name}: ${replaced} 处`)
    if (write) writeFileSync(path, restored)
  }
}

console.log(`\n合计替换 ${totalReplaced} 处`)

if (report === 'white') {
  const grouped = new Map()
  for (const line of whiteDecisions) {
    const [, property, token] = line.split('\t')
    const key = `${token}\t${property}`
    grouped.set(key, (grouped.get(key) ?? 0) + 1)
  }
  console.log('\n#fff 判定统计：')
  for (const [key, count] of [...grouped].sort((a, b) => b[1] - a[1])) {
    console.log(`  ${String(count).padStart(4)}  ${key.replace('\t', ' / ')}`)
  }
}

if (missed.size > 0 && report !== 'white') {
  const sorted = [...missed].sort((a, b) => b[1] - a[1])
  console.log(`\n未命中 ${sorted.length} 种：`)
  for (const [value, count] of sorted) console.log(`  ${String(count).padStart(4)}  ${value}`)
}
