/**
 * 读取主题令牌的运行时值。
 *
 * CSS 里一律用 var(--token)；只有需要把颜色交给浏览器 UI（meta theme-color、
 * Android 系统栏）时才需要解析成具体色值，走这里的 API。
 */

const tokenNames = [
  'app-canvas',
  'app-canvas-rgb',
  'page-bg',
  'bg-page',
  'bg-page-cool',
  'bg-page-blue',
  'bg-page-warm',
  'bg-page-deep',
  'bg-page-schedule',
  'bg-subtle',
  'bg-cell',
  'bg-surface',
  'bg-surface-raised',
  'bg-surface-glass',
  'bg-surface-soft',
  'bg-glass',
  'bg-glass-faint',
  'bg-glass-bright',
  'bg-surface-overlay',
  'bg-nav',
  'bg-nav-strong',
  'bg-scrim',
  'control-bg',
  'control-active-bg',
  'control-pressed-bg',
  'control-thumb',
  'control-track',
  'control-track-soft',
  'control-icon-disabled',
  'control-icon-muted',
  'text-primary',
  'text-strong',
  'text-body',
  'text-secondary',
  'text-tertiary',
  'text-slate',
  'text-label',
  'text-muted',
  'text-faint',
  'text-placeholder',
  'text-placeholder-soft',
  'text-cool',
  'text-on-accent',
  'line',
  'line-strong',
  'line-faint',
  'line-soft',
  'line-medium',
  'line-strong-alpha',
  'line-heavy',
  'edge-highlight',
  'edge-highlight-soft',
  'edge-highlight-faint',
  'edge-highlight-strong',
  'shadow-sm',
  'shadow-md',
  'shadow-lg',
  'shadow-card',
  'shadow-ambient',
  'shadow-inset-line',
  'shadow-popover',
  'accent',
  'accent-weak',
  'accent-tint',
  'blue',
  'blue-strong',
  'blue-link',
  'blue-schedule',
  'blue-autorun',
  'blue-deep',
  'blue-bright',
  'blue-ink',
  'blue-ink-deep',
  'blue-slate',
  'blue-slate-soft',
  'blue-slate-deep',
  'blue-soft',
  'blue-chip',
  'blue-count',
  'blue-muted',
  'blue-muted-soft',
  'blue-slate-muted',
  'blue-row',
  'blue-tint',
  'blue-ring',
  'blue-tint-weak',
  'blue-tint-strong',
  'danger',
  'danger-strong',
  'danger-deep',
  'danger-soft',
  'danger-tint',
  'warning',
  'warning-deep',
  'warning-soft',
  'success',
  'success-strong',
  'success-deep',
  'success-tint',
  'chart-blue',
  'chart-amber',
  'chart-rose',
  'chart-slate',
  'chart-violet',
  'chart-green',
  'chart-blue-soft',
  'chart-grid',
  'chart-grid-strong',
  'chart-grid-soft',
  'chart-axis',
  'chart-line',
  'chart-line-soft',
  'chart-line-faint',
  'chart-bar',
  'metric-danger',
  'metric-rose-soft',
  'map-ink',
  'map-ink-soft',
  'map-shadow',
  'map-shadow-strong',
  'map-lane',
  'map-tint',
  'map-tint-soft',
  'map-tint-faint',
  'map-tint-weak',
  'map-tint-mist',
  'map-border',
  'map-border-soft',
  'map-surface',
  'schedule-ink',
  'schedule-ink-soft',
  'schedule-muted',
] as const

export type ThemeTokenName = (typeof tokenNames)[number]

const tokenNameSet = new Set<string>(tokenNames)

export function isThemeTokenName(value: string): value is ThemeTokenName {
  return tokenNameSet.has(value)
}

export function themeTokenVar(name: ThemeTokenName) {
  return `--${name}`
}

export function themeTokenRef(name: ThemeTokenName) {
  return `var(${themeTokenVar(name)})`
}

let tokenValueCache: Map<string, string> | null = null

/** 主题切换后必须清缓存，否则 meta theme-color 会停留在上一套主题。 */
export function clearThemeTokenCache() {
  tokenValueCache = null
}

export function readThemeTokens() {
  if (typeof document === 'undefined') return new Map<string, string>()
  if (tokenValueCache) return tokenValueCache

  const styles = getComputedStyle(document.documentElement)
  const values = new Map<string, string>()
  for (const name of tokenNames) {
    const value = styles.getPropertyValue(themeTokenVar(name)).trim()
    if (value) values.set(name, value)
  }
  tokenValueCache = values
  return values
}

/** 解析令牌为具体色值；令牌缺失或为空时回落到 fallback（默认取画布色）。 */
export function resolveThemeToken(name: ThemeTokenName, fallback = '#f2f2f7') {
  const tokens = readThemeTokens()
  return tokens.get(name) || tokens.get('app-canvas') || fallback
}
