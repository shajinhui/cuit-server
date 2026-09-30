<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter, type RouteLocationRaw } from 'vue-router'

import profileIcon from '@/assets/icons/nav-profile-tab.png'
import ratingsIcon from '@/assets/icons/nav-ratings.png'
import scheduleIcon from '@/assets/icons/nav-schedule.png'
import toolsIcon from '@/assets/icons/nav-tools.png'
import { isRatingsConfigured } from '@/features/ratings'
import GlassSurface from '@/shared/ui/GlassSurface.vue'
import { useCapsuleGesture } from '@/shared/ui/useCapsuleGesture'

defineOptions({ name: 'BottomNavigation' })

const route = useRoute()
const router = useRouter()
const defaultItems = [
  { name: 'schedule', label: '课表', icon: scheduleIcon, to: { name: 'schedule' } },
  { name: 'tools', label: '工具', icon: toolsIcon, to: { name: 'tools' } },
  ...(isRatingsConfigured()
    ? [{ name: 'ratings', label: '校园', icon: ratingsIcon, to: { name: 'ratings' } }]
    : []),
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
const resolvedActiveName = computed(() => props.activeName ?? (route.path.startsWith('/marketplace') ? 'ratings' : String(route.name ?? '')))
const activeIndex = computed(() => {
  const index = resolvedItems.value.findIndex((item) => item.name === resolvedActiveName.value)
  return index < 0 ? 0 : index
})

const navigationRef = ref<HTMLElement | null>(null)
const contentRef = ref<HTMLElement | null>(null)
const selectionRef = ref<HTMLElement | null>(null)
const {
  position: selectionPosition, isPressed, isLifted, isDragging,
  handlePointerDown, handlePointerMove, handlePointerUp,
  handlePointerCancel, handleLostPointerCapture, handlePointerLeave, handleClick,
} = useCapsuleGesture({
  activeIndex,
  itemCount: () => resolvedItems.value.length,
  navigation: navigationRef,
  content: contentRef,
  selection: selectionRef,
  select: selectItem,
})

const selectionStyle = computed(() => ({
  '--selection-position': selectionPosition.value,
  // 放大以胶囊自身中心为基准，上下保持对称；不再额外向上偏移。
  '--selection-lift': '0px',
  // 胶囊比导航栏矮 10px（上下各留 5px），1.18 基本填满但不会越界。
  '--selection-scale': isLifted.value ? '1.18' : isPressed.value ? '1.02' : '1',
}))

function selectItem(index: number) {
  const item = resolvedItems.value[index]
  if (!item) return

  if (item.to) {
    void router.push(item.to)
  } else {
    emit('select', item.name)
  }
}

</script>

<template>
  <div
    class="bottom-navigation"
    :class="{
      'bottom-navigation--inline': inline,
      'bottom-navigation--compact': compact,
      'is-lifted': isLifted,
    }"
    ref="navigationRef"
  >
    <!--
      GlassSurface 统一库的折射、高光和兼容处理；导航只负责布局与手势。
      原始链接位于独立交互层，装饰材质不拦截点击，也不裁剪拖动中的内容。
    -->
    <GlassSurface class="bottom-navigation__glass" preset="navigation" :corner-radius="32" :style="{ '--glass-clip-radius': 'var(--bottom-navigation-outer-radius)' }" />

    <nav
      class="bottom-navigation__content"
      ref="contentRef"
      :style="{ '--navigation-item-count': resolvedItems.length }"
      :aria-label="ariaLabel"
      @pointerdown="handlePointerDown"
      @pointermove="handlePointerMove"
      @pointerup="handlePointerUp"
      @pointercancel="handlePointerCancel"
      @lostpointercapture="handleLostPointerCapture"
      @pointerleave="handlePointerLeave"
      @click.capture="handleClick"
      @dragstart.prevent
    >
      <span
        ref="selectionRef"
        class="bottom-navigation__selection"
        :class="{
          'is-pressed': isPressed,
          'is-lifted': isLifted,
          'is-dragging': isDragging,
        }"
        :style="selectionStyle"
        aria-hidden="true"
      >
        <GlassSurface preset="selection" :corner-radius="26" :style="{ '--glass-clip-radius': 'var(--bottom-navigation-inner-radius)' }" />
      </span>
      <template v-for="(item, index) in resolvedItems" :key="item.name">
        <RouterLink
          v-if="item.to"
          :to="item.to"
          class="bottom-navigation__item"
          :data-navigation-index="index"
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
          :data-navigation-index="index"
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
  </div>
</template>
