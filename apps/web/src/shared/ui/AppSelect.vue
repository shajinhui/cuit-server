<script setup lang="ts" generic="T extends SelectValue = SelectValue">
import GlassSelect from './GlassSelect.vue'
import type { GlassSelectProps, SelectValue } from './glassSelect'

// Compatibility name only; material, layout and interaction live in GlassSelect.
const props = defineProps<GlassSelectProps<T>>()
const emit = defineEmits<{ 'update:modelValue': [value: T]; change: [value: T] }>()
</script>

<template>
  <GlassSelect v-bind="props" @update:model-value="emit('update:modelValue', $event)" @change="emit('change', $event)" />
</template>
