import { computed, readonly, ref, shallowRef } from 'vue'

import { isInstalledDisplay, resolveInstallGuide } from './model'

interface InstallChoice {
  outcome: 'accepted' | 'dismissed'
  platform: string
}

interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[]
  readonly userChoice: Promise<InstallChoice>
  prompt(): Promise<void>
}

export type InstallRequestResult = 'accepted' | 'dismissed' | 'installed' | 'manual'

const DISMISS_STORAGE_KEY = 'pwa-install-dismissed-until'
const DISMISS_DURATION_MS = 14 * 24 * 60 * 60 * 1000
const DISPLAY_MODES = ['standalone', 'fullscreen', 'minimal-ui']

const deferredPrompt = shallowRef<BeforeInstallPromptEvent | null>(null)
const installed = ref(false)
const guideVisible = ref(false)
const dismissedUntil = ref(0)
let registered = false

const canPromptInstall = computed(() => deferredPrompt.value !== null && !installed.value)
const shouldPromoteInstall = computed(
  () =>
    !installed.value &&
    dismissedUntil.value <= Date.now() &&
    (canPromptInstall.value || installGuide.value.kind === 'ios'),
)
const installGuide = computed(() =>
  resolveInstallGuide(typeof navigator === 'undefined' ? '' : navigator.userAgent),
)

export function registerPwaInstall() {
  if (registered || typeof window === 'undefined') return
  registered = true

  installed.value = readInstalledDisplay()
  dismissedUntil.value = readDismissedUntil()

  window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
  window.addEventListener('appinstalled', handleAppInstalled)

  const standaloneQuery = window.matchMedia('(display-mode: standalone)')
  if (typeof standaloneQuery.addEventListener === 'function') {
    standaloneQuery.addEventListener('change', handleDisplayModeChange)
  } else {
    standaloneQuery.addListener(handleDisplayModeChange)
  }
}

export function usePwaInstall() {
  return {
    canPromptInstall: readonly(canPromptInstall),
    guideVisible: readonly(guideVisible),
    installGuide: readonly(installGuide),
    isInstalled: readonly(installed),
    shouldPromoteInstall: readonly(shouldPromoteInstall),
    closeInstallGuide,
    dismissInstallPromotion,
    openInstallGuide,
    requestInstall,
  }
}

async function requestInstall(): Promise<InstallRequestResult> {
  if (installed.value) return 'installed'

  const promptEvent = deferredPrompt.value
  if (!promptEvent) {
    openInstallGuide()
    return 'manual'
  }

  try {
    await promptEvent.prompt()
    const choice = await promptEvent.userChoice
    deferredPrompt.value = null

    if (choice.outcome === 'accepted') {
      installed.value = true
      guideVisible.value = false
      clearDismissedUntil()
      return 'accepted'
    }

    dismissInstallPromotion()
    return 'dismissed'
  } catch {
    deferredPrompt.value = null
    openInstallGuide()
    return 'manual'
  }
}

function handleBeforeInstallPrompt(event: Event) {
  event.preventDefault()
  if (installed.value) return
  deferredPrompt.value = event as BeforeInstallPromptEvent
}

function handleAppInstalled() {
  installed.value = true
  deferredPrompt.value = null
  guideVisible.value = false
  clearDismissedUntil()
}

function handleDisplayModeChange(event: MediaQueryListEvent) {
  if (!event.matches) return
  installed.value = true
  deferredPrompt.value = null
  guideVisible.value = false
}

function dismissInstallPromotion() {
  const until = Date.now() + DISMISS_DURATION_MS
  dismissedUntil.value = until
  try {
    window.localStorage.setItem(DISMISS_STORAGE_KEY, String(until))
  } catch {
    // 隐私模式或存储受限时仅在当前页面隐藏。
  }
}

function openInstallGuide() {
  if (installed.value) return
  guideVisible.value = true
}

function closeInstallGuide() {
  guideVisible.value = false
}

function readInstalledDisplay(): boolean {
  const displayModes = DISPLAY_MODES.filter((mode) =>
    window.matchMedia(`(display-mode: ${mode})`).matches,
  )
  const navigatorWithStandalone = window.navigator as Navigator & { standalone?: boolean }

  return isInstalledDisplay({
    displayModes,
    referrer: document.referrer,
    standalone: navigatorWithStandalone.standalone,
  })
}

function readDismissedUntil(): number {
  try {
    const value = Number(window.localStorage.getItem(DISMISS_STORAGE_KEY))
    return Number.isFinite(value) ? value : 0
  } catch {
    return 0
  }
}

function clearDismissedUntil() {
  dismissedUntil.value = 0
  try {
    window.localStorage.removeItem(DISMISS_STORAGE_KEY)
  } catch {
    // 存储不可用不影响安装完成状态。
  }
}
