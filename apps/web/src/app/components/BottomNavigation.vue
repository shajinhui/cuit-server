<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import profileIcon from '@/assets/icons/nav-profile-tab.png'
import scheduleIcon from '@/assets/icons/nav-schedule.png'
import toolsIcon from '@/assets/icons/nav-tools.png'

defineOptions({ name: 'BottomNavigation' })

const homeIcon =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Cpath d='m3.5 11 8.5-7 8.5 7v9H14v-6h-4v6H3.5z' fill='none' stroke='%23000' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E"

const route = useRoute()
const items = [
  { name: 'home', label: '首页', icon: homeIcon },
  { name: 'schedule', label: '课表', icon: scheduleIcon },
  { name: 'tools', label: '工具', icon: toolsIcon },
  { name: 'profile', label: '我的', icon: profileIcon },
] as const

const activeName = computed(() => route.name)
const activeIndex = computed(() => {
  const index = items.findIndex((item) => item.name === activeName.value)
  return index < 0 ? 0 : index
})
</script>

<template>
  <nav
    class="bottom-navigation"
    aria-label="主导航"
    :style="{ '--nav-count': items.length }"
  >
    <span
      class="bottom-navigation__selection"
      :style="{ '--active-index': activeIndex }"
      aria-hidden="true"
    />
    <RouterLink
      v-for="item in items"
      :key="item.name"
      :to="{ name: item.name }"
      class="bottom-navigation__item"
      :class="{ 'is-active': activeName === item.name }"
    >
      <span
        class="bottom-navigation__icon"
        :style="{ '--nav-icon': `url(${item.icon})` }"
        aria-hidden="true"
      />
      <span>{{ item.label }}</span>
    </RouterLink>
  </nav>
</template>
