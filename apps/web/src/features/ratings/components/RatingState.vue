<script setup lang="ts">
defineOptions({ name: 'RatingState' })

withDefaults(
  defineProps<{
    title: string
    description?: string
    loading?: boolean
    actionLabel?: string
  }>(),
  { description: '', loading: false, actionLabel: '' },
)

const emit = defineEmits<{ action: [] }>()
</script>

<template>
  <div class="ratings-state" :aria-busy="loading || undefined" :role="loading ? 'status' : undefined">
    <span v-if="loading" class="ratings-spinner" aria-hidden="true" />
    <svg v-else aria-hidden="true" viewBox="0 0 24 24">
      <path d="M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17Z" />
      <path d="M8.5 13.5c.8 1.2 2 1.8 3.5 1.8s2.7-.6 3.5-1.8M9 9.5h.01M15 9.5h.01" />
    </svg>
    <strong>{{ title }}</strong>
    <p v-if="description">{{ description }}</p>
    <button v-if="actionLabel" type="button" @click="emit('action')">{{ actionLabel }}</button>
  </div>
</template>

