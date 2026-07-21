<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import profileIcon from '@/assets/icons/nav-profile.png'
import scheduleIcon from '@/assets/icons/nav-schedule.png'
import toolsIcon from '@/assets/icons/nav-tools.png'

const route = useRoute()
const items = [
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
  <nav class="bottom-navigation" aria-label="主导航">
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
      <img :src="item.icon" alt="" />
      <span>{{ item.label }}</span>
    </RouterLink>
  </nav>
</template>
