<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import CampusHeader from '@/app/components/CampusHeader.vue'
import { campusLabels, formatPrice, listMarketplaceItems, statusLabels, type MarketplaceItem } from '@/features/marketplace'
import { RatingImage, RatingPageHeader, RatingState } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

const route = useRoute()
const router = useRouter()
const mine = computed(() => route.name === 'marketplace-mine')
const items = ref<MarketplaceItem[]>([])
const query = ref('')
const submittedQuery = ref('')
const loading = ref(true)
const loadingMore = ref(false)
const error = ref('')
const nextCursor = ref<string | null>(null)
let requestVersion = 0
usePageTheme('bg-page')
onMounted(() => void load(true))

async function load(reset: boolean) {
  const version = ++requestVersion
  if (reset) loading.value = true
  else loadingMore.value = true
  error.value = ''
  try {
    const page = await listMarketplaceItems({ mine: mine.value, q: submittedQuery.value, cursor: reset ? undefined : nextCursor.value ?? undefined })
    if (version !== requestVersion) return
    items.value = reset ? page.items : Array.from(new Map([...items.value, ...page.items].map((item) => [item.id, item])).values())
    nextCursor.value = page.has_more ? page.next_cursor : null
  } catch (reason) {
    if (version === requestVersion) error.value = reason instanceof Error ? reason.message : '商品加载失败'
  } finally {
    if (version === requestVersion) { loading.value = false; loadingMore.value = false }
  }
}
function search() {
  submittedQuery.value = query.value.trim()
  void load(true)
}
function clearSearch() {
  query.value = ''
  search()
}
</script>

<template>
  <main class="ratings-page marketplace-page marketplace-list-page" :class="{ 'ratings-page--with-bottom-navigation': !mine }">
    <RatingPageHeader v-if="mine" title="我的二手商品" @back="router.push({ name: 'marketplace' })">
      <RouterLink class="marketplace-text-button" :to="{ name: 'marketplace-create' }" aria-label="发布闲置">发布</RouterLink>
    </RatingPageHeader>
    <CampusHeader v-else active="marketplace" />

    <div v-if="!mine" class="marketplace-toolbar">
      <form class="ratings-search" role="search" @submit.prevent="search">
        <svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6.5" /><path d="m15.5 15.5 4 4" /></svg>
        <input v-model="query" type="search" maxlength="50" placeholder="搜索想要的闲置" aria-label="搜索二手商品" enterkeyhint="search" />
        <button v-if="query" type="button" aria-label="清空搜索" @click="clearSearch">×</button>
      </form>
      <RouterLink class="marketplace-publish" :to="{ name: 'marketplace-create' }"><span aria-hidden="true">＋</span>发布闲置</RouterLink>
    </div>

    <section class="ratings-section">
      <header class="marketplace-section-heading">
        <h2>{{ mine ? '我发布的' : submittedQuery ? '搜索结果' : '最新上架' }}</h2>
        <button type="button" :disabled="loading || loadingMore" @click="load(true)">刷新</button>
      </header>
      <RatingState v-if="loading && !items.length" title="正在加载商品" loading />
      <RatingState v-else-if="error && !items.length" title="暂时无法加载商品" :description="error" action-label="重新加载" @action="load(true)" />
      <RatingState
        v-else-if="!items.length"
        :title="submittedQuery ? '没有找到相关商品' : mine ? '还没有发布商品' : '二手小铺等待开张'"
        :description="submittedQuery ? '换个关键词试试。' : '整理一下闲置，让它们继续派上用场。'"
        :action-label="submittedQuery ? '清空搜索' : '发布第一件闲置'"
        @action="submittedQuery ? clearSearch() : router.push({ name: 'marketplace-create' })"
      />
      <template v-else>
        <p v-if="loading" class="marketplace-note" role="status">正在刷新…</p>
        <div class="marketplace-grid" :aria-busy="loading">
          <RouterLink v-for="item in items" :key="item.id" class="marketplace-card" :to="{ name: 'marketplace-item', params: { itemId: item.id } }">
            <RatingImage :asset="item.image_asset" :alt="item.title" />
            <span v-if="mine" class="marketplace-status marketplace-card__status">{{ statusLabels[item.status] }}</span>
            <div class="marketplace-card__body">
              <h3>{{ item.title }}</h3>
              <div class="marketplace-card__meta">
                <strong class="marketplace-price"><small>¥</small>{{ formatPrice(item.price_cents) }}</strong>
                <p>{{ campusLabels[item.campus] }}</p>
              </div>
            </div>
          </RouterLink>
        </div>
        <p v-if="error" class="ratings-form-error" role="alert">{{ error }}</p>
        <button v-if="nextCursor" class="ratings-load-more" type="button" :disabled="loadingMore || loading" @click="load(false)">{{ loadingMore ? '正在加载…' : '加载更多' }}</button>
      </template>
    </section>
  </main>
</template>
