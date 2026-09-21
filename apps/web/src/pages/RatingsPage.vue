<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import {
  listRatingBoards,
  type RatingBoard,
  type RatingBoardSort,
} from '@/features/ratings'
import { RatingBoardCard, RatingState } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'RatingsPage' })

const router = useRouter()
const boards = ref<RatingBoard[]>([])
const sort = ref<RatingBoardSort>('popular')
const query = ref('')
const submittedQuery = ref('')
const loading = ref(true)
const loadingMore = ref(false)
const error = ref('')
const nextCursor = ref<string | null>(null)
const hasMore = ref(false)
let requestVersion = 0

usePageTheme('#f2f2f7')
onMounted(() => void loadBoards(true))

async function loadBoards(reset: boolean) {
  const version = ++requestVersion
  if (reset) loading.value = true
  else loadingMore.value = true
  error.value = ''
  try {
    const page = await listRatingBoards({
      q: submittedQuery.value,
      sort: sort.value,
      cursor: reset ? undefined : nextCursor.value ?? undefined,
      limit: 20,
    })
    if (version !== requestVersion) return
    boards.value = reset ? page.items : deduplicate([...boards.value, ...page.items])
    nextCursor.value = page.next_cursor
    hasMore.value = page.has_more
  } catch (reason) {
    if (version !== requestVersion) return
    error.value = reason instanceof Error ? reason.message : '评分板块加载失败'
  } finally {
    if (version === requestVersion) {
      loading.value = false
      loadingMore.value = false
    }
  }
}

function changeSort(value: RatingBoardSort) {
  if (sort.value === value) return
  sort.value = value
  void loadBoards(true)
}

function search() {
  submittedQuery.value = query.value.trim()
  void loadBoards(true)
}

function clearSearch() {
  query.value = ''
  if (!submittedQuery.value) return
  submittedQuery.value = ''
  void loadBoards(true)
}

function deduplicate(items: RatingBoard[]) {
  return Array.from(new Map(items.map((item) => [item.id, item])).values())
}
</script>

<template>
  <main class="ratings-page">
    <header class="ratings-home-header">
      <button type="button" class="ratings-icon-button" aria-label="返回工具页" @click="router.push({ name: 'tools' })">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <div>
        <small>校园社区</small>
        <h1>友友评分</h1>
      </div>
      <RouterLink class="ratings-icon-button" :to="{ name: 'ratings-mine' }" aria-label="我的评分内容">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <circle cx="12" cy="8" r="3.2" /><path d="M5.5 20c.6-4.1 2.8-6.2 6.5-6.2s5.9 2.1 6.5 6.2" />
        </svg>
      </RouterLink>
    </header>

    <section class="ratings-home-intro">
      <div>
        <span aria-hidden="true">★</span>
        <h2>发现值得讨论的校园事物</h2>
        <p>创建一个主题，邀请大家添加对象并留下真实评分。</p>
      </div>
      <RouterLink :to="{ name: 'rating-create-board' }">创建板块</RouterLink>
    </section>

    <form class="ratings-search" role="search" @submit.prevent="search">
      <svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6.5" /><path d="m15.5 15.5 4 4" /></svg>
      <input v-model="query" type="search" maxlength="50" placeholder="搜索评分板块" aria-label="搜索评分板块" />
      <button v-if="query" type="button" aria-label="清空搜索" @click="clearSearch">×</button>
    </form>

    <section class="ratings-section">
      <header class="ratings-section-heading">
        <div>
          <small>{{ submittedQuery ? '搜索结果' : '评分广场' }}</small>
          <h2>{{ submittedQuery || '大家都在评' }}</h2>
        </div>
        <div class="ratings-segment" role="group" aria-label="板块排序">
          <button type="button" :class="{ 'is-active': sort === 'popular' }" @click="changeSort('popular')">热门</button>
          <button type="button" :class="{ 'is-active': sort === 'newest' }" @click="changeSort('newest')">最新</button>
        </div>
      </header>

      <RatingState v-if="loading" title="正在加载评分板块" loading />
      <RatingState
        v-else-if="error"
        title="暂时无法打开评分广场"
        :description="error"
        action-label="重新加载"
        @action="loadBoards(true)"
      />
      <RatingState
        v-else-if="boards.length === 0"
        :title="submittedQuery ? '没有找到相关板块' : '还没有评分板块'"
        :description="submittedQuery ? '换个关键词试试。' : '创建第一个主题，邀请大家参与评分。'"
        :action-label="submittedQuery ? '清空搜索' : '创建板块'"
        @action="submittedQuery ? clearSearch() : router.push({ name: 'rating-create-board' })"
      />
      <div v-else class="rating-board-list">
        <RatingBoardCard v-for="board in boards" :key="board.id" :board="board" />
        <button v-if="hasMore" type="button" class="ratings-load-more" :disabled="loadingMore" @click="loadBoards(false)">
          {{ loadingMore ? '正在加载…' : '加载更多' }}
        </button>
      </div>
    </section>
  </main>
</template>

