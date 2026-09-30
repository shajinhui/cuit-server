<script setup lang="ts">
import { ref } from 'vue'

import GlassSurface from './GlassSurface.vue'

withDefaults(defineProps<{ cornerRadius?: number }>(), { cornerRadius: 18 })
const element = ref<HTMLDivElement | null>(null)
defineExpose({ element })
</script>

<template>
  <!-- Positioning, dismissal and menu/listbox semantics remain with the caller. -->
  <div ref="element" class="glass-popover" :style="{ borderRadius: `${cornerRadius}px` }">
    <GlassSurface preset="popover" :corner-radius="cornerRadius" />
    <slot />
  </div>
</template>
