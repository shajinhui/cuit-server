<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'

import { loadRatingAsset } from '../api'
import type { RatingAssetRef } from '../model'

defineOptions({ name: 'RatingImage' })

const props = withDefaults(
  defineProps<{
    asset: RatingAssetRef | null
    alt?: string
  }>(),
  { alt: '' },
)

const source = ref('')
const failed = ref(false)
let requestVersion = 0

watch(
  () => props.asset?.id,
  async (assetID) => {
    const version = ++requestVersion
    source.value = ''
    failed.value = false
    if (!assetID) return
    try {
      const cachedSource = await loadRatingAsset(assetID)
      if (version !== requestVersion) return
      source.value = cachedSource
    } catch {
      if (version === requestVersion) failed.value = true
    }
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  requestVersion += 1
})
</script>

<template>
  <span class="rating-image" :class="{ 'is-empty': !source }">
    <img v-if="source" :src="source" :alt="alt" />
    <svg v-else aria-hidden="true" viewBox="0 0 32 32">
      <path d="M7 24.5 13.2 18l4.2 4.2 2.7-3 4.9 5.3" />
      <circle cx="21" cy="11" r="2.2" />
      <rect x="4.5" y="5" width="23" height="22" rx="5" />
    </svg>
    <span v-if="failed" class="sr-only">图片加载失败</span>
  </span>
</template>
