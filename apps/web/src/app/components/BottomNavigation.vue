<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, type RouteLocationRaw } from 'vue-router'

import profileIcon from '@/assets/icons/nav-profile-tab.png'
import scheduleIcon from '@/assets/icons/nav-schedule.png'
import toolsIcon from '@/assets/icons/nav-tools.png'

defineOptions({ name: 'BottomNavigation' })

const route = useRoute()
const defaultItems = [
  { name: 'schedule', label: '课表', icon: scheduleIcon, to: { name: 'schedule' } },
  { name: 'tools', label: '工具', icon: toolsIcon, to: { name: 'tools' } },
  { name: 'profile', label: '我的', icon: profileIcon, to: { name: 'profile' } },
] as const

interface NavigationItem {
  name: string
  label: string
  icon: string
  iconClass?: string
  to?: RouteLocationRaw
}

const props = withDefaults(
  defineProps<{
    items?: readonly NavigationItem[]
    activeName?: string
    ariaLabel?: string
    inline?: boolean
    compact?: boolean
  }>(),
  {
    ariaLabel: '主导航',
    inline: false,
    compact: false,
  },
)

const emit = defineEmits<{
  select: [name: string]
}>()

const resolvedItems = computed<readonly NavigationItem[]>(() => props.items ?? defaultItems)
const resolvedActiveName = computed(() => props.activeName ?? String(route.name ?? ''))
const activeIndex = computed(() => {
  const index = resolvedItems.value.findIndex((item) => item.name === resolvedActiveName.value)
  return index < 0 ? 0 : index
})
</script>

<template>
  <nav
    class="bottom-navigation"
    :class="{
      'bottom-navigation--inline': inline,
      'bottom-navigation--compact': compact,
    }"
    :aria-label="ariaLabel"
  >
    <span
      class="bottom-navigation__selection"
      :style="{ '--active-index': activeIndex }"
      aria-hidden="true"
    />
    <template v-for="item in resolvedItems" :key="item.name">
      <RouterLink
        v-if="item.to"
        :to="item.to"
        class="bottom-navigation__item"
        :class="{ 'is-active': resolvedActiveName === item.name }"
      >
        <span
          class="bottom-navigation__icon"
          :class="`bottom-navigation__icon--${item.iconClass ?? item.name}`"
          :style="{ '--nav-icon': `url(${item.icon})` }"
          aria-hidden="true"
        />
        <span>{{ item.label }}</span>
      </RouterLink>
      <button
        v-else
        type="button"
        class="bottom-navigation__item"
        :class="{ 'is-active': resolvedActiveName === item.name }"
        :aria-current="resolvedActiveName === item.name ? 'page' : undefined"
        @click="emit('select', item.name)"
      >
        <span
          class="bottom-navigation__icon"
          :class="`bottom-navigation__icon--${item.iconClass ?? item.name}`"
          :style="{ '--nav-icon': `url(${item.icon})` }"
          aria-hidden="true"
        />
        <span>{{ item.label }}</span>
      </button>
    </template>
  </nav>
</template>
