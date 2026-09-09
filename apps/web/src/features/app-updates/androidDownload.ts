import { Capacitor } from '@capacitor/core'

export const ANDROID_APK_URL =
  'https://gitee.com/fanxiaogao05/cuit-server/releases/download/v0.2.2/app-release-signed-5.apk'
export const MIN_ANDROID_APP_VERSION = '0.2.2'
const MIN_ANDROID_APP_BUILD = 4

interface AndroidAppSupport {
  android: boolean
  native: boolean
  version?: string
  build?: string
}

export function requiresAndroidAppDownload({
  android,
  native,
  version,
  build,
}: AndroidAppSupport): boolean {
  if (!android) return false
  if (!native) return true
  if (version && compareVersion(version, MIN_ANDROID_APP_VERSION) >= 0) return false
  if (build && Number.parseInt(build, 10) >= MIN_ANDROID_APP_BUILD) return false
  return true
}

export async function shouldPromptAndroidAppDownload(): Promise<boolean> {
  if (typeof window === 'undefined') return false

  const platform = Capacitor.getPlatform()
  const android = platform === 'android' || /Android/i.test(window.navigator.userAgent)
  const native = platform === 'android' && Capacitor.isNativePlatform()
  if (!android || !native) return requiresAndroidAppDownload({ android, native })

  try {
    const { App } = await import('@capacitor/app')
    const { version, build } = await App.getInfo()
    return requiresAndroidAppDownload({ android, native, version, build })
  } catch {
    return true
  }
}

function compareVersion(left: string, right: string): number {
  const leftParts = versionParts(left)
  const rightParts = versionParts(right)
  const length = Math.max(leftParts.length, rightParts.length)

  for (let index = 0; index < length; index += 1) {
    const difference = (leftParts[index] ?? 0) - (rightParts[index] ?? 0)
    if (difference !== 0) return difference
  }
  return 0
}

function versionParts(version: string): number[] {
  return version
    .trim()
    .split('.')
    .map((part) => Number.parseInt(part, 10))
    .map((part) => (Number.isFinite(part) ? part : 0))
}
