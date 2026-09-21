<script setup lang="ts">
import type { RatingBoard } from '../model'
import RatingAvatar from './RatingAvatar.vue'
import RatingImage from './RatingImage.vue'

defineOptions({ name: 'RatingBoardCard' })

defineProps<{ board: RatingBoard }>()
</script>

<template>
  <RouterLink class="rating-board-card" :to="{ name: 'rating-board', params: { boardId: board.id } }">
    <RatingImage :asset="board.cover_asset" :alt="board.title" />
    <span class="rating-board-card__body">
      <strong>{{ board.title }}</strong>
      <span>{{ board.description || '这个评分板块还没有介绍' }}</span>
      <small>
        <RatingAvatar :author="board.creator" />
        {{ board.creator.display_name }}
      </small>
    </span>
    <span class="rating-board-card__meta">
      <b>{{ board.item_count }}</b>
      <small>个对象</small>
      <em>{{ board.rating_count }} 人次</em>
    </span>
  </RouterLink>
</template>
