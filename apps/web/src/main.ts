import { Capacitor } from '@capacitor/core'
import { createPinia } from 'pinia'
import { createApp } from 'vue'
import { registerSW } from 'virtual:pwa-register'

import App from './app/App.vue'
import { registerNativeRuntime } from './app/nativeRuntime'
import router from './app/router'
import { registerSessionLifecycle } from './app/sessionLifecycle'
import { registerPwaInstall } from './features/pwa-install'
import './styles/main.css'

registerPwaInstall()
registerNativeRuntime()
if (!Capacitor.isNativePlatform()) {
  registerSW({ immediate: true })
}

const pinia = createPinia()
const app = createApp(App)

app.use(pinia)
registerSessionLifecycle(pinia)

app.use(router).mount('#app')
