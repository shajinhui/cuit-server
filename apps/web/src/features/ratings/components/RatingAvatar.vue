<script setup lang="ts">
import { computed } from 'vue'

import type { RatingAuthor } from '../model'

defineOptions({ name: 'RatingAvatar' })

const props = defineProps<{ author: RatingAuthor }>()
const palette = ['#5b8def', '#e88065', '#8d74d6', '#45a59a', '#d59a3f', '#db6d9c']
const background = computed(() => palette[Math.abs(props.author.avatar_preset) % palette.length])
const label = computed(() => Array.from(props.author.display_name.trim()).at(0) || '友')
</script>

<template>
  <span class="rating-avatar" :style="{ backgroundColor: background }" aria-hidden="true">
    {{ label }}
  </span>
</template>
