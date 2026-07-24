<script setup lang="ts">
defineOptions({ name: 'AppShell' })

defineProps<{
  variant?: string
}>()
</script>

<template>
  <main class="app-shell" :class="variant ? `app-shell--${variant}` : undefined">
    <div class="app-shell__content">
      <slot />
    </div>
  </main>
</template>
