<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import CampusHeader from '@/app/components/CampusHeader.vue'
import { campusLabels, formatPrice, listMarketplaceItems, listingStatusLabel, listingTypeFromQuery, listingTypes, type ListingType, type MarketplaceItem } from '@/features/marketplace'
import { RatingImage, RatingPageHeader, RatingState } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

const route = useRoute()
const router = useRouter()
const mine = computed(() => route.name === 'marketplace-mine')
const listingType = computed(() => listingTypeFromQuery(route.query.type))
const wanted = computed(() => listingType.value === 'wanted')
const publishLabel = computed(() => wanted.value ? '发布求购' : '发布闲置')
const createRoute = computed(() => ({ name: 'marketplace-create', query: { type: listingType.value } }))
const items = ref<MarketplaceItem[]>([])
const query = ref('')
const submittedQuery = ref('')
const loading = ref(true)
const loadingMore = ref(false)
const error = ref('')
const nextCursor = ref<string | null>(null)
let requestVersion = 0
usePageTheme('bg-page')
watch([mine, listingType], () => {
  items.value = []
  nextCursor.value = null
  void load(true)
}, { immediate: true })

async function load(reset: boolean) {
  const version = ++requestVersion
  if (reset) loading.value = true
  else loadingMore.value = true
  error.value = ''
  try {
    const page = await listMarketplaceItems({ mine: mine.value, listing_type: listingType.value, q: submittedQuery.value, cursor: reset ? undefined : nextCursor.value ?? undefined })
    if (version !== requestVersion) return
    items.value = reset ? page.items : Array.from(new Map([...items.value, ...page.items].map((item) => [item.id, item])).values())
    nextCursor.value = page.has_more ? page.next_cursor : null
  } catch (reason) {
    if (version === requestVersion) error.value = reason instanceof Error ? reason.message : '发布内容加载失败'
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
function selectType(type: ListingType) {
  void router.replace({ query: { ...route.query, type } })
}
</script>

<template>
  <main class="ratings-page marketplace-page marketplace-list-page" :class="{ 'ratings-page--with-bottom-navigation': !mine }">
    <RatingPageHeader v-if="mine" title="我的二手发布" @back="router.push({ name: 'marketplace', query: { type: listingType } })">
      <RouterLink class="marketplace-text-button" :to="createRoute" :aria-label="publishLabel">发布</RouterLink>
    </RatingPageHeader>
    <CampusHeader v-else active="marketplace" />

    <div v-if="!mine" class="marketplace-toolbar">
      <form class="ratings-search" role="search" @submit.prevent="search">
        <svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6.5" /><path d="m15.5 15.5 4 4" /></svg>
        <input v-model="query" type="search" maxlength="50" :placeholder="wanted ? '搜索求购需求' : '搜索想要的闲置'" :aria-label="wanted ? '搜索求购' : '搜索二手商品'" enterkeyhint="search" />
        <button v-if="query" type="button" aria-label="清空搜索" @click="clearSearch">×</button>
      </form>
      <RouterLink class="marketplace-publish" :to="createRoute"><span aria-hidden="true">＋</span>{{ publishLabel }}</RouterLink>
    </div>

    <section class="ratings-section">
      <header class="marketplace-section-heading">
        <div class="marketplace-type-switch" role="group" aria-label="二手类型">
          <button v-for="type in listingTypes" :key="type.value" type="button" :aria-pressed="listingType === type.value" @click="selectType(type.value)">{{ type.label }}</button>
        </div>
        <button type="button" :disabled="loading || loadingMore" @click="load(true)">刷新</button>
      </header>
      <RatingState v-if="loading && !items.length" :title="wanted ? '正在加载求购' : '正在加载商品'" loading />
      <RatingState v-else-if="error && !items.length" :title="wanted ? '暂时无法加载求购' : '暂时无法加载商品'" :description="error" action-label="重新加载" @action="load(true)" />
      <RatingState
        v-else-if="!items.length"
        :title="submittedQuery ? (wanted ? '没有找到相关求购' : '没有找到相关商品') : wanted ? (mine ? '还没有发布求购' : '暂时没有求购') : mine ? '还没有发布商品' : '二手小铺等待开张'"
        :description="submittedQuery ? '换个关键词试试。' : wanted ? '写下想要的物品，让有闲置的同学联系你。' : '整理一下闲置，让它们继续派上用场。'"
        :action-label="submittedQuery ? '清空搜索' : wanted ? '发布第一条求购' : '发布第一件闲置'"
        @action="submittedQuery ? clearSearch() : router.push(createRoute)"
      />
      <template v-else>
        <p v-if="loading" class="marketplace-note" role="status">正在刷新…</p>
        <div class="marketplace-grid" :aria-busy="loading">
          <RouterLink v-for="item in items" :key="item.id" class="marketplace-card" :class="{ 'marketplace-card--wanted': item.listing_type === 'wanted' }" :to="{ name: 'marketplace-item', params: { itemId: item.id }, query: { type: listingType } }">
            <RatingImage v-if="item.listing_type !== 'wanted' || item.image_asset" :asset="item.image_asset" :alt="item.title" />
            <span v-if="mine" class="marketplace-status marketplace-card__status">{{ listingStatusLabel(item) }}</span>
            <div class="marketplace-card__body">
              <h3>{{ item.title }}</h3>
              <p v-if="item.listing_type === 'wanted'" class="marketplace-card__description">{{ item.description }}</p>
              <div class="marketplace-card__meta">
                <strong class="marketplace-price"><small v-if="item.listing_type === 'wanted'">预算</small><small>¥</small>{{ formatPrice(item.price_cents) }}</strong>
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
