import { App } from '@capacitor/app'
import { Capacitor, CapacitorHttp } from '@capacitor/core'
import { CapacitorUpdater } from '@capgo/capacitor-updater'
import { readonly, ref, shallowRef } from 'vue'

import { parseAndroidUpdateManifest, shouldDownloadAndroidUpdate } from './model'

const DEFAULT_MANIFEST_URLS = [
  'https://fanxiaogao05.dpdns.org/app-updates/android/latest.json',
  'https://cuit-server.pages.dev/app-updates/android/latest.json',
]
const REQUEST_TIMEOUT_MS = 10_000

let registered = false
let readyPromise: Promise<boolean> | undefined
let updateCheck: Promise<void> | undefined
let dismissedVersion: string | undefined

interface ReadyAndroidUpdate {
  bundleId: string
  version: string
  title: string
  releaseNotes: string
}

const readyUpdate = shallowRef<ReadyAndroidUpdate | null>(null)
const applyingUpdate = ref(false)

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
      if (
        manifest.nativeVersion === nativeVersion &&
        manifest.version !== currentBundle.version &&
        pendingBundle?.version === manifest.version
      ) {
        showReadyUpdate(
          pendingBundle.id,
          manifest.version,
          manifest.title,
          manifest.releaseNotes,
        )
      }
      return
    }

    const downloadedBundle = await downloadUpdate(manifest)
    await CapacitorUpdater.next({ id: downloadedBundle.id })
    showReadyUpdate(
      downloadedBundle.id,
      manifest.version,
      manifest.title,
      manifest.releaseNotes,
    )
  } catch (error) {
    console.warn('Android 热更新检查失败，继续使用当前版本。', error)
  }
}

function showReadyUpdate(
  bundleId: string,
  version: string,
  title?: string,
  releaseNotes?: string,
) {
  if (dismissedVersion === version) return
  readyUpdate.value = {
    bundleId,
    version,
    title: title?.trim() || '新版本已准备好',
    releaseNotes: releaseNotes?.trim() || '包含最新功能与体验优化。',
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

export function useAndroidLiveUpdate() {
  return {
    applyingUpdate: readonly(applyingUpdate),
    readyUpdate: readonly(readyUpdate),
    applyReadyUpdate,
    dismissReadyUpdate,
  }
}

function dismissReadyUpdate() {
  if (applyingUpdate.value || !readyUpdate.value) return
  dismissedVersion = readyUpdate.value.version
  readyUpdate.value = null
}

async function applyReadyUpdate() {
  if (applyingUpdate.value || !readyUpdate.value) return
  applyingUpdate.value = true

  try {
    // set() 会立即切换到这个已校验包，并销毁当前 JS 上下文完成重载。
    await CapacitorUpdater.set({ id: readyUpdate.value.bundleId })
  } catch (error) {
    applyingUpdate.value = false
    console.warn('Android 热更新立即应用失败，将在下次启动时继续更新。', error)
  }
}
