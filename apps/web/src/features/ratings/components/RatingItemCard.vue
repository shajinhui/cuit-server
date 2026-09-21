<script setup lang="ts">
import { scoreLabel, type RatingItem } from '../model'
import RatingImage from './RatingImage.vue'

defineOptions({ name: 'RatingItemCard' })

defineProps<{ item: RatingItem }>()
</script>

<template>
  <RouterLink class="rating-item-card" :to="{ name: 'rating-item', params: { itemId: item.id } }">
    <RatingImage :asset="item.image_asset" :alt="item.name" />
    <span class="rating-item-card__body">
      <strong>{{ item.name }}</strong>
      <span>{{ item.description || '暂无介绍' }}</span>
      <small>由 {{ item.creator.display_name }} 添加</small>
    </span>
    <span class="rating-item-card__score" :class="{ 'is-empty': item.rating.score === null }">
      <span aria-hidden="true">★</span>
      <b>{{ scoreLabel(item.rating.score) }}</b>
      <small>{{ item.rating.count }} 人</small>
    </span>
  </RouterLink>
</template>
