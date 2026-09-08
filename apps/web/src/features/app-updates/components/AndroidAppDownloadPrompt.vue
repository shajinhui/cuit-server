<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { ANDROID_APK_URL } from '../androidDownload'

defineOptions({ name: 'AndroidAppDownloadPrompt' })

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ close: [] }>()
const dialog = ref<HTMLElement | null>(null)

watch(
  () => props.open,
  async (open) => {
    if (!open) return
    await nextTick()
    dialog.value?.focus()
  },
)

onMounted(() => document.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', handleKeydown))

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape' && props.open) emit('close')
}
</script>

<template>
  <Teleport to="body">
    <Transition name="app-update">
      <div v-if="open" class="app-update-backdrop" @click.self="emit('close')">
        <section
          ref="dialog"
          class="app-update-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="android-app-download-title"
          aria-describedby="android-app-download-description"
          tabindex="-1"
        >
          <div class="app-update-dialog__handle" aria-hidden="true"></div>
          <header>
            <img src="/icons/app-icon-192.png" alt="" />
            <div>
              <p>安卓新版 · v0.2.2</p>
              <h2 id="android-app-download-title">下载新版 App</h2>
            </div>
          </header>
          <p id="android-app-download-description" class="app-update-dialog__description">
            新版支持将整学期课表导入系统日历，安装后即可直接使用。
          </p>
          <p class="app-update-dialog__notice">下载完成后直接安装，再打开成信友友。</p>
          <div class="app-update-dialog__actions">
            <button class="app-update-dialog__later" type="button" @click="emit('close')">
              暂不下载
            </button>
            <a
              class="app-update-dialog__apply"
              :href="ANDROID_APK_URL"
              target="_blank"
              rel="noopener noreferrer"
            >
              下载新版 APK
            </a>
          </div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
