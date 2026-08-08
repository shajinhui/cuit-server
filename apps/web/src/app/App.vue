<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import { AppUpdatePrompt } from '@/features/app-updates'
import { PwaInstallPrompt } from '@/features/pwa-install'

import BottomNavigation from './components/BottomNavigation.vue'

defineOptions({ name: 'AppRoot' })

const route = useRoute()
const navigationRoutes = new Set(['home', 'schedule', 'tools', 'profile'])
const resolvingInitialRoute = computed(() => !route.name)
const showBottomNavigation = computed(() => navigationRoutes.has(String(route.name)))
</script>

<template>
  <div v-if="resolvingInitialRoute" class="app-launch-screen" role="status" aria-label="成信友友正在启动">
    <div class="app-launch-content">
      <div class="app-launch-mark" aria-hidden="true">
        <svg viewBox="0 0 32 32">
          <path class="app-launch-mark-cap" d="m3.5 12.1 12.5-6 12.5 6L16 18.2 3.5 12.1Z" />
          <path class="app-launch-mark-base" d="M8.1 15.1v5.2c2 2.2 4.7 3.3 7.9 3.3s5.9-1.1 7.9-3.3v-5.2" />
          <path class="app-launch-mark-tassel" d="M28.5 12.2v7.1" />
          <circle class="app-launch-mark-dot" cx="28.5" cy="21.5" r="1.6" />
        </svg>
      </div>
      <p class="app-launch-title">成信友友</p>
      <p class="app-launch-status">正在启动</p>
    </div>
  </div>
  <RouterView v-else />
  <BottomNavigation v-if="showBottomNavigation" />
  <PwaInstallPrompt
    :allow-promotion="showBottomNavigation"
    :with-bottom-navigation="showBottomNavigation"
  />
  <AppUpdatePrompt />
</template>
