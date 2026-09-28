import { computed, ref } from 'vue'

import {
  COLOR_SCHEME_OPTIONS,
  type ColorSchemePreference,
  type ResolvedColorScheme,
  readColorSchemePreference,
  resolveColorScheme,
  subscribeSystemColorScheme,
  writeColorSchemePreference,
} from './colorScheme'
import { clearThemeTokenCache } from './tokens'

/**
 * 主题（浅色 / 深色 / 跟随系统）的唯一状态源。
 *
 * 生效方式是给 <html> 写 data-theme，样式层只认这个属性和 theme.css 里的令牌。
 * 偏好为 'system' 时移除该属性，交给 CSS 的 prefers-color-scheme 分支。
 *
 * 首帧之前的状态由 index.html 内联脚本写入（避免闪白），这里负责启动时的
 * 兜底同步、监听系统配色变化，以及用户切换。
 */

const preference = ref<ColorSchemePreference>(readColorSchemePreference())
const systemDark = ref(resolveColorScheme('system') === 'dark')

const resolved = computed<ResolvedColorScheme>(() =>
  preference.value === 'system' ? (systemDark.value ? 'dark' : 'light') : preference.value,
)

/**
 * 令牌缓存保存的是"当前主题下的解析结果"，主题一变就必须失效，
 * 否则 meta theme-color 与 Android 系统栏会停留在上一套配色。
 *
 * data-theme 只在用户显式选择浅色/深色时写入；跟随系统时移除该属性，
 * 让 theme.css 的 prefers-color-scheme 分支接管（系统切换无需 JS 参与）。
 * 移除属性会翻转级联结果，所以先删属性、再清缓存、最后读值。
 */
function syncDocumentTheme(value: ResolvedColorScheme, preferenceValue: ColorSchemePreference) {
  if (typeof document === 'undefined') return

  const root = document.documentElement
  if (preferenceValue === 'system') {
    delete root.dataset.theme
  } else {
    root.dataset.theme = value
  }
  clearThemeTokenCache()
}

/**
 * 在应用启动时调用一次（见 src/main.ts）。
 *
 * 不使用生命周期钩子：main.ts 不在组件 setup 作用域内，onMounted 不会触发。
 * 返回的清理函数供测试或热重载使用。
 */
export function registerColorSchemeRuntime() {
  if (typeof window === 'undefined') return () => undefined

  syncDocumentTheme(resolved.value, preference.value)
  const unsubscribe = subscribeSystemColorScheme(() => {
    systemDark.value = resolveColorScheme('system') === 'dark'
    // 跟随系统时属性本来就不存在，这里只需要让令牌缓存失效。
    if (preference.value === 'system') clearThemeTokenCache()
  })

  return () => {
    unsubscribe()
  }
}

export function setColorSchemePreference(next: ColorSchemePreference) {
  preference.value = next
  writeColorSchemePreference(next)
  syncDocumentTheme(resolved.value, next)
}

/** 仅供测试使用：把模块级状态复位到"读取本地偏好 + 跟随系统"的初始状态。 */
export function resetColorSchemeStateForTests() {
  preference.value = readColorSchemePreference()
  systemDark.value = resolveColorScheme('system') === 'dark'
  clearThemeTokenCache()
}

export function useColorScheme() {
  return {
    preference,
    resolved,
    options: COLOR_SCHEME_OPTIONS,
    setPreference: setColorSchemePreference,
  }
}
