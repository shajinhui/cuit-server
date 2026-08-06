<script setup lang="ts">
import { ref } from 'vue'

import { presetAvatars } from '../avatar'

defineOptions({ name: 'AvatarPicker' })

const props = defineProps<{
  open: boolean
  selectedPresetId: number | null
  saving: boolean
}>()

const emit = defineEmits<{
  close: []
  selectPreset: [presetId: number]
  upload: [file: File]
}>()

const fileInput = ref<HTMLInputElement | null>(null)

function close() {
  if (!props.saving) emit('close')
}

function openFilePicker() {
  fileInput.value?.click()
}

function handleFileChange(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) emit('upload', file)
  input.value = ''
}
</script>

<template>
  <Teleport to="body">
    <Transition name="avatar-sheet" appear>
      <div v-if="open" class="avatar-sheet-backdrop" @pointerdown.self="close">
        <section
          class="avatar-sheet"
          role="dialog"
          aria-modal="true"
          aria-labelledby="avatar-picker-title"
          @keydown.esc="close"
        >
          <div class="avatar-sheet__grabber" aria-hidden="true" />
          <header class="avatar-sheet__header">
            <button type="button" :disabled="saving" @click="close">取消</button>
            <h2 id="avatar-picker-title">选择头像</h2>
            <span aria-hidden="true" />
          </header>

          <div class="avatar-grid" role="group" aria-label="默认头像">
            <button
              v-for="preset in presetAvatars"
              :key="preset.id"
              type="button"
              class="avatar-grid__item"
              :class="{ 'is-active': selectedPresetId === preset.id }"
              :aria-pressed="selectedPresetId === preset.id"
              :aria-label="`默认头像 ${preset.id}`"
              :disabled="saving"
              @click="emit('selectPreset', preset.id)"
            >
              <img :src="preset.src" alt="" />
              <span v-if="selectedPresetId === preset.id" class="avatar-grid__check" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="m5 12.5 4.2 4.2L19 7" />
                </svg>
              </span>
            </button>
          </div>

          <button
            type="button"
            class="avatar-upload-button"
            :disabled="saving"
            @click="openFilePicker"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M12 16V5m0 0L7.5 9.5M12 5l4.5 4.5M5 14v4.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V14" />
            </svg>
            <span>{{ saving ? '保存中…' : '上传自定义头像' }}</span>
          </button>
          <p class="avatar-sheet__note">自定义头像仅保存在本机，不会上传服务器</p>
          <input
            ref="fileInput"
            type="file"
            accept="image/*"
            hidden
            aria-label="选择自定义头像图片"
            @change="handleFileChange"
          />
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
