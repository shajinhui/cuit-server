import { createPinia } from 'pinia'
import { createApp } from 'vue'
import { registerSW } from 'virtual:pwa-register'

import App from './App.vue'
import router from './router'
import './styles/main.css'

registerSW({ immediate: true })

createApp(App).use(createPinia()).use(router).mount('#app')
