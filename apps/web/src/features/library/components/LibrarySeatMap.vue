<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import type { LibrarySeat } from '../api'
import { librarySeatPosition, seatTitle } from '../model'

const props = defineProps<{
  imageUrl: string
  seats: LibrarySeat[]
}>()

const emit = defineEmits<{
  select: [seat: LibrarySeat]
}>()

const minimumZoom = 1
const maximumZoom = 2.5
const zoomStep = 0.25
const zoom = ref(1)
const imageLoaded = ref(false)

const positionedSeats = computed(() =>
  props.seats.flatMap((seat) => {
    const position = librarySeatPosition(seat.Coordinate)
    return position ? [{ seat, position }] : []
  }),
)

watch(
  () => props.imageUrl,
  () => {
    zoom.value = 1
    imageLoaded.value = false
  },
)

function changeZoom(direction: 1 | -1) {
  zoom.value = Math.min(maximumZoom, Math.max(minimumZoom, zoom.value + direction * zoomStep))
}

function selectSeat(seat: LibrarySeat) {
  if (seat.Status === 'available' && !seat.OnlyView) emit('select', seat)
}

function statusLabel(seat: LibrarySeat) {
  if (seat.OnlyView || seat.Status === 'unavailable') return '不可预约'
  if (seat.Status === 'reserved') return '时段占用'
  return '可预约'
}
</script>

<template>
  <section class="library-seat-map" aria-label="座位平面图">
    <header class="library-seat-map__toolbar">
      <p>拖动查看平面图，点击绿色座位即可预约。</p>
      <div aria-label="平面图缩放">
        <button type="button" aria-label="缩小平面图" :disabled="zoom <= minimumZoom" @click="changeZoom(-1)">−</button>
        <button type="button" aria-label="恢复原始大小" :disabled="zoom === minimumZoom" @click="zoom = minimumZoom">
          {{ Math.round(zoom * 100) }}%
        </button>
        <button type="button" aria-label="放大平面图" :disabled="zoom >= maximumZoom" @click="changeZoom(1)">＋</button>
      </div>
    </header>

    <div class="library-seat-map__viewport" tabindex="0" aria-label="可滚动的座位平面图">
      <div class="library-seat-map__canvas" :style="{ width: `${zoom * 100}%` }">
        <img
          :src="imageUrl"
          alt="当前预约区域平面图"
          draggable="false"
          @load="imageLoaded = true"
        />
        <template v-if="imageLoaded">
          <button
            v-for="item in positionedSeats"
            :key="item.seat.ID"
            type="button"
            class="library-map-seat"
            :class="[`is-${item.seat.Status}`, { 'is-view-only': item.seat.OnlyView }]"
            :style="{ left: item.position.left, top: item.position.top }"
            :disabled="item.seat.Status !== 'available' || item.seat.OnlyView"
            :aria-label="`${seatTitle(item.seat)}，${statusLabel(item.seat)}`"
            :title="`${seatTitle(item.seat)} · ${statusLabel(item.seat)}`"
            @click="selectSeat(item.seat)"
          />
        </template>
      </div>
    </div>

    <footer class="library-seat-map__legend" aria-label="座位状态图例">
      <span><i class="is-available" />可预约</span>
      <span><i class="is-reserved" />时段占用</span>
      <span><i class="is-unavailable" />不可预约</span>
    </footer>
  </section>
</template>
