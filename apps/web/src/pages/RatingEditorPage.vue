<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import {
  createRatingBoard,
  createRatingItem,
  createRequestID,
  uploadRatingAsset,
} from '@/features/ratings'
import { RatingPageHeader } from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'RatingEditorPage' })

const route = useRoute()
const router = useRouter()
const boardID = computed(() => String(route.params.boardId ?? ''))
const creatingItem = computed(() => Boolean(boardID.value))
const title = ref('')
const description = ref('')
const imageFile = ref<File | null>(null)
const imagePreview = ref('')
const imageError = ref('')
const error = ref('')
const submitting = ref(false)
const requestID = createRequestID()
let uploadedAssetID = ''

const titleLength = computed(() => Array.from(title.value.trim()).length)
const descriptionLength = computed(() => Array.from(description.value.trim()).length)
const canSubmit = computed(() => {
  const titleValid = creatingItem.value
    ? titleLength.value >= 1 && titleLength.value <= 60
    : titleLength.value >= 2 && titleLength.value <= 40
  const descriptionValid = descriptionLength.value <= (creatingItem.value ? 1000 : 500)
  return titleValid && descriptionValid && !submitting.value && !imageError.value
})

usePageTheme('#f2f2f7')
onBeforeUnmount(releasePreview)

function selectImage(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0] ?? null
  releasePreview()
  imageFile.value = null
  uploadedAssetID = ''
  imageError.value = ''
  if (!file) return
  if (!['image/jpeg', 'image/png'].includes(file.type)) {
    imageError.value = '请选择 JPG 或 PNG 图片'
    return
  }
  if (file.size > 5 * 1024 * 1024) {
    imageError.value = '图片不能超过 5 MB'
    return
  }
  imageFile.value = file
  imagePreview.value = URL.createObjectURL(file)
}

function releasePreview() {
  if (imagePreview.value) URL.revokeObjectURL(imagePreview.value)
  imagePreview.value = ''
}

async function submit() {
  if (!canSubmit.value) return
  submitting.value = true
  error.value = ''
  try {
    if (imageFile.value && !uploadedAssetID) {
      uploadedAssetID = (await uploadRatingAsset(imageFile.value)).id
    }
    if (creatingItem.value) {
      const item = await createRatingItem(boardID.value, {
        name: title.value.trim(),
        description: description.value.trim(),
        image_asset_id: uploadedAssetID || undefined,
        create_request_id: requestID,
      })
      await router.replace({ name: 'rating-item', params: { itemId: item.id } })
    } else {
      const board = await createRatingBoard({
        title: title.value.trim(),
        description: description.value.trim(),
        cover_asset_id: uploadedAssetID || undefined,
        create_request_id: requestID,
      })
      await router.replace({ name: 'rating-board', params: { boardId: board.id } })
    }
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '发布失败，请稍后重试'
  } finally {
    submitting.value = false
  }
}

function goBack() {
  void router.push(creatingItem.value
    ? { name: 'rating-board', params: { boardId: boardID.value } }
    : { name: 'ratings' })
}
</script>

<template>
  <main class="ratings-page">
    <RatingPageHeader :title="creatingItem ? '添加评分对象' : '创建评分板块'" @back="goBack" />
    <form class="rating-editor" @submit.prevent="submit">
      <section>
        <header><h2>{{ creatingItem ? '对象信息' : '板块信息' }}</h2><span>必填</span></header>
        <label>
          <span>{{ creatingItem ? '对象名称' : '板块标题' }}</span>
          <input v-model="title" type="text" :maxlength="creatingItem ? 60 : 40" :placeholder="creatingItem ? '例如：航空港一食堂麻辣烫' : '例如：校园食堂窗口评分'" autocomplete="off" />
          <small>{{ titleLength }}/{{ creatingItem ? 60 : 40 }}</small>
        </label>
        <label>
          <span>介绍</span>
          <textarea v-model="description" :maxlength="creatingItem ? 1000 : 500" rows="6" :placeholder="creatingItem ? '介绍这个对象，帮助大家确认评价的是谁。' : '说明这个板块评价什么、如何区分评分对象。'" />
          <small>{{ descriptionLength }}/{{ creatingItem ? 1000 : 500 }}</small>
        </label>
      </section>

      <section>
        <header><h2>{{ creatingItem ? '对象图片' : '板块封面' }}</h2><span>可选</span></header>
        <label class="rating-image-picker">
          <input type="file" accept="image/png,image/jpeg" @change="selectImage" />
          <img v-if="imagePreview" :src="imagePreview" alt="待上传图片预览" />
          <span v-else><svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>选择 JPG 或 PNG</span>
        </label>
        <p>图片最大 5 MB，发布时会上传到评分服务并统一处理。</p>
        <p v-if="imageError" class="is-error" role="alert">{{ imageError }}</p>
      </section>

      <p v-if="error" class="ratings-form-error" role="alert">{{ error }}</p>
      <button class="ratings-primary-button" type="submit" :disabled="!canSubmit">
        <span v-if="submitting" class="ratings-spinner" aria-hidden="true" />
        {{ submitting ? '正在发布…' : '确认发布' }}
      </button>
    </form>
  </main>
</template>
