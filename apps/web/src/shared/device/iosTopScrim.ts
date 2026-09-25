import { Capacitor } from '@capacitor/core'

/**
 * iOS 27 can composite a system scroll-pocket blur over installed web apps and
 * native shells. Native shells disable the UIKit edge effect directly; standalone
 * web apps use the fixed color extension in `main.css` to give WebKit a stable
 * top edge without adding layout space.
 */
export const IOS_TOP_SCRIM_DATA_KEY = 'iosTopScrim'

const IOS_TOP_SCRIM_FIRST_MAJOR = 27

/**
 * Reads the iOS major version out of a Safari/WKWebView user agent, e.g.
 * `(iPhone; CPU iPhone OS 27_0 like Mac OS X)` or `(iPad; CPU OS 27_1 like Mac OS X)`.
 * Safari 26+ freezes the OS part of its iOS user agent at 18.x, so the Safari
 * `Version/26.0` (or later) token is also considered. iPads that request the
 * desktop site report a macOS user agent and yield `undefined`.
 */
export function detectIosMajorVersion(userAgent: string): number | undefined {
  if (!/(?:iPhone|iPad|iPod)/i.test(userAgent)) return undefined

  const versions = [
    /(?:iPhone|CPU) OS (\d+)[._]/i.exec(userAgent)?.[1],
    /(?:^|[\s(;])Version\/(\d+)(?:[._])/i.exec(userAgent)?.[1],
  ]
    .map((version) => Number(version))
    .filter((version) => Number.isInteger(version))

  return versions.length > 0 ? Math.max(...versions) : undefined
}

export interface IosTopScrimContext {
  userAgent: string
  /** Installed/standalone web app (`display-mode: standalone` or `navigator.standalone`). */
  installedWebApp: boolean
  /** Capacitor iOS shell, where the page also fills the whole window. */
  nativeIos: boolean
}

export function shouldApplyIosTopScrim(context: IosTopScrimContext): boolean {
  if (!context.installedWebApp && !context.nativeIos) return false
  const major = detectIosMajorVersion(context.userAgent)
  return major !== undefined && major >= IOS_TOP_SCRIM_FIRST_MAJOR
}

function isInstalledWebApp(): boolean {
  if ((window.navigator as Navigator & { standalone?: boolean }).standalone === true) return true
  return window.matchMedia('(display-mode: standalone)').matches
}

/**
 * Marks the document so `main.css` can enable the standalone-app workaround.
 * Called once before the app mounts.
 */
export function applyIosTopScrim(): boolean {
  if (typeof window === 'undefined') return false

  const active = shouldApplyIosTopScrim({
    userAgent: window.navigator.userAgent,
    installedWebApp: isInstalledWebApp(),
    nativeIos: Capacitor.getPlatform() === 'ios',
  })
  document.documentElement.dataset[IOS_TOP_SCRIM_DATA_KEY] = active ? 'true' : 'false'
  return active
}
