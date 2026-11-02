<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { currentRatingSessionGeneration } from '@/features/ratings/auth'
import { RatingsApiError } from '@/features/ratings/client'
import { uploadRatingAsset } from '@/features/ratings/api'
import RatingAvatar from '@/features/ratings/components/RatingAvatar.vue'
import { createSquareAvatar, presetAvatars } from '@/features/profile/avatar'
import type { ActiveAvatar } from '@/features/profile/store'
import { useCommunityStore } from '../store'

const props = defineProps<{ open: boolean; localAvatar: ActiveAvatar | null }>()
const emit = defineEmits<{ close: []; saved: [] }>()
const community = useCommunityStore()
const name = ref(''), error = ref(''), assetID = ref<string | null>(null)
const preset = ref(1), saving = ref(false), preparing = ref(false), consent = ref(false)
const file = ref<File | null>(null), preview = ref('')
const dialog = ref<HTMLFormElement | null>(null)
let previousFocus: HTMLElement | null = null
let version = 0
const previewAuthor = computed(() => ({ id: '', display_name: name.value || '校园同学', avatar_preset: preset.value, avatar_asset_id: assetID.value }))
const nameLength = computed(() => [...new Intl.Segmenter('zh', { granularity: 'grapheme' }).segment(name.value.trim())].length)
const canSave = computed(() => Boolean(community.profile) && !community.loading && consent.value && !saving.value && !preparing.value && nameLength.value >= 2 && nameLength.value <= 24)

function releasePreview() { if (preview.value) URL.revokeObjectURL(preview.value); preview.value = '' }
async function load() {
  const requestVersion = ++version
  await community.load(true)
  if (!props.open || requestVersion !== version) return
  error.value = community.error
  if (!community.profile) return
  name.value = community.profile.display_name
  preset.value = Math.max(1, Math.min(15, community.profile.avatar_preset))
  assetID.value = community.profile.avatar_asset_id
}
watch(() => props.open, open => {
  version++
  releasePreview()
  file.value = null
  saving.value = false
  preparing.value = false
  consent.value = false
  error.value = ''
  if (open) {
    previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
    void load().then(async () => { await nextTick(); if (props.open) dialog.value?.focus() })
  } else previousFocus?.focus()
}, { immediate: true })
watch(() => community.profile, (value, old) => { if (!value && old && props.open) emit('close') })
onBeforeUnmount(() => { version++; releasePreview(); previousFocus?.focus() })
function close() { if (!saving.value && !preparing.value) emit('close') }
function trapFocus(event: KeyboardEvent) {
  if (event.key !== 'Tab' || !dialog.value) return
  const elements = [...dialog.value.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled)')].filter(element => element.offsetParent !== null)
  const first = elements[0], last = elements.at(-1)
  if (!first || !last) { event.preventDefault(); return }
  if (event.shiftKey && (document.activeElement === first || document.activeElement === dialog.value)) { event.preventDefault(); last.focus() }
  else if (!event.shiftKey && (document.activeElement === last || document.activeElement === dialog.value)) { event.preventDefault(); first.focus() }
}
function selectPreset(id: number) { preset.value = id; assetID.value = null; file.value = null; releasePreview() }
async function chooseFile(event: Event) {
  const input = event.target as HTMLInputElement
  const selected = input.files?.[0]
  input.value = ''
  if (!selected) return
  const requestVersion = version
  preparing.value = true
  try {
    const blob = await createSquareAvatar(selected)
    if (requestVersion !== version || !props.open) return
    if (blob.size > 2 * 1024 * 1024) throw new Error('头像不能超过 2 MB')
    releasePreview()
    file.value = new File([blob], 'avatar.jpg', { type: 'image/jpeg' })
    preview.value = URL.createObjectURL(blob)
    assetID.value = null
  } catch (reason) { if (requestVersion === version) error.value = reason instanceof Error ? reason.message : '无法处理图片' }
  finally { if (requestVersion === version) preparing.value = false }
}
async function useLocal() {
  const local = props.localAvatar
  if (!local) return
  if (local.kind === 'preset' && local.presetId) { selectPreset(local.presetId); return }
  if (!local.src.startsWith('blob:')) { error.value = '请从相册重新选择图片'; return }
  const requestVersion = version
  try {
    const blob = await (await fetch(local.src)).blob()
    if (requestVersion !== version || !props.open) return
    if (!['image/jpeg', 'image/png'].includes(blob.type) || blob.size > 2 * 1024 * 1024) throw new Error('本机头像无法直接同步，请重新选择')
    releasePreview()
    file.value = new File([blob], blob.type === 'image/png' ? 'avatar.png' : 'avatar.jpg', { type: blob.type })
    preview.value = URL.createObjectURL(blob)
    assetID.value = null
  } catch (reason) { if (requestVersion === version) error.value = reason instanceof Error ? reason.message : '无法读取本机头像' }
}
async function save() {
  if (!canSave.value) return
  const requestVersion = version, session = currentRatingSessionGeneration()
  saving.value = true
  error.value = ''
  try {
    if (file.value) {
      const uploaded = await uploadRatingAsset(file.value)
      if (requestVersion !== version || session !== currentRatingSessionGeneration()) return
      assetID.value = uploaded.id
      file.value = null
    }
    await community.save({ display_name: name.value.trim(), avatar_preset: preset.value, avatar_asset_id: assetID.value })
    if (requestVersion === version) { emit('saved'); emit('close') }
  } catch (reason) {
    if (requestVersion !== version) return
    error.value = reason instanceof Error ? reason.message : '保存失败，请重试'
    if (reason instanceof RatingsApiError && reason.status === 409) await community.load(true)
  } finally { if (requestVersion === version) saving.value = false }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="avatar-sheet">
      <div v-if="open" class="avatar-sheet-backdrop" @pointerdown.self="close" @keydown.esc="close">
        <form ref="dialog" class="avatar-sheet community-profile-editor" role="dialog" aria-modal="true" aria-labelledby="community-profile-title" tabindex="-1" @keydown="trapFocus" @submit.prevent="save">
          <header class="avatar-sheet__header">
            <button type="button" :disabled="saving || preparing" @click="close">取消</button>
            <h2 id="community-profile-title">公开资料</h2>
            <button type="submit" :disabled="!canSave">{{ saving ? '保存中…' : '保存' }}</button>
          </header>
          <p>昵称和头像在评分、二手和论坛中统一展示。学籍信息不会公开。</p>
          <p v-if="community.loading" role="status">正在加载公开资料…</p>
          <template v-if="community.profile && !community.loading">
            <div class="community-profile-editor__preview">
              <img v-if="preview" :src="preview" alt="头像预览" />
              <RatingAvatar v-else :author="previewAuthor" />
            </div>
            <label class="community-profile-editor__name">公开昵称
              <input v-model="name" type="text" maxlength="96" autocomplete="off" :disabled="saving" placeholder="2 至 24 个字，不必填写学校姓名" />
              <small>{{ nameLength }}/24</small>
            </label>
            <div class="avatar-grid" role="group" aria-label="预设头像">
              <button v-for="avatar in presetAvatars" :key="avatar.id" type="button" class="avatar-grid__item" :class="{ 'is-active': !assetID && !file && preset === avatar.id }" :aria-pressed="!assetID && !file && preset === avatar.id" :aria-label="`预设头像 ${avatar.id}`" :disabled="saving || preparing" @click="selectPreset(avatar.id)">
                <img :src="avatar.src" alt="" />
              </button>
            </div>
            <label class="avatar-upload-button community-profile-editor__upload">
              {{ preparing ? '正在处理图片…' : '选择照片（确认保存后才上传）' }}
              <input type="file" accept="image/*" :disabled="saving || preparing" @change="chooseFile" />
            </label>
            <button v-if="localAvatar" type="button" class="avatar-upload-button" :disabled="saving || preparing" @click="useLocal">使用本机头像</button>
            <label class="community-profile-editor__consent"><input v-model="consent" type="checkbox" :disabled="saving" />我同意将以上昵称和头像展示给已登录的社区用户。</label>
          </template>
          <p v-if="error" role="alert">{{ error }}</p>
          <button v-if="!community.profile && !community.loading" type="button" class="avatar-upload-button" @click="load">重新加载</button>
        </form>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.community-profile-editor { max-height: 88dvh; overflow-y: auto; color: var(--text-primary); }
.community-profile-editor > p { font-size: 13px; line-height: 1.5; }
.community-profile-editor__preview { display: flex; justify-content: center; margin: 16px 0; }
.community-profile-editor__preview > img, .community-profile-editor__preview :deep(.rating-avatar) { width: 80px; height: 80px; border-radius: 50%; object-fit: cover; }
.community-profile-editor__name { display: grid; gap: 8px; margin: 16px 0; font-size: 14px; }
.community-profile-editor__name input { width: 100%; box-sizing: border-box; min-height: 44px; padding: 10px; border-radius: 12px; border: 1px solid var(--border-color, #8886); background: transparent; color: inherit; font: inherit; }
.community-profile-editor__consent { display: flex; align-items: flex-start; gap: 8px; margin-top: 16px; padding: 12px 0; font-size: 13px; line-height: 1.5; }
.community-profile-editor__upload { position: relative; overflow: hidden; }
.community-profile-editor__upload input { position: absolute; inset: 0; opacity: 0; width: 100%; cursor: pointer; }
@media (prefers-reduced-motion: reduce) { .avatar-sheet-enter-active, .avatar-sheet-leave-active { transition: none; } }
</style>
