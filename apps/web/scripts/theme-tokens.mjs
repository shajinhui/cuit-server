/**
 * 主题令牌维护工具。
 *
 * theme.css 里同一批令牌要写三处（浅色、深色、跟随系统的深色），手写容易漏。
 * 本脚本负责：
 *   --check   校验三处令牌键集合、顺序一致，且没有游离在 @media 与内层选择器之间的声明
 *   --fix     把游离声明搬回内层选择器之后（历史上 patchTokens 插入点错误留下的）
 *   导入 patchTokens() 用于新增令牌时三处一起补全
 *
 * 用法：
 *   node scripts/theme-tokens.mjs --check
 *   node scripts/theme-tokens.mjs --fix
 *
 * 注意：@media (prefers-color-scheme: dark) 里，块区间必须从**内层选择器之后**开始。
 * 早期版本把 @media 行的下一行当作块起点，于是新令牌被插在 @media 与选择器之间，
 * 产出浏览器会整段丢弃的坏 CSS（lightningcss 会直接让构建失败）。
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const themePath = fileURLToPath(new URL('../src/styles/theme.css', import.meta.url))

const BLOCKS = [
  { name: 'light', selector: /^:root,$/, end: /^\}$/ },
  { name: 'dark', selector: /^\.theme-dark,$/, end: /^\}$/ },
  { name: 'system-dark', selector: /^@media \(prefers-color-scheme: dark\) \{$/, end: /^ {2}\}$/ },
]

/**
 * 找出三个令牌块。
 * 返回的 start 是「第一条令牌允许出现的行」，即内层选择器之后那一行，
 * 对 @media 块来说是 `:root:not(...) {` 之后，而不是 @media 之后。
 */
export function locateBlocks(lines = readFileSync(themePath, 'utf8').split('\n')) {
  const found = []
  const searchFrom = { value: 0 }

  for (const block of BLOCKS) {
    const selectorLine = lines.findIndex(
      (line, index) => index >= searchFrom.value && block.selector.test(line),
    )
    if (selectorLine === -1) throw new Error(`theme.css 里找不到 ${block.name} 块的选择器`)

    // 从选择器往下找"第一个以 { 结尾的行"，这就是包含令牌的内层选择器。
    let open = selectorLine
    while (open < lines.length && !lines[open].trimEnd().endsWith('{')) open += 1
    if (open >= lines.length) throw new Error(`${block.name} 块没有找到 {`)

    let close = open + 1
    while (close < lines.length && !block.end.test(lines[close])) close += 1
    if (close >= lines.length) throw new Error(`${block.name} 块没有找到收尾的 }`)

    found.push({ name: block.name, selectorLine, open, start: open + 1, end: close })
    searchFrom.value = close + 1
  }

  if (found.length !== BLOCKS.length) {
    throw new Error(`只找到 ${found.length} 个令牌块，期望 ${BLOCKS.length}`)
  }
  return found
}

function parseTokens(lines, block) {
  const tokens = []
  const seen = new Set()
  for (let index = block.start; index < block.end; index += 1) {
    const match = /^(\s*)(--[a-z0-9-]+):\s*(.*?);\s*$/.exec(lines[index])
    if (!match) continue
    const [, indent, name, value] = match
    if (seen.has(name)) throw new Error(`${block.name} 块里重复定义 ${name}`)
    seen.add(name)
    tokens.push({ name, value, indent, line: index })
  }
  return tokens
}

/** 找出夹在块选择器与其内层选择器之间的声明（历史 bug 残留）。 */
export function findStrayDeclarations(lines = readFileSync(themePath, 'utf8').split('\n')) {
  const strays = []
  for (const block of locateBlocks(lines)) {
    for (let index = block.selectorLine + 1; index < block.open; index += 1) {
      if (lines[index].trim()) strays.push({ block: block.name, line: index, text: lines[index] })
    }
  }
  return strays
}

/**
 * 按名字插入/更新令牌，保持三块同步。
 * entries: [{ name, values: { light, dark, 'system-dark' }, after? }]
 * after 指向的锚点在三块里都必须存在——找不到直接抛错，不猜位置。
 */
export function patchTokens(entries, { write = true } = {}) {
  const lines = readFileSync(themePath, 'utf8').split('\n')
  const strays = findStrayDeclarations(lines)
  if (strays.length > 0) {
    throw new Error(
      `theme.css 里存在游离声明（${strays.map((item) => item.text.trim()).join(' / ')}），` +
        '请先运行 node scripts/theme-tokens.mjs --fix',
    )
  }

  const blocks = locateBlocks(lines)

  // 从后往前改，避免行号漂移
  for (const block of [...blocks].reverse()) {
    const parsed = parseTokens(lines, block)
    if (parsed.length === 0) throw new Error(`${block.name} 块里没有解析到任何令牌`)
    const indent = parsed[0].indent
    const byName = new Map(parsed.map((token) => [token.name, token]))

    for (const entry of entries) {
      const value = entry.values?.[block.name]
      if (value === undefined) throw new Error(`${entry.name} 缺少 ${block.name} 的值`)

      const existing = byName.get(entry.name)
      if (existing) {
        lines[existing.line] = `${indent}${entry.name}: ${value};`
        continue
      }

      if (!entry.after) throw new Error(`${entry.name} 是新增令牌，必须指定 after 锚点`)
      const anchor = byName.get(entry.after)
      if (!anchor) {
        throw new Error(`${entry.name} 的锚点 ${entry.after} 在 ${block.name} 块里不存在，拒绝插入`)
      }
      const insertAt = anchor.line + 1
      if (insertAt <= block.open || insertAt >= block.end) {
        throw new Error(`${entry.name} 的插入位置越界，已中止`)
      }
      lines.splice(insertAt, 0, `${indent}${entry.name}: ${value};`)
      byName.set(entry.name, { name: entry.name, line: insertAt })
    }
  }

  if (write) writeFileSync(themePath, lines.join('\n'))
  return { blocks }
}

/** 把游离声明按值搬回 system-dark 块内。 */
export function fixStrayDeclarations() {
  const lines = readFileSync(themePath, 'utf8').split('\n')
  const strays = findStrayDeclarations(lines)
  if (strays.length === 0) return 0

  const mediaBlock = locateBlocks(lines).find((block) => block.name === 'system-dark')
  const kept = []
  const moved = []
  for (let index = 0; index < lines.length; index += 1) {
    const stray = strays.find((item) => item.line === index)
    if (!stray) {
      kept.push(lines[index])
      continue
    }
    const match = /^\s*(--[a-z0-9-]+):\s*(.+?);\s*$/.exec(stray.text)
    if (!match) throw new Error(`游离内容不是声明，需人工处理：${stray.text}`)
    moved.push({ name: match[1], value: match[2] })
  }

  const anchorLine = kept.findIndex(
    (line, index) => index > mediaBlock.open && /^\s*--schedule-muted:/.test(line),
  )
  if (anchorLine === -1) throw new Error('system-dark 块里找不到 --schedule-muted 锚点')

  const insert = moved.map((item) => `    ${item.name}: ${item.value};`)
  const result = [...kept.slice(0, anchorLine + 1), ...insert, ...kept.slice(anchorLine + 1)]
  writeFileSync(themePath, result.join('\n'))
  return moved.length
}

/** 校验：三块键集合与顺序一致，且没有游离声明。 */
export function checkTokens() {
  const lines = readFileSync(themePath, 'utf8').split('\n')
  const strays = findStrayDeclarations(lines)
  const blocks = locateBlocks(lines)
  const parsed = blocks.map((block) => ({ name: block.name, tokens: parseTokens(lines, block) }))
  const [light, ...rest] = parsed
  const problems = []

  const lightNames = light.tokens.map((token) => token.name)
  for (const block of rest) {
    const names = block.tokens.map((token) => token.name)
    const missing = lightNames.filter((name) => !names.includes(name))
    const extra = names.filter((name) => !lightNames.includes(name))
    if (missing.length) problems.push(`${block.name} 缺少：${missing.join(', ')}`)
    if (extra.length) problems.push(`${block.name} 多出：${extra.join(', ')}`)
  }

  for (const stray of strays) {
    problems.push(`${stray.block} 块的选择器之前有游离声明：${stray.text.trim()}`)
  }

  console.log(
    `浅色 ${light.tokens.length} 个 / 深色 ${rest[0].tokens.length} 个 / 系统深色 ${rest[1].tokens.length} 个`,
  )
  if (problems.length) {
    for (const problem of problems) console.error(`✗ ${problem}`)
    return false
  }
  console.log('✓ 三处令牌一致，且没有游离声明')
  return true
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (process.argv.includes('--check')) {
    process.exit(checkTokens() ? 0 : 1)
  }
  if (process.argv.includes('--fix')) {
    const count = fixStrayDeclarations()
    console.log(count > 0 ? `已搬回 ${count} 条游离声明` : '没有游离声明')
    process.exit(checkTokens() ? 0 : 1)
  }
  console.log('用法：node scripts/theme-tokens.mjs --check | --fix')
}
