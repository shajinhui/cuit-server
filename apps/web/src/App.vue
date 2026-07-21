<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import BottomNavigation from '@/components/BottomNavigation.vue'

const route = useRoute()
const navigationRoutes = new Set(['schedule', 'tools', 'profile'])
const showBottomNavigation = computed(() => navigationRoutes.has(String(route.name)))
</script>

<template>
  <RouterView />
  <BottomNavigation v-if="showBottomNavigation" />
</template>
