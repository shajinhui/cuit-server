<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { useRouter } from 'vue-router'

import airportMapURL from '@/assets/maps/campus-map-airport.jpg'
import longquanMapURL from '@/assets/maps/campus-map-longquan.jpg'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'CampusMapPage' })

type CampusId = 'airport' | 'longquan'

interface CampusMap {
  id: CampusId
  label: string
  title: string
  fileName: string
  imageURL: string
  alt: string
}

const maps: CampusMap[] = [
  {
    id: 'airport',
    label: '航空港',
    title: '航空港校区地图',
    fileName: '成都信息工程大学-航空港校区地图.jpg',
    imageURL: airportMapURL,
    alt: '成都信息工程大学航空港校区手绘地图',
  },
  {
    id: 'longquan',
    label: '龙泉',
    title: '龙泉校区地图',
    fileName: '成都信息工程大学-龙泉校区地图.jpg',
    imageURL: longquanMapURL,
    alt: '成都信息工程大学龙泉校区手绘地图',
  },
]

const router = useRouter()
const selectedCampus = ref<CampusId>('airport')
const viewport = ref<HTMLElement>()
const zoom = ref(1)
const loading = ref(true)
const loadFailed = ref(false)
const imageKey = ref(0)
const saving = ref(false)
const mapFiles = new Map<CampusId, File>()

const currentMap = computed(() => maps.find((map) => map.id === selectedCampus.value) ?? maps[0])
const zoomPercentage = computed(() => `${Math.round(zoom.value * 100)}%`)
const imageStyle = computed(() => ({ width: `${zoom.value * 100}%` }))
const backdropStyle = computed(() => ({ backgroundImage: `url("${currentMap.value.imageURL}")` }))

usePageTheme('#f2f2f7')

function selectCampus(campus: CampusId) {
  if (selectedCampus.value === campus) return

  selectedCampus.value = campus
  loading.value = true
  loadFailed.value = false
  zoom.value = 1
  imageKey.value += 1
  void nextTick(() => viewport.value?.scrollTo({ top: 0, left: 0, behavior: 'auto' }))
}

function imageLoaded() {
  loading.value = false
  loadFailed.value = false
  void prepareMapFile(currentMap.value).catch(() => undefined)
}

function imageFailed() {
  loading.value = false
  loadFailed.value = true
}

function retry() {
  loading.value = true
  loadFailed.value = false
  imageKey.value += 1
}

function setZoom(nextZoom: number) {
  zoom.value = Math.min(2.5, Math.max(1, nextZoom))
  if (zoom.value === 1) {
    void nextTick(() => viewport.value?.scrollTo({ top: 0, left: 0, behavior: 'smooth' }))
  }
}

async function prepareMapFile(map: CampusMap) {
  const cachedFile = mapFiles.get(map.id)
  if (cachedFile) return cachedFile

  const response = await fetch(map.imageURL)
  if (!response.ok) throw new Error(`地图图片读取失败：${response.status}`)

  const blob = await response.blob()
  const file = new File([blob], map.fileName, { type: blob.type || 'image/jpeg' })
  mapFiles.set(map.id, file)
  return file
}

async function saveMapImage() {
  if (saving.value) return

  saving.value = true
  const map = currentMap.value

  try {
    const file = await prepareMapFile(map)
    const canShareFile =
      typeof navigator.share === 'function' &&
      typeof navigator.canShare === 'function' &&
      navigator.canShare({ files: [file] })

    if (canShareFile) {
      await navigator.share({
        files: [file],
        title: map.title,
      })
      return
    }

    window.location.assign(map.imageURL)
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return
    window.location.assign(map.imageURL)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <main class="campus-map-page">
    <header class="campus-map-topbar">
      <button
        type="button"
        class="campus-map-icon-button"
        aria-label="返回工具页"
        @click="router.push({ name: 'tools' })"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>

      <div>
        <h1>校园地图</h1>
        <p>{{ currentMap.title }}</p>
      </div>

      <a
        class="campus-map-icon-button"
        :href="currentMap.imageURL"
        aria-label="打开当前校园地图原图"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M14 5h5v5M19 5l-8 8M18 13v5a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5" />
        </svg>
      </a>
    </header>

    <div class="campus-map-selector" role="group" aria-label="选择校区">
      <span
        class="campus-map-selector__selection"
        :class="{ 'is-longquan': selectedCampus === 'longquan' }"
        aria-hidden="true"
      />
      <button
        v-for="campus in maps"
        :key="campus.id"
        type="button"
        :aria-pressed="selectedCampus === campus.id"
        @click="selectCampus(campus.id)"
      >
        {{ campus.label }}
      </button>
    </div>

    <section
      ref="viewport"
      class="campus-map-viewer"
      :class="{ 'is-zoomed': zoom > 1 }"
      :aria-busy="loading"
      :aria-label="currentMap.title"
    >
      <div v-if="loading" class="campus-map-state" aria-live="polite">
        <span class="campus-map-spinner" aria-hidden="true" />
        <p>正在打开地图…</p>
      </div>

      <div v-if="loadFailed" class="campus-map-state campus-map-state--error" role="alert">
        <strong>地图加载失败</strong>
        <p>请重新加载，或使用右上角按钮查看原图。</p>
        <button type="button" @click="retry">重新加载</button>
      </div>

      <div v-show="!loadFailed" class="campus-map-image-stage">
        <span class="campus-map-image-backdrop" :style="backdropStyle" aria-hidden="true" />
        <a
          class="campus-map-image-link"
          :href="currentMap.imageURL"
          :style="imageStyle"
          :aria-label="`全屏查看${currentMap.title}`"
        >
          <img
            :key="`${selectedCampus}-${imageKey}`"
            :src="currentMap.imageURL"
            :alt="currentMap.alt"
            draggable="false"
            @load="imageLoaded"
            @error="imageFailed"
          />
        </a>
      </div>
    </section>

    <div class="campus-map-controls">
      <div class="campus-map-zoom" aria-label="地图缩放">
        <button
          type="button"
          :disabled="zoom <= 1"
          aria-label="缩小地图"
          @click="setZoom(zoom - 0.25)"
        >
          <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M6 12h12" /></svg>
        </button>
        <button
          type="button"
          class="campus-map-zoom__value"
          :disabled="zoom === 1"
          @click="setZoom(1)"
        >
          <strong>{{ zoomPercentage }}</strong>
          <span>{{ zoom === 1 ? '适应屏幕' : '轻点还原' }}</span>
        </button>
        <button
          type="button"
          :disabled="zoom >= 2.5"
          aria-label="放大地图"
          @click="setZoom(zoom + 0.25)"
        >
          <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M6 12h12M12 6v12" /></svg>
        </button>
      </div>

      <button
        type="button"
        class="campus-map-save-button"
        :disabled="saving || loading"
        aria-label="保存当前校园地图图片"
        @click="saveMapImage"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M12 4v10m-4-4 4 4 4-4M5 19h14" />
        </svg>
        <span>{{ saving ? '准备中' : '保存' }}</span>
      </button>
    </div>

    <p class="campus-map-note">轻点地图全屏查看 · 手绘示意图仅供参考</p>
  </main>
</template>
