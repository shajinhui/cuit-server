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
const previewOpen = ref(false)
let requestVersion = 0
let releaseSource: () => void = () => undefined

watch(
  () => props.asset?.id,
  async (assetID) => {
    const version = ++requestVersion
    releaseSource()
    releaseSource = () => undefined
    source.value = ''
    failed.value = false
    previewOpen.value = false
    if (!assetID) return
    try {
      const cachedSource = await loadRatingAsset(assetID)
      if (version !== requestVersion) {
        cachedSource.release()
        return
      }
      source.value = cachedSource.source
      releaseSource = cachedSource.release
    } catch {
      if (version === requestVersion) failed.value = true
    }
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  requestVersion += 1
  releaseSource()
})

function openPreview(event: Event) {
  if (!source.value) return
  event.preventDefault()
  event.stopPropagation()
  previewOpen.value = true
}

function closePreview() {
  previewOpen.value = false
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    openPreview(event)
  } else if (event.key === 'Escape') {
    closePreview()
  }
}
</script>

<template>
  <span
    class="rating-image"
    :class="{ 'is-empty': !source, 'is-clickable': Boolean(source) }"
    :role="source ? 'button' : undefined"
    :tabindex="source ? 0 : undefined"
    :aria-label="source ? `${alt || '图片'}，点击查看大图` : undefined"
    @click="openPreview"
    @keydown="handleKeydown"
  >
    <img v-if="source" :src="source" :alt="alt" />
    <svg v-else aria-hidden="true" viewBox="0 0 32 32">
      <path d="M7 24.5 13.2 18l4.2 4.2 2.7-3 4.9 5.3" />
      <circle cx="21" cy="11" r="2.2" />
      <rect x="4.5" y="5" width="23" height="22" rx="5" />
    </svg>
    <span v-if="failed" class="sr-only">图片加载失败</span>
  </span>
  <Teleport to="body">
    <Transition name="rating-image-preview">
      <div v-if="previewOpen" class="rating-image-preview-backdrop" role="presentation" @click.self="closePreview">
        <button type="button" class="rating-image-preview-close" aria-label="关闭大图" @click="closePreview">×</button>
        <img class="rating-image-preview" :src="source" :alt="alt" @click.stop />
      </div>
    </Transition>
  </Teleport>
</template>
