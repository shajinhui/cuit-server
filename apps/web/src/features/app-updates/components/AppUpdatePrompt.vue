<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { useAndroidLiveUpdate } from '../runtime'

defineOptions({ name: 'AppUpdatePrompt' })

const {
  appliedUpdate,
  applyError,
  applyingUpdate,
  readyUpdate,
  updateDialogVisible,
  applyReadyUpdate,
  dismissAppliedUpdate,
  dismissReadyUpdate,
} = useAndroidLiveUpdate()
const dialog = ref<HTMLElement | null>(null)
const updateVersion = computed(() => appliedUpdate.value?.version ?? readyUpdate.value?.version ?? '')

watch(updateDialogVisible, async (visible) => {
  if (!visible) return
  await nextTick()
  dialog.value?.focus()
})

onMounted(() => document.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', handleKeydown))

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') closeDialog()
}

function closeDialog() {
  if (applyingUpdate.value) return
  if (appliedUpdate.value) {
    dismissAppliedUpdate()
  } else {
    dismissReadyUpdate()
  }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="app-update">
      <div
        v-if="updateDialogVisible"
        class="app-update-backdrop"
        @click.self="closeDialog"
      >
        <section
          ref="dialog"
          class="app-update-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="app-update-title"
          :aria-describedby="appliedUpdate ? undefined : 'app-update-description'"
          tabindex="-1"
        >
          <div class="app-update-dialog__handle" aria-hidden="true"></div>
          <header>
            <img src="/icons/app-icon-192.png" alt="" />
            <div>
              <p>Web 更新 {{ updateVersion }}</p>
              <h2 id="app-update-title">
                {{ appliedUpdate ? '更新完成' : readyUpdate?.title }}
              </h2>
            </div>
          </header>

          <template v-if="appliedUpdate">
            <div class="app-update-dialog__status app-update-dialog__status--success" role="status">
              <span class="app-update-dialog__status-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="m6.5 12.3 3.4 3.4 7.7-8" />
                </svg>
              </span>
              <div>
                <strong>已更新到 {{ appliedUpdate.version }}</strong>
                <span>新版本已经生效，可以继续使用。</span>
              </div>
            </div>
            <div class="app-update-dialog__actions app-update-dialog__actions--single">
              <button class="app-update-dialog__apply" type="button" @click="dismissAppliedUpdate">
                知道了
              </button>
            </div>
          </template>

          <template v-else-if="readyUpdate">
            <p id="app-update-description" class="app-update-dialog__description">
              {{ readyUpdate.releaseNotes }}
            </p>
            <div
              v-if="applyingUpdate"
              class="app-update-dialog__status app-update-dialog__status--applying"
              role="status"
              aria-live="polite"
            >
              <span class="app-update-dialog__spinner" aria-hidden="true"></span>
              <div>
                <strong>正在应用更新</strong>
                <span>应用会快速重启，重启后将显示更新结果。</span>
              </div>
            </div>
            <p v-else-if="applyError" class="app-update-dialog__notice app-update-dialog__notice--error" role="alert">
              {{ applyError }}
            </p>
            <p v-else class="app-update-dialog__notice">
              更新包已下载完成。点击后应用会快速重启一次，并显示更新结果。
            </p>
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
                <span v-if="applyingUpdate" class="app-update-dialog__button-spinner" aria-hidden="true"></span>
                {{ applyingUpdate ? '正在应用' : applyError ? '重新更新' : '重启并更新' }}
              </button>
            </div>
          </template>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
