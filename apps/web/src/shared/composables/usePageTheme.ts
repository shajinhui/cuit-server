import { onActivated, onBeforeUnmount, onDeactivated, onMounted, watch } from 'vue'

import { setNativeSystemBarTheme } from '@/shared/native/systemBars'
import type { ResolvedColorScheme } from '@/shared/theme/colorScheme'
import { isThemeTokenName, resolveThemeToken, themeTokenVar, type ThemeTokenName } from '@/shared/theme/tokens'
import { useColorScheme } from '@/shared/theme/useColorScheme'

/**
 * 声明当前页面的底色。
 *
 * 参数传语义令牌名（见 theme.css），例如 usePageTheme('bg-page')。
 * 历史代码里传过十六进制色值，那种写法在深色主题下不会跟随，新代码不要再用。
 *
 * 实现要点：
 *  1. 颜色写进 --page-bg（由 theme.css 的 html/body 消费），而不是内联背景色，
 *     这样主题切换时只有变量值变化，不会和令牌层的深色值打架；
 *  2. 卸载时只清理由本页面写入的值（currentOwner 守卫），避免路由切换时
 *     后挂载的页面被前一个页面的清理覆盖；
 *  3. 主题切换后重新解析令牌，把新色值同步给 meta theme-color 与 Android 系统栏。
 */

const pageBackgroundVar = themeTokenVar('page-bg')

let currentOwner: symbol | null = null

const fallbackCanvas = '#f2f2f7'

function resolvePageColor(color: ThemeTokenName | string) {
  return isThemeTokenName(color) ? resolveThemeToken(color, fallbackCanvas) : color
}

/** 写入页面底色并同步 meta theme-color 与系统栏；导出供测试直接验证。 */
export function applyPageColor(color: ThemeTokenName | string, mode: ResolvedColorScheme) {
  if (typeof document === 'undefined') return

  const resolvedColor = resolvePageColor(color)
  document.documentElement.style.setProperty(pageBackgroundVar, resolvedColor)
  document
    .querySelector<HTMLMetaElement>('meta[name="theme-color"]')
    ?.setAttribute('content', resolvedColor)
  void setNativeSystemBarTheme({ color: resolvedColor, mode })
}

/** 撤销页面底色，回落到画布色；导出供测试直接验证。 */
export function clearPageColor(mode: ResolvedColorScheme) {
  if (typeof document === 'undefined') return

  document.documentElement.style.removeProperty(pageBackgroundVar)
  const canvas = resolveThemeToken('app-canvas', fallbackCanvas)
  document
    .querySelector<HTMLMetaElement>('meta[name="theme-color"]')
    ?.setAttribute('content', canvas)
  void setNativeSystemBarTheme({ color: canvas, mode })
}

export function usePageTheme(color: ThemeTokenName | string) {
  const owner = Symbol('page-theme')
  const { resolved } = useColorScheme()
  // 卸载阶段不能再依赖 watch 的触发时机，自己记住最后一次生效的模式。
  let lastMode: ResolvedColorScheme = resolved.value

  function activate() {
    currentOwner = owner
    lastMode = resolved.value
    applyPageColor(color, lastMode)
  }

  function deactivate() {
    if (currentOwner !== owner) return

    currentOwner = null
    clearPageColor(lastMode)
  }

  onMounted(activate)
  onActivated(activate)

  // 主题切换（含系统配色变化）后重新解析令牌：颜色本身来自 CSS 变量，
  // 但 meta theme-color 与 Android 系统栏需要具体色值。
  watch(resolved, (mode) => {
    if (currentOwner !== owner) return
    lastMode = mode
    applyPageColor(color, mode)
  })

  onBeforeUnmount(deactivate)
  onDeactivated(deactivate)
}
