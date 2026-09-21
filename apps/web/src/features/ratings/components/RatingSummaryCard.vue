<script setup lang="ts">
import { ratingCountLabel, ratingPercentage, scoreLabel, type RatingSummary } from '../model'

defineOptions({ name: 'RatingSummaryCard' })

defineProps<{ summary: RatingSummary }>()
</script>

<template>
  <section class="rating-summary-card" aria-label="评分概览">
    <div class="rating-summary-card__score">
      <strong>{{ scoreLabel(summary.score) }}</strong>
      <span v-if="summary.score !== null">/ 10</span>
      <small>{{ ratingCountLabel(summary.count) }}</small>
      <em v-if="summary.count > 0 && summary.count < 5">样本较少</em>
    </div>
    <div class="rating-distribution">
      <div v-for="star in [5, 4, 3, 2, 1]" :key="star" class="rating-distribution__row">
        <span>{{ star }} 星</span>
        <i>
          <b :style="{ width: `${ratingPercentage(summary.distribution[String(star) as '1' | '2' | '3' | '4' | '5'], summary.count)}%` }" />
        </i>
        <small>{{ ratingPercentage(summary.distribution[String(star) as '1' | '2' | '3' | '4' | '5'], summary.count) }}%</small>
      </div>
    </div>
  </section>
</template>
