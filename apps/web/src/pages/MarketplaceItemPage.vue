<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { campusLabels, contactLabels, formatPrice, getMarketplaceItem, revealSellerContact, statusLabels, updateMarketplaceStatus, type ListingStatus, type MarketplaceItem, type SellerContact } from '@/features/marketplace'
import { RatingsApiError } from '@/features/ratings'
import { RatingAvatar, RatingImage, RatingPageHeader, RatingState } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import GlassToolbar from '@/shared/ui/GlassToolbar.vue'

const route = useRoute()
const router = useRouter()
const item = ref<MarketplaceItem | null>(null)
const contact = ref<SellerContact | null>(null)
const contactPanel = ref<HTMLElement | null>(null)
const loading = ref(true)
const busy = ref(false)
const error = ref('')
const actionError = ref('')
const copyMessage = ref('')
usePageTheme('bg-page')
onMounted(() => void load())

async function load() {
  loading.value = true
  error.value = ''
  contact.value = null
  try { item.value = await getMarketplaceItem(String(route.params.itemId)) }
  catch (reason) { error.value = reason instanceof Error ? reason.message : '商品加载失败' }
  finally { loading.value = false }
}
async function buy() {
  if (!item.value || busy.value) return
  if (contact.value) { focusContact(); return }
  busy.value = true
  actionError.value = ''
  try {
    contact.value = await revealSellerContact(item.value.id)
    await nextTick()
    focusContact()
  } catch (reason) {
    actionError.value = reason instanceof Error ? reason.message : '获取联系方式失败'
    if (reason instanceof RatingsApiError && [404, 409].includes(reason.status)) await load()
  } finally { busy.value = false }
}
function focusContact() {
  contactPanel.value?.focus({ preventScroll: true })
  contactPanel.value?.scrollIntoView({ block: 'center' })
}
async function changeStatus(status: ListingStatus) {
  if (!item.value || busy.value) return
  busy.value = true
  actionError.value = ''
  try { item.value = await updateMarketplaceStatus(item.value, status) }
  catch (reason) {
    actionError.value = reason instanceof Error ? reason.message : '操作失败，请重试'
    if (reason instanceof RatingsApiError && reason.status === 409) await load()
  } finally { busy.value = false }
}
async function copyContact() {
  if (!contact.value) return
  try { await navigator.clipboard.writeText(contact.value.contact_value); copyMessage.value = '已复制联系方式' }
  catch { copyMessage.value = '复制失败，请长按联系方式手动复制' }
}
</script>

<template>
  <main class="ratings-page marketplace-page marketplace-item-page" :class="{ 'ratings-page--with-action': !item?.is_mine }">
    <RatingPageHeader title="商品详情" @back="router.push({ name: 'marketplace' })">
      <RouterLink v-if="item?.is_mine" class="marketplace-text-button" :to="{ name: 'marketplace-mine' }">我的</RouterLink>
    </RatingPageHeader>
    <RatingState v-if="loading" title="正在加载商品" loading />
    <RatingState v-else-if="error" title="暂时无法查看商品" :description="error" action-label="重新加载" @action="load" />
    <template v-else-if="item">
      <div class="marketplace-detail">
        <div v-if="item.image_asset" class="marketplace-detail__image"><RatingImage :asset="item.image_asset" :alt="item.title" /></div>
        <section class="marketplace-detail__info">
          <div class="marketplace-detail__price"><strong class="marketplace-price"><small>¥</small>{{ formatPrice(item.price_cents) }}</strong><span class="marketplace-status">{{ statusLabels[item.status] }}</span></div>
          <h1>{{ item.title }}</h1>
          <p class="marketplace-note">{{ campusLabels[item.campus] }} · {{ new Date(item.created_at).toLocaleDateString('zh-CN') }} 发布</p>
          <p class="marketplace-description">{{ item.description }}</p>
          <div class="marketplace-seller"><RatingAvatar :author="item.seller" /><span>{{ item.seller.display_name }}</span><small>{{ item.is_mine ? '我发布的' : '卖家' }}</small></div>
        </section>
        <section v-if="contact" ref="contactPanel" class="marketplace-contact" tabindex="-1" aria-labelledby="seller-contact-title">
          <h2 id="seller-contact-title">卖家联系方式</h2>
          <div class="marketplace-contact__value">
            <div><span>{{ contactLabels[contact.contact_type] }}</span><strong>{{ contact.contact_value }}</strong></div>
            <button type="button" class="marketplace-secondary-button" @click="copyContact">复制联系方式</button>
          </div>
          <p role="status">{{ copyMessage || '联系卖家确认商品情况和交易方式。获取联系方式不代表已预订或成交。' }}</p>
        </section>
        <section v-if="item.is_mine" class="marketplace-owner-actions">
          <h2>管理商品</h2>
          <p class="marketplace-note">{{ item.status === 'sold' ? '商品已售出，不再出现在二手列表中。' : '交易完成后，请标记已售出。' }}</p>
          <template v-if="item.status !== 'sold'">
            <button v-if="item.status === 'on_sale'" type="button" class="marketplace-secondary-button" :disabled="busy" @click="changeStatus('withdrawn')">下架商品</button>
            <button v-else type="button" class="ratings-primary-button" :disabled="busy" @click="changeStatus('on_sale')">重新上架</button>
            <button type="button" class="marketplace-secondary-button" :disabled="busy" @click="changeStatus('sold')">标记已售出</button>
          </template>
        </section>
        <p class="marketplace-note">买卖双方自行联系、约定交易。本版本暂不支持在线支付。</p>
        <p v-if="actionError" class="ratings-form-error" role="alert">{{ actionError }}</p>
      </div>
      <GlassToolbar v-if="!item.is_mine" class="marketplace-buy-bar" :corner-radius="24">
        <button type="button" class="ratings-primary-button" :disabled="busy || item.status !== 'on_sale'" @click="buy">{{ item.status !== 'on_sale' ? statusLabels[item.status] : busy ? '正在获取联系方式…' : contact ? '查看卖家联系方式' : '我想购买' }}</button>
      </GlassToolbar>
    </template>
  </main>
</template>
