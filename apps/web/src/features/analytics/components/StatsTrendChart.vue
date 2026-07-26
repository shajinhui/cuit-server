<script setup lang="ts">
import { computed } from 'vue'

import { chartPoints, compactDate, type ChartSeries } from '../model'

defineOptions({ name: 'StatsTrendChart' })

const props = defineProps<{
  title: string
  description: string
  dates: string[]
  series: ChartSeries[]
}>()

const viewWidth = 680
const viewHeight = 210
const allValues = computed(() => props.series.flatMap((item) => item.values))
const maximum = computed(() => Math.max(1, ...allValues.value))
const chartSeries = computed(() =>
  props.series.map((item) => ({
    ...item,
    points: chartPoints(item.values, maximum.value, viewWidth, viewHeight),
  })),
)
const labelIndexes = computed(() => {
  const last = Math.max(0, props.dates.length - 1)
  return [...new Set([0, Math.floor(last / 2), last])]
})
</script>

<template>
  <article class="admin-chart-card">
    <header class="admin-card-heading">
      <div>
        <h2>{{ title }}</h2>
        <p>{{ description }}</p>
      </div>
      <div class="admin-chart-legend" aria-label="图例">
        <span v-for="item in series" :key="item.label">
          <i :style="{ backgroundColor: item.color }" aria-hidden="true" />
          {{ item.label }}
        </span>
      </div>
    </header>

    <div class="admin-chart" role="img" :aria-label="`${title}趋势图`">
      <svg :viewBox="`0 0 ${viewWidth} ${viewHeight}`" preserveAspectRatio="none" aria-hidden="true">
        <line v-for="offset in [0.25, 0.5, 0.75]" :key="offset" x1="12" :y1="viewHeight * offset" x2="668" :y2="viewHeight * offset" />
        <polyline
          v-for="item in chartSeries"
          :key="item.label"
          :points="item.points"
          :style="{ stroke: item.color }"
        />
      </svg>
      <div class="admin-chart__labels" aria-hidden="true">
        <span v-for="index in labelIndexes" :key="index">{{ compactDate(dates[index] || '') }}</span>
      </div>
    </div>
  </article>
</template>
