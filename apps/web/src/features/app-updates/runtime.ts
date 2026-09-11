import { App } from '@capacitor/app'
import { Capacitor, CapacitorHttp } from '@capacitor/core'
import { CapacitorUpdater } from '@capgo/capacitor-updater'
import { computed, nextTick, readonly, ref, shallowRef } from 'vue'

import { parseAndroidUpdateManifest, shouldDownloadAndroidUpdate } from './model'

const DEFAULT_MANIFEST_URLS = [
  'https://fanxiaogao05.dpdns.org/app-updates/android/latest.json',
  'https://cuit-server.pages.dev/app-updates/android/latest.json',
]
const REQUEST_TIMEOUT_MS = 10_000
const APPLY_MARKER_STORAGE_KEY = 'android-live-update-applying-v1'
const ACKNOWLEDGED_UPDATE_STORAGE_KEY = 'android-live-update-acknowledged-v1'

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

interface AppliedAndroidUpdate {
  version: string
}

interface UpdateApplyMarker {
  bundleId: string
  version: string
}

const readyUpdate = shallowRef<ReadyAndroidUpdate | null>(null)
const appliedUpdate = shallowRef<AppliedAndroidUpdate | null>(null)
const applyingUpdate = ref(false)
const applyError = ref('')
const updateDialogVisible = computed(
  () => Boolean(readyUpdate.value || appliedUpdate.value) || applyingUpdate.value,
)

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

async function prepareAndroidUpdates(): Promise<void> {
  if (!(await readyPromise)) return

  try {
    const { bundle } = await CapacitorUpdater.current()
    restoreUpdateResult(bundle.id, bundle.version)
  } catch (error) {
    console.warn('Android 热更新结果确认失败。', error)
  }

  checkForUpdate()
}

export function registerAndroidLiveUpdates(): void {
  if (registered || Capacitor.getPlatform() !== 'android') return
  registered = true

  readyPromise = confirmAppReady()
  void prepareAndroidUpdates()

  void App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) checkForUpdate()
  })
  window.addEventListener('online', checkForUpdate)
}

export function useAndroidLiveUpdate() {
  return {
    appliedUpdate: readonly(appliedUpdate),
    applyError: readonly(applyError),
    applyingUpdate: readonly(applyingUpdate),
    readyUpdate: readonly(readyUpdate),
    updateDialogVisible: readonly(updateDialogVisible),
    applyReadyUpdate,
    dismissAppliedUpdate,
    dismissReadyUpdate,
  }
}

function dismissReadyUpdate() {
  if (applyingUpdate.value || !readyUpdate.value) return
  dismissedVersion = readyUpdate.value.version
  readyUpdate.value = null
  applyError.value = ''
}

function dismissAppliedUpdate() {
  if (!appliedUpdate.value) return
  writeStorage(ACKNOWLEDGED_UPDATE_STORAGE_KEY, appliedUpdate.value.version)
  appliedUpdate.value = null
}

async function applyReadyUpdate() {
  if (applyingUpdate.value || !readyUpdate.value) return
  const update = readyUpdate.value
  applyingUpdate.value = true
  applyError.value = ''
  writeApplyMarker({ bundleId: update.bundleId, version: update.version })

  try {
    // 先让“正在应用”状态完成一次绘制，再执行会销毁当前 JS 上下文的 set()。
    await nextTick()
    await waitForPaint()
    // set() 会立即切换到这个已校验包，并销毁当前 JS 上下文完成重载。
    await CapacitorUpdater.set({ id: update.bundleId })
  } catch (error) {
    removeStorage(APPLY_MARKER_STORAGE_KEY)
    applyingUpdate.value = false
    applyError.value = '更新没有生效，请重试；如果仍然失败，请重新启动应用。'
    console.warn('Android 热更新立即应用失败，将在下次启动时继续更新。', error)
  }
}

function restoreUpdateResult(bundleId: string, version: string) {
  const marker = readApplyMarker()
  removeStorage(APPLY_MARKER_STORAGE_KEY)

  const isDownloadedBundle = bundleId !== 'builtin' && version !== 'builtin'
  const acknowledgedVersion = readStorage(ACKNOWLEDGED_UPDATE_STORAGE_KEY)
  const markerMatchesCurrentBundle =
    !marker || (marker.bundleId === bundleId && marker.version === version)
  if (isDownloadedBundle && acknowledgedVersion !== version && markerMatchesCurrentBundle) {
    appliedUpdate.value = { version }
  }

  if (marker && !markerMatchesCurrentBundle) {
    readyUpdate.value = {
      bundleId: marker.bundleId,
      version: marker.version,
      title: '更新未完成',
      releaseNotes: '上次切换新版本时应用重新启动了，但目标版本没有生效。',
    }
    applyError.value = `上次更新到 ${marker.version} 没有完成，请重新尝试。`
  }
}

function writeApplyMarker(marker: UpdateApplyMarker) {
  try {
    writeStorage(APPLY_MARKER_STORAGE_KEY, JSON.stringify(marker))
  } catch {
    // writeStorage 已经兼容存储不可用的情况，此处只保护 JSON 序列化边界。
  }
}

function readApplyMarker(): UpdateApplyMarker | null {
  const value = readStorage(APPLY_MARKER_STORAGE_KEY)
  if (!value) return null

  try {
    const marker = JSON.parse(value) as Partial<UpdateApplyMarker>
    if (typeof marker.bundleId !== 'string' || typeof marker.version !== 'string') return null
    return { bundleId: marker.bundleId, version: marker.version }
  } catch {
    return null
  }
}

function readStorage(key: string): string | null {
  try {
    return window.localStorage.getItem(key)
  } catch {
    return null
  }
}

function writeStorage(key: string, value: string) {
  try {
    window.localStorage.setItem(key, value)
  } catch {
    // WebView 禁用持久化时仍允许更新，只是无法跨重载显示完成回执。
  }
}

function removeStorage(key: string) {
  try {
    window.localStorage.removeItem(key)
  } catch {
    // 忽略不可用的 WebView 存储。
  }
}

function waitForPaint() {
  return new Promise<void>((resolve) => {
    window.requestAnimationFrame(() => window.requestAnimationFrame(() => resolve()))
  })
}
