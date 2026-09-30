<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, type RouteLocationRaw } from 'vue-router'

import GlassSurface from './GlassSurface.vue'

const props = withDefaults(defineProps<{
  to?: RouteLocationRaw
  href?: string
  disabled?: boolean
}>(), { disabled: false })
const element = computed(() => props.to ? RouterLink : props.href ? 'a' : 'button')
</script>

<template>
  <component
    :is="element"
    class="glass-icon-button"
    :to="to"
    :href="href"
    :type="!to && !href ? 'button' : undefined"
    :disabled="!to && !href ? disabled : undefined"
  >
    <GlassSurface preset="icon" :corner-radius="22" />
    <slot />
  </component>
</template>
