<script setup lang="ts">
import { computed } from 'vue'
import { GlassMode, LiquidGlass } from '@wxperia/liquid-glass-vue'

import { glassMaterials, type GlassMaterial } from './glassMaterial'

const props = withDefaults(defineProps<{
  preset?: GlassMaterial
  cornerRadius?: number
}>(), { preset: 'toolbar', cornerRadius: 24 })

const material = computed(() => glassMaterials[props.preset])
const materialStyle = computed(() => ({
  '--glass-clip-radius': `${props.cornerRadius}px`,
  '--glass-fallback-blur': `${material.value.fallbackBlur}px`,
  '--glass-saturation': `${material.value.saturation}%`,
  '--glass-fill': material.value.fill,
}))
</script>

<template>
  <!-- A decorative library surface, never the hit target or a backdrop root around content. -->
  <span class="glass-surface" aria-hidden="true" :data-glass-material="preset" :style="materialStyle">
    <LiquidGlass
      :mode="GlassMode.standard"
      :displacement-scale="material.displacementScale"
      :blur-amount="material.blurAmount"
      :saturation="material.saturation"
      :aberration-intensity="material.aberrationIntensity"
      :elasticity="0"
      :corner-radius="cornerRadius"
      padding="0"
      :style="{ position: 'absolute', top: '50%', left: '50%', width: '100%', height: '100%' }"
    >
      <span class="glass-surface__fill" />
    </LiquidGlass>
  </span>
</template>
