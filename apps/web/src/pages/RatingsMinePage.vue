<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import {
  formatRatingTime,
  listMyRatingContent,
  type RatingBoard,
  type RatingComment,
  type RatingItem,
  type RatingMineKind,
} from '@/features/ratings'
import {
  RatingBoardCard,
  RatingItemCard,
  RatingPageHeader,
  RatingState,
} from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'RatingsMinePage' })

type MineEntry = RatingBoard | RatingItem | RatingComment

const router = useRouter()
const kind = ref<RatingMineKind>('boards')
const entries = ref<MineEntry[]>([])
const loading = ref(true)
const loadingMore = ref(false)
const error = ref('')
const nextCursor = ref<string | null>(null)
const hasMore = ref(false)
let requestVersion = 0

usePageTheme('#f2f2f7')
onMounted(() => void loadContent(true))

async function loadContent(reset: boolean) {
  const version = ++requestVersion
  if (reset) loading.value = true
  else loadingMore.value = true
  error.value = ''
  try {
    const page = await listMyRatingContent(kind.value, {
      cursor: reset ? undefined : nextCursor.value ?? undefined,
      limit: 20,
    })
    if (version !== requestVersion) return
    entries.value = reset ? page.items : [...entries.value, ...page.items]
    nextCursor.value = page.next_cursor
    hasMore.value = page.has_more
  } catch (reason) {
    if (version === requestVersion) error.value = reason instanceof Error ? reason.message : '内容加载失败'
  } finally {
    if (version === requestVersion) {
      loading.value = false
      loadingMore.value = false
    }
  }
}

function changeKind(value: RatingMineKind) {
  if (kind.value === value) return
  kind.value = value
  void loadContent(true)
}

function isBoard(entry: MineEntry): entry is RatingBoard {
  return 'title' in entry
}

function isItem(entry: MineEntry): entry is RatingItem {
  return 'name' in entry
}

function openComment(comment: RatingComment) {
  void router.push({ name: 'rating-item', params: { itemId: comment.item_id } })
}
</script>

<template>
  <main class="ratings-page">
    <RatingPageHeader title="我的评分内容" @back="router.push({ name: 'ratings' })" />
    <div class="ratings-mine-tabs" role="tablist" aria-label="我的评分内容分类">
      <button v-for="option in ([['boards', '板块'], ['items', '对象'], ['votes', '评分'], ['comments', '评论']] as const)" :key="option[0]" type="button" role="tab" :aria-selected="kind === option[0]" :class="{ 'is-active': kind === option[0] }" @click="changeKind(option[0])">{{ option[1] }}</button>
    </div>

    <section class="ratings-section ratings-section--inset">
      <RatingState v-if="loading" title="正在加载我的内容" loading />
      <RatingState v-else-if="error" title="暂时无法加载" :description="error" action-label="重新加载" @action="loadContent(true)" />
      <RatingState v-else-if="entries.length === 0" title="这里还没有内容" description="参与评分后，你的记录会出现在这里。" />
      <div v-else class="rating-board-list">
        <template v-for="entry in entries" :key="entry.id">
          <RatingBoardCard v-if="isBoard(entry)" :board="entry" />
          <RatingItemCard v-else-if="isItem(entry)" :item="entry" />
          <button v-else type="button" class="rating-mine-comment" @click="openComment(entry)">
            <span>{{ entry.body }}</span><small>{{ formatRatingTime(entry.created_at) }} · 查看对象</small>
          </button>
        </template>
        <button v-if="hasMore" type="button" class="ratings-load-more" :disabled="loadingMore" @click="loadContent(false)">{{ loadingMore ? '正在加载…' : '加载更多' }}</button>
      </div>
    </section>
  </main>
</template>
