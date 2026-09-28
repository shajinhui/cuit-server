/**
 * 主题偏好的读写与系统检测。
 *
 * 这里刻意不依赖 Vue：index.html 的首帧启动脚本需要同一套规则来决定初始主题，
 * 两处不一致会导致刷新时闪白。storage key 与取值格式改动时必须同步 index.html。
 */

export type ColorSchemePreference = 'light' | 'dark' | 'system'
export type ResolvedColorScheme = 'light' | 'dark'

export const COLOR_SCHEME_STORAGE_KEY = 'color-scheme-preference'
export const DEFAULT_COLOR_SCHEME_PREFERENCE: ColorSchemePreference = 'system'
export const DARK_COLOR_SCHEME_QUERY = '(prefers-color-scheme: dark)'

/**
 * 设置项文案。'跟随系统' 保持完整写法，兼容原生外观设置术语；
 * 分段控件里空间紧张时可以按需用 shortLabel。
 */
export const COLOR_SCHEME_OPTIONS: {
  value: ColorSchemePreference
  label: string
  shortLabel: string
}[] = [
  { value: 'system', label: '跟随系统', shortLabel: '系统' },
  { value: 'light', label: '浅色', shortLabel: '浅色' },
  { value: 'dark', label: '深色', shortLabel: '深色' },
]

const darkQuery = DARK_COLOR_SCHEME_QUERY

export function normalizeColorSchemePreference(value: unknown): ColorSchemePreference {
  return value === 'light' || value === 'dark' || value === 'system'
    ? value
    : DEFAULT_COLOR_SCHEME_PREFERENCE
}

export function readColorSchemePreference(): ColorSchemePreference {
  if (typeof window === 'undefined') return DEFAULT_COLOR_SCHEME_PREFERENCE

  try {
    return normalizeColorSchemePreference(window.localStorage.getItem(COLOR_SCHEME_STORAGE_KEY))
  } catch {
    // 隐私模式等场景下 localStorage 不可用，回落到跟随系统。
    return DEFAULT_COLOR_SCHEME_PREFERENCE
  }
}

export function writeColorSchemePreference(preference: ColorSchemePreference) {
  if (typeof window === 'undefined') return

  try {
    if (preference === DEFAULT_COLOR_SCHEME_PREFERENCE) {
      window.localStorage.removeItem(COLOR_SCHEME_STORAGE_KEY)
    } else {
      window.localStorage.setItem(COLOR_SCHEME_STORAGE_KEY, preference)
    }
  } catch {
    // 偏好仅在当前会话生效，写入失败不阻断使用。
  }
}

export function systemPrefersDark() {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return false

  try {
    return window.matchMedia(darkQuery).matches
  } catch {
    return false
  }
}

export function resolveColorScheme(preference: ColorSchemePreference): ResolvedColorScheme {
  if (preference === 'system') return systemPrefersDark() ? 'dark' : 'light'
  return preference
}

/** 监听系统配色变化；不支持 matchMedia 时返回空清理函数。 */
export function subscribeSystemColorScheme(listener: () => void) {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
    return () => undefined
  }

  const media = window.matchMedia(darkQuery)
  media.addEventListener('change', listener)
  return () => media.removeEventListener('change', listener)
}
