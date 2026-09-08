import { Capacitor } from '@capacitor/core'
import { Device } from '@capacitor/device'

export type ClientPlatform = 'android' | 'ios'

export interface ClientDevice {
  platform: ClientPlatform
  brand: string
}

interface NavigatorHints {
  platform?: string
  maxTouchPoints?: number
}

const androidBrands: ReadonlyArray<[string, RegExp]> = [
  ['Samsung', /Samsung|SM-|GT-|SCH-|SGH-/i],
  ['Huawei', /HUAWEI|HarmonyOS|\b(?:ANE|ELE|LYA|VOG|JNY|NOH|ELS|LIO|MAR|STK|TAS|YAL)-/i],
  ['Honor', /HONOR/i],
  ['iQOO', /iQOO/i],
  ['Redmi', /Redmi/i],
  ['POCO', /POCO/i],
  ['Xiaomi', /Xiaomi|\bMI\s/i],
  ['OnePlus', /OnePlus/i],
  ['OPPO', /OPPO|\bCPH\d+/i],
  ['vivo', /vivo|\bV\d{4}[A-Z]?(?:\s|\)|;)/i],
  ['realme', /realme|\bRMX\d+/i],
  ['Google', /Pixel/i],
  ['Motorola', /Motorola|\bmoto\s/i],
  ['Meizu', /Meizu|\bM\d{3}[A-Z]?\b/i],
  ['Nothing', /Nothing Phone|\bA0\d{3}\b/i],
  ['ASUS', /ASUS|ROG Phone|ZenFone/i],
  ['Lenovo', /Lenovo/i],
  ['ZTE', /ZTE/i],
  ['Nubia', /Nubia|NX\d{3}/i],
]

let devicePromise: Promise<ClientDevice | undefined> | undefined

export function normalizeAndroidBrand(value: string): string {
  return androidBrands.find(([, pattern]) => pattern.test(value))?.[0] ?? 'Other'
}

export function detectClientDevice(
  userAgent: string,
  hints: NavigatorHints = {},
): ClientDevice | undefined {
  const isiPad = /iPad/i.test(userAgent) || (
    hints.platform === 'MacIntel' && (hints.maxTouchPoints ?? 0) > 1
  )
  if (/iPhone|iPod/i.test(userAgent) || isiPad) {
    return { platform: 'ios', brand: 'Apple' }
  }
  if (!/Android/i.test(userAgent)) return undefined

  return {
    platform: 'android',
    brand: normalizeAndroidBrand(userAgent),
  }
}

async function resolveClientDevice(): Promise<ClientDevice | undefined> {
  if (typeof window === 'undefined') return undefined
  const fallback = detectClientDevice(window.navigator.userAgent, {
    platform: window.navigator.platform,
    maxTouchPoints: window.navigator.maxTouchPoints,
  })
  if (!Capacitor.isNativePlatform()) return fallback

  try {
    const info = await Device.getInfo()
    if (info.operatingSystem === 'ios') return { platform: 'ios', brand: 'Apple' }
    if (info.operatingSystem === 'android') {
      return {
        platform: 'android',
        brand: normalizeAndroidBrand(`${info.manufacturer} ${info.model}`),
      }
    }
  } catch {
    return fallback
  }
  return fallback
}

export async function clientDeviceHeaders(): Promise<Record<string, string>> {
  devicePromise ??= resolveClientDevice()
  const device = await devicePromise
  if (!device) return {}
  return {
    'X-Client-Platform': device.platform,
    'X-Client-Brand': device.brand,
  }
}
