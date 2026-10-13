import { Capacitor } from '@capacitor/core'
import { createPinia } from 'pinia'
import { createApp } from 'vue'
import { registerSW } from 'virtual:pwa-register'

import App from './app/App.vue'
import { registerNativeRuntime } from './app/nativeRuntime'
import { isOfficialPagePath } from './app/pwaPolicy'
import router from './app/router'
import { registerSessionLifecycle } from './app/sessionLifecycle'
import { registerAndroidLiveUpdates } from './features/app-updates'
import { registerPwaInstall } from './features/pwa-install'
import { applyIosTopScrim } from './shared/device/iosTopScrim'
import { registerColorSchemeRuntime } from './shared/theme/useColorScheme'
import './styles/main.css'

document.documentElement.dataset.platform = Capacitor.getPlatform()
applyIosTopScrim()

// 主题状态在应用根上初始化一次：负责兜底同步 data-theme 并监听系统配色变化。
// 首帧之前的状态由 index.html 的内联脚本写入，避免闪白。
registerColorSchemeRuntime()

registerPwaInstall()
registerNativeRuntime()
if (!Capacitor.isNativePlatform() && (import.meta.env.PROD || import.meta.env.VITE_PWA_DEV === 'true')) {
  if (isOfficialPagePath(window.location.pathname)) {
    // 官网不新建 PWA 缓存；旧用户仍检查已有 Worker 更新，让新缓存边界生效。
    if ('serviceWorker' in navigator) {
      void navigator.serviceWorker.getRegistration()
        .then((registration) => registration?.update())
        .catch(() => undefined)
    }
  } else {
    registerSW({ immediate: true })
  }
} else if (!Capacitor.isNativePlatform() && import.meta.env.DEV && 'serviceWorker' in navigator) {
  // A development service worker can reload the app while Vite is starting and make every
  // protected route appear to load twice. Clear registrations left by earlier dev sessions;
  // production PWA behavior is unchanged and can still be tested with VITE_PWA_DEV=true.
  void navigator.serviceWorker
    .getRegistrations()
    .then((registrations) => Promise.all(registrations.map((registration) => registration.unregister())))
    .catch(() => undefined)
}

const pinia = createPinia()
const app = createApp(App)

app.use(pinia)
registerSessionLifecycle(pinia)

app.use(router).mount('#app')
registerAndroidLiveUpdates()
