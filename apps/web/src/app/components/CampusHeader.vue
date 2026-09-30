<script setup lang="ts">
import { useRoute } from 'vue-router'
import { listingTypeFromQuery } from '@/features/marketplace'
import GlassSegmented from '@/shared/ui/GlassSegmented.vue'
import GlassIconButton from '@/shared/ui/GlassIconButton.vue'

defineProps<{ active: 'ratings' | 'marketplace' }>()
const route = useRoute()
</script>

<template>
  <header class="campus-header">
    <h1>校园</h1>
    <GlassSegmented
      class="campus-tabs"
      :model-value="active"
      :options="[{ value: 'ratings', label: '评分', to: { name: 'ratings' } }, { value: 'marketplace', label: '二手', to: { name: 'marketplace' } }] as const"
      aria-label="校园栏目"
      material="navigation"
      :corner-radius="18"
      :thumb-radius="15"
    />
    <GlassIconButton
      class="ratings-icon-button"
      :to="active === 'ratings' ? { name: 'ratings-mine' } : { name: 'marketplace-mine', query: { type: listingTypeFromQuery(route.query.type) } }"
      :aria-label="active === 'ratings' ? '我的评分内容' : '我的二手发布'"
    >
      <svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="12" cy="8" r="3.2" /><path d="M5.5 20c.6-4.1 2.8-6.2 6.5-6.2s5.9 2.1 6.5 6.2" /></svg>
    </GlassIconButton>
  </header>
</template>
