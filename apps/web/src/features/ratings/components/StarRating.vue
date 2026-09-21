<script setup lang="ts">
defineOptions({ name: 'StarRating' })

withDefaults(
  defineProps<{
    modelValue: number
    disabled?: boolean
    compact?: boolean
  }>(),
  { disabled: false, compact: false },
)

const emit = defineEmits<{ 'update:modelValue': [value: number] }>()
</script>

<template>
  <div class="star-rating" :class="{ 'is-compact': compact }" role="radiogroup" aria-label="选择评分">
    <button
      v-for="star in 5"
      :key="star"
      type="button"
      role="radio"
      :aria-checked="modelValue === star"
      :aria-label="`${star} 星，${star * 2} 分`"
      :disabled="disabled"
      :class="{ 'is-active': star <= modelValue }"
      @click="emit('update:modelValue', star)"
    >
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="m12 2.8 2.8 5.7 6.3.9-4.6 4.4 1.1 6.3-5.6-3-5.6 3 1.1-6.3-4.6-4.4 6.3-.9L12 2.8Z" />
      </svg>
    </button>
  </div>
</template>

