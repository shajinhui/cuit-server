<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import { PwaInstallPrompt } from '@/features/pwa-install'

import BottomNavigation from './components/BottomNavigation.vue'

defineOptions({ name: 'AppRoot' })

const route = useRoute()
const navigationRoutes = new Set(['schedule', 'tools', 'profile'])
const showBottomNavigation = computed(() => navigationRoutes.has(String(route.name)))
</script>

<template>
  <RouterView />
  <BottomNavigation v-if="showBottomNavigation" />
  <PwaInstallPrompt
    :allow-promotion="showBottomNavigation"
    :with-bottom-navigation="showBottomNavigation"
  />
</template>
