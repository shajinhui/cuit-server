<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import {
  getRatingBoard,
  listRatingItems,
  type RatingBoard,
  type RatingItem,
  type RatingItemSort,
} from '@/features/ratings'
import {
  RatingAvatar,
  RatingImage,
  RatingItemCard,
  RatingPageHeader,
  RatingReportDialog,
  RatingState,
} from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'RatingBoardPage' })

const route = useRoute()
const router = useRouter()
const boardID = computed(() => String(route.params.boardId ?? ''))
const board = ref<RatingBoard | null>(null)
const items = ref<RatingItem[]>([])
const sort = ref<RatingItemSort>('popular')
const query = ref('')
const submittedQuery = ref('')
const loading = ref(true)
const error = ref('')
const nextCursor = ref<string | null>(null)
const hasMore = ref(false)
const loadingMore = ref(false)
const reportOpen = ref(false)
const notice = ref('')
let requestVersion = 0
let noticeTimer: number | undefined

usePageTheme('#f2f2f7')
onMounted(() => void loadPage())
onBeforeUnmount(() => window.clearTimeout(noticeTimer))

async function loadPage() {
  loading.value = true
  error.value = ''
  try {
    const [loadedBoard] = await Promise.all([getRatingBoard(boardID.value), loadItems(true)])
    board.value = loadedBoard
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '评分板块加载失败'
  } finally {
    loading.value = false
  }
}

async function loadItems(reset: boolean) {
  const version = ++requestVersion
  if (!reset) loadingMore.value = true
  error.value = ''
  try {
    const page = await listRatingItems(boardID.value, {
      q: submittedQuery.value,
      sort: sort.value,
      cursor: reset ? undefined : nextCursor.value ?? undefined,
      limit: 20,
    })
    if (version !== requestVersion) return
    items.value = reset
      ? page.items
      : Array.from(new Map([...items.value, ...page.items].map((item) => [item.id, item])).values())
    nextCursor.value = page.next_cursor
    hasMore.value = page.has_more
  } finally {
    if (version === requestVersion) loadingMore.value = false
  }
}

function changeSort(value: RatingItemSort) {
  if (sort.value === value) return
  sort.value = value
  void loadItems(true).catch(showListError)
}

function search() {
  submittedQuery.value = query.value.trim()
  void loadItems(true).catch(showListError)
}

function showListError(reason: unknown) {
  error.value = reason instanceof Error ? reason.message : '评分对象加载失败'
}

function showNotice() {
  notice.value = '举报已提交'
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 2200)
}
</script>

<template>
  <main class="ratings-page ratings-page--with-action">
    <RatingPageHeader title="评分板块" back-label="返回评分广场" @back="router.push({ name: 'ratings' })" />

    <RatingState v-if="loading" title="正在加载板块" loading />
    <RatingState v-else-if="error && !board" title="无法打开这个板块" :description="error" action-label="重新加载" @action="loadPage" />

    <template v-else-if="board">
      <section class="rating-board-hero">
        <RatingImage :asset="board.cover_asset" :alt="board.title" />
        <div class="rating-board-hero__copy">
          <small>评分板块</small>
          <h1>{{ board.title }}</h1>
          <p>{{ board.description || '创建者还没有填写板块介绍。' }}</p>
          <span><RatingAvatar :author="board.creator" />{{ board.creator.display_name }} 创建</span>
          <button type="button" class="rating-report-link" @click="reportOpen = true">举报板块</button>
        </div>
        <dl>
          <div><dt>{{ board.item_count }}</dt><dd>对象</dd></div>
          <div><dt>{{ board.rating_count }}</dt><dd>评分人次</dd></div>
        </dl>
      </section>

      <form class="ratings-search ratings-search--inset" role="search" @submit.prevent="search">
        <svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6.5" /><path d="m15.5 15.5 4 4" /></svg>
        <input v-model="query" type="search" maxlength="50" placeholder="搜索这个板块的对象" aria-label="搜索评分对象" />
        <button v-if="query" type="button" aria-label="清空搜索" @click="query = ''; search()">×</button>
      </form>

      <section class="ratings-section ratings-section--inset">
        <header class="ratings-section-heading ratings-section-heading--stacked">
          <div><small>全部评分</small><h2>{{ submittedQuery || `${board.item_count} 个对象` }}</h2></div>
          <div class="ratings-segment ratings-segment--four" role="group" aria-label="对象排序">
            <button v-for="option in ([['popular', '热门'], ['newest', '最新'], ['highest', '高分'], ['lowest', '低分']] as const)" :key="option[0]" type="button" :class="{ 'is-active': sort === option[0] }" @click="changeSort(option[0])">{{ option[1] }}</button>
          </div>
        </header>

        <p v-if="error" class="ratings-inline-error" role="alert">{{ error }}</p>
        <RatingState v-if="items.length === 0" :title="submittedQuery ? '没有找到相关对象' : '还没有评分对象'" description="你可以为这个板块添加第一个对象。" />
        <div v-else class="rating-item-list">
          <RatingItemCard v-for="item in items" :key="item.id" :item="item" />
          <button v-if="hasMore" type="button" class="ratings-load-more" :disabled="loadingMore" @click="loadItems(false).catch(showListError)">{{ loadingMore ? '正在加载…' : '加载更多' }}</button>
        </div>
      </section>

      <div class="ratings-bottom-action">
        <RouterLink :to="{ name: 'rating-create-item', params: { boardId: board.id } }">
          <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 4v16M4 12h16" /></svg>
          添加评分对象
        </RouterLink>
      </div>
      <RatingReportDialog :open="reportOpen" target-type="board" :target-id="board.id" @close="reportOpen = false" @submitted="showNotice" />
      <div v-if="notice" class="ratings-toast" role="status">{{ notice }}</div>
    </template>
  </main>
</template>
