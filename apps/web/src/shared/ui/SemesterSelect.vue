<script setup lang="ts">
import { computed } from 'vue'
import type { Semester } from '@/shared/models/academic'
import GlassSelect from './GlassSelect.vue'
import { semesterSelectOptions, type SelectSize, type SelectVariant } from './glassSelect'

const props = withDefaults(defineProps<{
  modelValue: string
  semesters: readonly Semester[]
  title?: string
  ariaLabel?: string
  disabled?: boolean
  variant?: SelectVariant
  size?: SelectSize
  embedded?: boolean
}>(), {
  title: '选择学期', ariaLabel: '选择学期', disabled: false, variant: 'field', size: 'md', embedded: false,
})
const emit = defineEmits<{ 'update:modelValue': [value: string]; change: [value: string] }>()
const options = computed(() => semesterSelectOptions(props.semesters))
</script>

<template>
  <GlassSelect
    :model-value="modelValue"
    :options="options"
    :title="title"
    :aria-label="ariaLabel"
    :disabled="disabled"
    :variant="variant"
    :size="size"
    :embedded="embedded"
    placeholder="暂无可用学期"
    @update:model-value="emit('update:modelValue', $event)"
    @change="emit('change', $event)"
  />
</template>
