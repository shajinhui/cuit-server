import { Capacitor } from '@capacitor/core'
import { createPinia } from 'pinia'
import { createApp } from 'vue'
import { registerSW } from 'virtual:pwa-register'

import App from './app/App.vue'
import { registerNativeRuntime } from './app/nativeRuntime'
import router from './app/router'
import { registerSessionLifecycle } from './app/sessionLifecycle'
import { registerAndroidLiveUpdates } from './features/app-updates'
import { registerPwaInstall } from './features/pwa-install'
import { applyIosTopScrim } from './shared/device/iosTopScrim'
import './styles/main.css'

document.documentElement.dataset.platform = Capacitor.getPlatform()
applyIosTopScrim()

registerPwaInstall()
registerNativeRuntime()
if (!Capacitor.isNativePlatform() && (import.meta.env.PROD || import.meta.env.VITE_PWA_DEV === 'true')) {
  registerSW({ immediate: true })
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
