import { App } from '@capacitor/app'
import { Capacitor, CapacitorHttp } from '@capacitor/core'
import { CapacitorUpdater } from '@capgo/capacitor-updater'

import { parseAndroidUpdateManifest, shouldDownloadAndroidUpdate } from './model'

const DEFAULT_MANIFEST_URLS = [
  'https://fanxiaogao05.dpdns.org/app-updates/android/latest.json',
  'https://cuit-server.pages.dev/app-updates/android/latest.json',
]
const REQUEST_TIMEOUT_MS = 10_000

let registered = false
let readyPromise: Promise<boolean> | undefined
let updateCheck: Promise<void> | undefined

async function confirmAppReady(): Promise<boolean> {
  try {
    await CapacitorUpdater.notifyAppReady()
    return true
  } catch (error) {
    console.warn('Android 热更新就绪确认失败，继续使用当前内置版本。', error)
    return false
  }
}

async function fetchManifest(manifestURL: string): Promise<unknown> {
  const response = await CapacitorHttp.get({
    url: manifestURL,
    connectTimeout: REQUEST_TIMEOUT_MS,
    readTimeout: REQUEST_TIMEOUT_MS,
    responseType: 'json',
    headers: {
      Accept: 'application/json',
      'Cache-Control': 'no-cache',
    },
  })
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`HTTP ${response.status}`)
  }
  if (typeof response.data === 'string') {
    return JSON.parse(response.data)
  }
  return response.data
}

async function loadLatestManifest() {
  const configuredURL = import.meta.env.VITE_ANDROID_UPDATE_MANIFEST_URL
  const manifestURLs = configuredURL ? [configuredURL] : DEFAULT_MANIFEST_URLS
  let lastError: unknown

  for (const manifestURL of manifestURLs) {
    try {
      const manifest = parseAndroidUpdateManifest(
        await fetchManifest(manifestURL),
        manifestURL,
      )
      if (!manifest) throw new Error('更新清单格式或来源不合法')
      return manifest
    } catch (error) {
      lastError = error
    }
  }

  throw lastError || new Error('没有可用的更新清单')
}

async function downloadUpdate(
  manifest: Awaited<ReturnType<typeof loadLatestManifest>>,
) {
  const bundleURLs = [manifest.url, manifest.fallbackUrl].filter(
    (url): url is string => Boolean(url),
  )
  let lastError: unknown

  for (const url of bundleURLs) {
    try {
      return await CapacitorUpdater.download({
        url,
        version: manifest.version,
        checksum: manifest.checksum,
      })
    } catch (error) {
      lastError = error
    }
  }

  throw lastError || new Error('没有可用的更新包地址')
}

async function performUpdateCheck(): Promise<void> {
  if (!(await readyPromise)) return

  try {
    const manifest = await loadLatestManifest()

    const [{ bundle: currentBundle, native: nativeVersion }, pendingBundle] =
      await Promise.all([
        CapacitorUpdater.current(),
        CapacitorUpdater.getNextBundle(),
      ])

    if (
      !shouldDownloadAndroidUpdate(
        manifest,
        nativeVersion,
        currentBundle.version,
        pendingBundle?.version,
      )
    ) {
      return
    }

    const downloadedBundle = await downloadUpdate(manifest)
    await CapacitorUpdater.next({ id: downloadedBundle.id })
  } catch (error) {
    console.warn('Android 热更新检查失败，继续使用当前版本。', error)
  }
}

function checkForUpdate(): void {
  if (updateCheck) return

  updateCheck = performUpdateCheck().finally(() => {
    updateCheck = undefined
  })
}

export function registerAndroidLiveUpdates(): void {
  if (registered || Capacitor.getPlatform() !== 'android') return
  registered = true

  readyPromise = confirmAppReady()
  checkForUpdate()

  void App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) checkForUpdate()
  })
  window.addEventListener('online', checkForUpdate)
}
