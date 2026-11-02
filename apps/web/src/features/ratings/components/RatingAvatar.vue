<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { presetAvatarById } from '@/features/profile/avatar'
import { useCommunityStore } from '@/features/community/store'
import { loadRatingAsset } from '../api'

import type { RatingAuthor } from '../model'

defineOptions({ name: 'RatingAvatar' })

const props = defineProps<{ author: RatingAuthor }>()
const community = useCommunityStore()
const author = computed(() => community.profile?.id === props.author.id && community.profile.profile_version >= (props.author.profile_version ?? 1) ? community.profile : props.author)
const source = ref('')
let version = 0
let release = () => {}
watch(() => author.value.avatar_asset_id, async id => {
  const requestVersion = ++version
  release()
  release = () => {}
  source.value = ''
  if (!id) return
  try {
    const image = await loadRatingAsset(id)
    if (requestVersion !== version) { image.release(); return }
    source.value = image.source
    release = image.release
  } catch { /* Preserve the preset fallback when a custom image is unavailable. */ }
}, { immediate: true })
onBeforeUnmount(() => { version++; release() })
const imageSource = computed(() => source.value || presetAvatarById(author.value.avatar_preset)?.src || '')
const palette = ['#5b8def', '#e88065', '#8d74d6', '#45a59a', '#d59a3f', '#db6d9c']
const background = computed(() => palette[Math.abs(author.value.avatar_preset) % palette.length])
const label = computed(() => Array.from(author.value.display_name.trim()).at(0) || '友')
</script>

<template>
  <span class="rating-avatar" :style="{ backgroundColor: background }" aria-hidden="true">
    <img v-if="imageSource" :src="imageSource" alt="" @error="source = ''" />
    <template v-else>{{ label }}</template>
  </span>
</template>

<style scoped>
.rating-avatar { overflow: hidden; }
.rating-avatar img { width: 100%; height: 100%; object-fit: cover; display: block; }
</style>
