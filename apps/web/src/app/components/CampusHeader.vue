<script setup lang="ts">
defineProps<{ active: 'ratings' | 'marketplace' }>()
</script>

<template>
  <header class="campus-header">
    <h1>校园</h1>
    <nav class="campus-tabs" aria-label="校园栏目">
      <RouterLink :to="{ name: 'ratings' }" :class="{ 'is-active': active === 'ratings' }" :aria-current="active === 'ratings' ? 'page' : undefined">评分</RouterLink>
      <RouterLink :to="{ name: 'marketplace' }" :class="{ 'is-active': active === 'marketplace' }" :aria-current="active === 'marketplace' ? 'page' : undefined">二手</RouterLink>
    </nav>
    <RouterLink
      class="ratings-icon-button"
      :to="{ name: active === 'ratings' ? 'ratings-mine' : 'marketplace-mine' }"
      :aria-label="active === 'ratings' ? '我的评分内容' : '我的二手商品'"
    >
      <svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="12" cy="8" r="3.2" /><path d="M5.5 20c.6-4.1 2.8-6.2 6.5-6.2s5.9 2.1 6.5 6.2" /></svg>
    </RouterLink>
  </header>
</template>
