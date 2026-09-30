<script setup lang="ts">
import GlassIconButton from '@/shared/ui/GlassIconButton.vue'

defineOptions({ name: 'RatingPageHeader' })

withDefaults(
  defineProps<{
    title: string
    subtitle?: string
    backLabel?: string
  }>(),
  { subtitle: '', backLabel: '返回' },
)

const emit = defineEmits<{ back: [] }>()
</script>

<template>
  <header class="ratings-topbar">
    <GlassIconButton class="ratings-icon-button" :aria-label="backLabel" @click="emit('back')">
      <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
    </GlassIconButton>
    <div>
      <h1>{{ title }}</h1>
      <p v-if="subtitle">{{ subtitle }}</p>
    </div>
    <div class="ratings-topbar__action"><slot /></div>
  </header>
</template>
