<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { useAndroidLiveUpdate } from '../runtime'

defineOptions({ name: 'AppUpdatePrompt' })

const { applyingUpdate, readyUpdate, applyReadyUpdate, dismissReadyUpdate } =
  useAndroidLiveUpdate()
const dialog = ref<HTMLElement | null>(null)

watch(readyUpdate, async (update) => {
  if (!update) return
  await nextTick()
  dialog.value?.focus()
})

onMounted(() => document.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', handleKeydown))

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') dismissReadyUpdate()
}
</script>

<template>
  <Teleport to="body">
    <Transition name="app-update">
      <div
        v-if="readyUpdate"
        class="app-update-backdrop"
        @click.self="dismissReadyUpdate"
      >
        <section
          ref="dialog"
          class="app-update-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="app-update-title"
          aria-describedby="app-update-description"
          tabindex="-1"
        >
          <div class="app-update-dialog__handle" aria-hidden="true"></div>
          <header>
            <img src="/icons/app-icon-192.png" alt="" />
            <div>
              <p>Web 更新 {{ readyUpdate.version }}</p>
              <h2 id="app-update-title">{{ readyUpdate.title }}</h2>
            </div>
          </header>
          <p id="app-update-description" class="app-update-dialog__description">
            {{ readyUpdate.releaseNotes }}
          </p>
          <p class="app-update-dialog__notice">更新包已下载完成，立即更新会重新加载应用。</p>
          <div class="app-update-dialog__actions">
            <button
              class="app-update-dialog__later"
              type="button"
              :disabled="applyingUpdate"
              @click="dismissReadyUpdate"
            >
              稍后
            </button>
            <button
              class="app-update-dialog__apply"
              type="button"
              :disabled="applyingUpdate"
              @click="applyReadyUpdate"
            >
              {{ applyingUpdate ? '正在更新' : '立即更新' }}
            </button>
          </div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
