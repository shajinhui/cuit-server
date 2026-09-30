<script setup lang="ts">
import GlassSurface from './GlassSurface.vue'

withDefaults(defineProps<{
  as?: 'div' | 'form' | 'nav'
  cornerRadius?: number
}>(), { as: 'div', cornerRadius: 24 })
</script>

<template>
  <component :is="as" class="glass-toolbar" :style="{ borderRadius: `${cornerRadius}px` }">
    <GlassSurface preset="toolbar" :corner-radius="cornerRadius" />
    <slot />
  </component>
</template>
