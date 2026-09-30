<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { contactLabels, createMarketplaceItem, listingTypeFromQuery, listingTypes, parsePriceCents, validContact, type Campus, type ContactType } from '@/features/marketplace'
import { createRequestID, uploadRatingAsset } from '@/features/ratings'
import { RatingPageHeader } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import GlassSelect from '@/shared/ui/GlassSelect.vue'

const router = useRouter()
const route = useRoute()
const listingType = ref(listingTypeFromQuery(route.query.type))
const wanted = computed(() => listingType.value === 'wanted')
const title = ref('')
const description = ref('')
const price = ref('')
const campus = ref<Campus>('airport')
const contactType = ref<ContactType>('wechat')
const contactValue = ref('')
const imageFile = ref<File | null>(null)
const imagePreview = ref('')
const imageError = ref('')
const error = ref('')
const submitting = ref(false)
let uploadedAssetID = ''
let lastPayload = ''
let requestID = createRequestID()
const priceCents = computed(() => parsePriceCents(price.value))
const contactValid = computed(() => validContact(contactType.value, contactValue.value))
const canSubmit = computed(() => title.value.trim().length > 0 && description.value.trim().length > 0 && priceCents.value !== null && contactValid.value && !imageError.value && !submitting.value)
usePageTheme('bg-page')
onBeforeUnmount(releasePreview)

function releasePreview() {
  if (imagePreview.value) URL.revokeObjectURL(imagePreview.value)
  imagePreview.value = ''
}
function removeImage() {
  releasePreview()
  imageFile.value = null
  uploadedAssetID = ''
  imageError.value = ''
}
function selectImage(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  removeImage()
  input.value = ''
  if (!['image/jpeg', 'image/png'].includes(file.type)) { imageError.value = '请选择 JPG 或 PNG 图片'; return }
  if (file.size > 5 * 1024 * 1024) { imageError.value = '图片不能超过 5 MB'; return }
  imageFile.value = file
  imagePreview.value = URL.createObjectURL(file)
}
async function submit() {
  if (!canSubmit.value || priceCents.value === null) return
  submitting.value = true
  error.value = ''
  try {
    if (imageFile.value && !uploadedAssetID) uploadedAssetID = (await uploadRatingAsset(imageFile.value)).id
    const payload = {
      listing_type: listingType.value,
      title: title.value.trim(), description: description.value.trim(), price_cents: priceCents.value,
      campus: campus.value, contact_type: contactType.value, contact_value: contactValue.value.trim(),
      image_asset_id: uploadedAssetID || undefined,
    }
    const serialized = JSON.stringify(payload)
    if (lastPayload && lastPayload !== serialized) requestID = createRequestID()
    lastPayload = serialized
    const item = await createMarketplaceItem({ ...payload, create_request_id: requestID })
    await router.replace({ name: 'marketplace-item', params: { itemId: item.id }, query: { type: listingType.value } })
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '发布失败，请重试'
  } finally { submitting.value = false }
}
</script>

<template>
  <main class="ratings-page marketplace-page">
    <RatingPageHeader :title="wanted ? '发布求购' : '发布闲置'" @back="router.push({ name: 'marketplace', query: { type: listingType } })" />
    <form class="marketplace-editor" @submit.prevent="submit">
      <fieldset :disabled="submitting">
        <div class="marketplace-type-switch" role="group" aria-label="发布类型">
          <button v-for="type in listingTypes" :key="type.value" type="button" :aria-pressed="listingType === type.value" @click="listingType = type.value">{{ type.value === 'wanted' ? '我想求购' : '我要出售' }}</button>
        </div>
        <section class="marketplace-form-section">
          <h2>{{ wanted ? '求购信息' : '商品信息' }}</h2>
          <label><span>{{ wanted ? '求购标题' : '商品标题' }}</span><input v-model="title" required maxlength="60" :placeholder="wanted ? '例如：求购一盏护眼台灯' : '例如：九成新台灯'" /></label>
          <label><span>{{ wanted ? '需求说明' : '商品描述' }}</span><textarea v-model="description" required maxlength="2000" rows="3" :placeholder="wanted ? '说说想要的型号、成色要求和期望交易地点。' : '说说成色、使用情况、配件和交易地点，如有瑕疵请注明。'" /></label>
          <div class="marketplace-form-row">
            <label><span>{{ wanted ? '预算（元）' : '价格（元）' }}</span><input v-model="price" required inputmode="decimal" maxlength="8" placeholder="0.00" aria-describedby="marketplace-price-help" /></label>
            <label><span>交易校区</span><GlassSelect v-model="campus" :options="[{ value: 'airport', label: '航空港校区' }, { value: 'longquan', label: '龙泉校区' }] as const" title="选择交易校区" :disabled="submitting" /></label>
          </div>
          <p id="marketplace-price-help" :class="{ 'ratings-form-error': price && priceCents === null }">{{ wanted ? '预算' : '价格' }}为 0.01–99999.99 元，最多两位小数。</p>
        </section>
        <section class="marketplace-form-section">
          <h2>{{ wanted ? '参考图片' : '商品图片' }} <small>选填</small></h2>
          <label class="rating-image-picker">
            <input type="file" accept="image/jpeg,image/png" :aria-label="wanted ? '选择参考图片' : '选择商品图片'" @change="selectImage" />
            <img v-if="imagePreview" :src="imagePreview" alt="商品图片预览" />
            <span v-else><svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>{{ wanted ? '添加一张参考图' : '添加一张实拍图' }}</span>
          </label>
          <p>支持 JPG、PNG，最大 5 MB。</p>
          <button v-if="imagePreview || imageError" class="marketplace-text-button" type="button" @click="removeImage">移除图片</button>
          <p v-if="imageError" class="ratings-form-error" role="alert">{{ imageError }}</p>
        </section>
        <section class="marketplace-form-section">
          <h2>{{ wanted ? '我的联系方式' : '联系卖家' }}</h2>
          <div class="marketplace-contact-fields">
          <label><span>联系方式</span><GlassSelect v-model="contactType" :options="[{ value: 'wechat', label: '微信' }, { value: 'qq', label: 'QQ' }, { value: 'phone', label: '手机号' }] as const" title="选择联系方式" :disabled="submitting" /></label>
          <label><span>{{ contactLabels[contactType] }}</span><input v-model="contactValue" required maxlength="80" :inputmode="contactType === 'wechat' ? 'text' : 'numeric'" :placeholder="`填写${wanted ? '有闲置的同学' : '买家'}可以联系到你的${contactLabels[contactType]}`" autocomplete="off" aria-describedby="marketplace-contact-help" /></label>
          </div>
          <p v-if="contactValue && !contactValid" class="ratings-form-error">请填写有效的{{ contactLabels[contactType] }}，不要包含空格。</p>
          <p id="marketplace-contact-help">发布即同意向点击“{{ wanted ? '我有闲置' : '我想购买' }}”的登录用户展示此联系方式。</p>
        </section>
        <p class="marketplace-note">买卖双方自行联系、约定交易。本版本暂不支持在线支付。</p>
        <p v-if="error" class="ratings-form-error" role="alert">{{ error }}</p>
        <button type="submit" class="ratings-primary-button" :disabled="!canSubmit">{{ submitting ? '正在发布…' : wanted ? '发布求购' : '确认上架' }}</button>
      </fieldset>
    </form>
  </main>
</template>
