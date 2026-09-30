<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { useRouter } from 'vue-router'

import { contactLabels, createMarketplaceItem, parsePriceCents, validContact, type Campus, type ContactType } from '@/features/marketplace'
import { createRequestID, uploadRatingAsset } from '@/features/ratings'
import { RatingPageHeader } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

const router = useRouter()
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
      title: title.value.trim(), description: description.value.trim(), price_cents: priceCents.value,
      campus: campus.value, contact_type: contactType.value, contact_value: contactValue.value.trim(),
      image_asset_id: uploadedAssetID || undefined,
    }
    const serialized = JSON.stringify(payload)
    if (lastPayload && lastPayload !== serialized) requestID = createRequestID()
    lastPayload = serialized
    const item = await createMarketplaceItem({ ...payload, create_request_id: requestID })
    await router.replace({ name: 'marketplace-item', params: { itemId: item.id } })
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '发布失败，请重试'
  } finally { submitting.value = false }
}
</script>

<template>
  <main class="ratings-page marketplace-page">
    <RatingPageHeader title="发布闲置" @back="router.push({ name: 'marketplace' })" />
    <form class="marketplace-editor" @submit.prevent="submit">
      <fieldset :disabled="submitting">
        <section class="marketplace-form-section">
          <h2>商品信息</h2>
          <label><span>商品标题</span><input v-model="title" required maxlength="60" placeholder="例如：九成新台灯" /></label>
          <label><span>商品描述</span><textarea v-model="description" required maxlength="2000" rows="3" placeholder="说说成色、使用情况、配件和交易地点，如有瑕疵请注明。" /></label>
          <div class="marketplace-form-row">
            <label><span>价格（元）</span><input v-model="price" required inputmode="decimal" maxlength="8" placeholder="0.00" aria-describedby="marketplace-price-help" /></label>
            <label><span>交易校区</span><select v-model="campus"><option value="airport">航空港校区</option><option value="longquan">龙泉校区</option></select></label>
          </div>
          <p id="marketplace-price-help" :class="{ 'ratings-form-error': price && priceCents === null }">价格为 0.01–99999.99 元，最多两位小数。</p>
        </section>
        <section class="marketplace-form-section">
          <h2>商品图片 <small>选填</small></h2>
          <label class="rating-image-picker">
            <input type="file" accept="image/jpeg,image/png" aria-label="选择商品图片" @change="selectImage" />
            <img v-if="imagePreview" :src="imagePreview" alt="商品图片预览" />
            <span v-else><svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>添加一张实拍图</span>
          </label>
          <p>支持 JPG、PNG，最大 5 MB。</p>
          <button v-if="imagePreview || imageError" class="marketplace-text-button" type="button" @click="removeImage">移除图片</button>
          <p v-if="imageError" class="ratings-form-error" role="alert">{{ imageError }}</p>
        </section>
        <section class="marketplace-form-section">
          <h2>联系卖家</h2>
          <div class="marketplace-contact-fields">
          <label><span>联系方式</span><select v-model="contactType"><option value="wechat">微信</option><option value="qq">QQ</option><option value="phone">手机号</option></select></label>
          <label><span>{{ contactLabels[contactType] }}</span><input v-model="contactValue" required maxlength="80" :inputmode="contactType === 'wechat' ? 'text' : 'numeric'" :placeholder="`填写买家可以联系到你的${contactLabels[contactType]}`" autocomplete="off" aria-describedby="marketplace-contact-help" /></label>
          </div>
          <p v-if="contactValue && !contactValid" class="ratings-form-error">请填写有效的{{ contactLabels[contactType] }}，不要包含空格。</p>
          <p id="marketplace-contact-help">发布即同意向点击“我想购买”的登录用户展示此联系方式。</p>
        </section>
        <p class="marketplace-note">买卖双方自行联系、约定交易。本版本暂不支持在线支付。</p>
        <p v-if="error" class="ratings-form-error" role="alert">{{ error }}</p>
        <button type="submit" class="ratings-primary-button" :disabled="!canSubmit">{{ submitting ? '正在发布…' : '确认上架' }}</button>
      </fieldset>
    </form>
  </main>
</template>
