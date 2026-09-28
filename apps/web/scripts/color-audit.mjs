// 审计 src 下 CSS 中的颜色字面量，统计频次并标注所在声明，用于主题令牌映射。
// 用法：node scripts/color-audit.mjs [--props]
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('../src', import.meta.url))
const withProps = process.argv.includes('--props')

function walk(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) return walk(full)
    return full.endsWith('.css') ? [full] : []
  })
}

// 排除 rgb(var(--token) / .93) 这类写法：里面的 var() 不是颜色字面量。
const COLOR = /#[0-9a-fA-F]{3,8}\b|(?<!var\()rgba?\([^)]*\)/g
const comments = /\/\*[\s\S]*?\*\//g

const colors = new Map()

for (const file of walk(root)) {
  const source = readFileSync(file, 'utf8')
  const rel = relative(root, file)
  // 记录注释区间，避免把注释里的色值算进来。
  const masked = source.replace(comments, (match) => ' '.repeat(match.length))
  for (const match of masked.matchAll(COLOR)) {
    const value = match[0].toLowerCase().replace(/\s+/g, '')
    const lineStart = masked.lastIndexOf('\n', match.index) + 1
    const lineEnd = masked.indexOf('\n', match.index)
    const line = masked.slice(lineStart, lineEnd === -1 ? undefined : lineEnd)
    const property = /^\s*([a-z-]+)\s*:/.exec(line)?.[1] ?? '?'
    const entry = colors.get(value) ?? { count: 0, files: new Map(), props: new Map(), samples: [] }
    entry.count += 1
    entry.files.set(rel, (entry.files.get(rel) ?? 0) + 1)
    entry.props.set(property, (entry.props.get(property) ?? 0) + 1)
    if (entry.samples.length < 2) entry.samples.push(`${rel}:${masked.slice(0, match.index).split('\n').length}`)
    colors.set(value, entry)
  }
}

const sorted = [...colors].sort((a, b) => b[1].count - a[1].count)
const total = sorted.reduce((sum, [, entry]) => sum + entry.count, 0)
console.log(`distinct=${sorted.length} occurrences=${total}\n`)

for (const [value, entry] of sorted) {
  const fileList = [...entry.files].sort((a, b) => b[1] - a[1]).slice(0, 3).map(([f, n]) => `${f}x${n}`).join(' ')
  const propList = withProps
    ? ' | ' + [...entry.props].sort((a, b) => b[1] - a[1]).slice(0, 4).map(([p, n]) => `${p}:${n}`).join(',')
    : ''
  console.log(`${String(entry.count).padStart(4)}  ${value.padEnd(30)} ${fileList}${propList}`)
}
