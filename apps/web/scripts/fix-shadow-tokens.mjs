/**
 * 迁移修正脚本（一次性）：
 *
 * 1. box-shadow / filter / background 等"消费色值"的位置被错误地填入了
 *    --shadow-* 这类整条阴影令牌，产出非法声明（如 `0 8px 24px 0 8px 24px ...`），
 *    需要换回纯色令牌 --shadow-color*。
 * 2. `0 0.5px 0|1px rgba(0,0,0,...)` 属于发丝描边而不是投影，深色下应该提亮，
 *    统一改为 --hairline*。
 *
 * 用法：node scripts/fix-shadow-tokens.mjs [--write]
 */
import { readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const stylesDir = fileURLToPath(new URL('../src/styles', import.meta.url))
const write = process.argv.includes('--write')

/** [匹配, 替换, 说明] */
const rules = [
  // 发丝描边：0 0.5px 0/1px 的浅色边，深色下要提亮而不是压暗
  [/0 0\.5px 0 var\(--map-shadow\)/g, '0 0.5px 0 var(--hairline)', '发丝描边'],
  [/0 0\.5px 1px var\(--map-shadow\)/g, '0 0.5px 1px var(--hairline)', '发丝描边'],
  [/0 0\.5px 0 var\(--shadow-sm\)/g, '0 0.5px 0 var(--hairline)', '发丝描边'],
  [/0 0\.5px 1px var\(--shadow-sm\)/g, '0 0.5px 1px var(--hairline)', '发丝描边'],
  [/0 0\.5px 0 var\(--shadow-inset-line\)/g, '0 0.5px 0 var(--hairline)', '发丝描边'],
  [/0 0\.5px 1px var\(--shadow-inset-line\)/g, '0 0.5px 1px var(--hairline)', '发丝描边'],
  // 投影模糊半径后的颜色：必须是纯色
  [/(\d+px \d+px \d+px )var\(--shadow-popover\)/g, '$1var(--shadow-color-strong)', '投影色'],
  [/(\d+px \d+px \d+px )var\(--shadow-lg\)/g, '$1var(--shadow-color)', '投影色'],
  [/(\d+px \d+px \d+px )var\(--shadow-md\)/g, '$1var(--shadow-color)', '投影色'],
  [/(\d+px \d+px \d+px )var\(--shadow-sm\)/g, '$1var(--shadow-color-soft)', '投影色'],
  [/(\d+px \d+px \d+px )var\(--shadow-inset-line\)/g, '$1var(--shadow-color-soft)', '投影色'],
  [/(\d+px \d+px )var\(--shadow-popover\)/g, '$1var(--shadow-color-strong)', '投影色'],
  [/(\d+px \d+px )var\(--shadow-lg\)/g, '$1var(--shadow-color)', '投影色'],
  [/(\d+px \d+px )var\(--shadow-md\)/g, '$1var(--shadow-color)', '投影色'],
  [/(\d+px \d+px )var\(--shadow-sm\)/g, '$1var(--shadow-color-soft)', '投影色'],
  [/(\d+px \d+px )var\(--shadow-inset-line\)/g, '$1var(--shadow-color-soft)', '投影色'],
  // 背景位置的阴影令牌：原本是深色蒙层
  [/background: var\(--shadow-lg\);/g, 'background: var(--shadow-color);', '蒙层底色'],
  [/background: var\(--shadow-popover\);/g, 'background: var(--shadow-color-strong);', '蒙层底色'],
  // 描边位置的阴影令牌：原本是极浅的分隔线
  [/border: 1px solid var\(--shadow-lg\);/g, 'border: 1px solid var(--line-soft);', '分隔线'],
  [/border: 1px solid var\(--shadow-md\);/g, 'border: 1px solid var(--line-soft);', '分隔线'],
  [/border: 1px solid var\(--shadow-sm\);/g, 'border: 1px solid var(--line-faint);', '分隔线'],
  // 地图阴影令牌被用在普通投影/背景位置：换回通用阴影色
  [/box-shadow: (\d+px \d+px \d+px) var\(--map-shadow\)/g, 'box-shadow: $1 var(--shadow-color-soft)', '投影色'],
  [/box-shadow: (\d+px \d+px \d+px) var\(--map-shadow-strong\)/g, 'box-shadow: $1 var(--shadow-color-strong)', '投影色'],
  [/(\d+px \d+px \d+px )var\(--map-lane\)/g, '$1var(--shadow-color-soft)', '投影色'],
  [/(\d+px \d+px \d+px )var\(--map-shadow-strong\)/g, '$1var(--shadow-color-strong)', '投影色'],
  [/(\d+px \d+px \d+px )var\(--map-shadow\)/g, '$1var(--shadow-color-soft)', '投影色'],
  [/background: var\(--map-shadow-strong\);/g, 'background: var(--scrim-strong);', '蒙层底色'],
  [/background: var\(--map-shadow\);/g, 'background: var(--scrim);', '蒙层底色'],
  [/background: var\(--map-lane\);/g, 'background: var(--scrim);', '蒙层底色'],
  [/inset 0 -1px 0 var\(--map-shadow-strong\)/g, 'inset 0 -1px 0 var(--line-soft)', '内描边'],
  [/inset 0 1px 0 var\(--map-shadow\)/g, 'inset 0 1px 0 var(--edge-highlight-soft)', '内高光'],
]

let total = 0
for (const name of readdirSync(stylesDir).filter((entry) => entry.endsWith('.css'))) {
  if (name === 'theme.css') continue
  const path = join(stylesDir, name)
  let source = readFileSync(path, 'utf8')
  let changed = 0
  for (const [pattern, replacement] of rules) {
    source = source.replace(pattern, (...args) => {
      changed += 1
      return typeof replacement === 'string' ? replacement.replace(/\$(\d)/g, (_, i) => args[Number(i)]) : replacement
    })
  }
  if (changed > 0) {
    total += changed
    console.log(`${write ? '写入' : '预览'} ${name}: ${changed} 处`)
    if (write) writeFileSync(path, source)
  }
}
console.log(`\n合计 ${total} 处`)
