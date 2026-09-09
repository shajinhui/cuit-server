<script setup lang="ts">
import HamsterWheel from './HamsterWheel.vue'

withDefaults(defineProps<{ label: string; size?: number }>(), { size: 88 })

defineOptions({ name: 'HamsterLoader' })
</script>

<template>
  <div class="hamster-loader" role="status" aria-live="polite">
    <HamsterWheel class="hamster-loader__wheel" :size="size" />
    <p>{{ label }}</p>
  </div>
</template>

<style scoped>
.hamster-loader {
  display: grid;
  place-items: center;
  gap: 10px;
  color: rgba(24, 31, 42, 0.72);
  text-align: center;
}

.hamster-loader__wheel {
  background: rgba(240, 244, 249, 0.88);
  border-radius: 50%;
  box-shadow:
    0 10px 26px rgba(32, 44, 61, 0.14),
    inset 0 0 0 1px rgba(255, 255, 255, 0.68);
}

p {
  margin: 0;
  font-size: 13px;
  font-weight: 650;
  line-height: 1.3;
}
</style>
