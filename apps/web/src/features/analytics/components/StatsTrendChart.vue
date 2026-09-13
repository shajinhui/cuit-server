<script setup lang="ts">
import { computed } from 'vue'

import { chartCoordinates, type ChartSeries } from '../model'

defineOptions({ name: 'StatsTrendChart' })

const props = defineProps<{
  title: string
  description: string
  labels: string[]
  series: ChartSeries[]
  unit?: 'count' | 'latency'
}>()

const viewWidth = 680
const viewHeight = 210
const allValues = computed(() => props.series.flatMap((item) => item.values))
const maximum = computed(() => Math.max(1, ...allValues.value))
const chartSeries = computed(() =>
  props.series.map((item) => ({
    ...item,
    points: chartCoordinates(item.values, maximum.value, viewWidth, viewHeight, 44, 12),
  })),
)
const labelIndexes = computed(() => {
  const last = Math.max(0, props.labels.length - 1)
  return [...new Set([0, Math.floor(last / 4), Math.floor(last / 2), Math.floor((last * 3) / 4), last])]
})
const gridTicks = computed(() => [maximum.value, maximum.value / 2, 0])
const showPoints = computed(() => props.labels.length <= 30)

function formatValue(value: number): string {
  if (props.unit === 'latency') {
    return value >= 1000 ? `${(value / 1000).toFixed(value >= 10000 ? 0 : 1)}s` : `${Math.round(value)}ms`
  }
  return new Intl.NumberFormat('zh-CN', {
    notation: value >= 10000 ? 'compact' : 'standard',
    maximumFractionDigits: 1,
  }).format(Math.round(value))
}
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
        <g v-for="(tick, index) in gridTicks" :key="index" class="admin-chart__grid">
          <line x1="44" :y1="12 + index * 93" x2="668" :y2="12 + index * 93" />
          <text x="37" :y="16 + index * 93" text-anchor="end">{{ formatValue(tick) }}</text>
        </g>
        <g v-for="item in chartSeries" :key="item.label" :style="{ color: item.color }">
          <polyline
            :points="item.points.map((point) => `${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(' ')"
            :style="{ stroke: item.color }"
          />
          <circle
            v-for="(point, index) in showPoints ? item.points : []"
            :key="index"
            :cx="point.x"
            :cy="point.y"
            r="3"
          >
            <title>{{ labels[index] }} · {{ item.label }} {{ formatValue(point.value) }}</title>
          </circle>
        </g>
      </svg>
      <div class="admin-chart__labels" aria-hidden="true">
        <span v-for="index in labelIndexes" :key="index">{{ labels[index] || '' }}</span>
      </div>
    </div>
  </article>
</template>
