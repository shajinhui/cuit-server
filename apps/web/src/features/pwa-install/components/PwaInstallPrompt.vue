<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { usePwaInstall } from '../runtime'

defineOptions({ name: 'PwaInstallPrompt' })

const props = defineProps<{
  allowPromotion: boolean
  withBottomNavigation: boolean
}>()

const {
  canPromptInstall,
  closeInstallGuide,
  dismissInstallPromotion,
  guideVisible,
  installGuide,
  requestInstall,
  shouldPromoteInstall,
} = usePwaInstall()

const installing = ref(false)
const guideDialog = ref<HTMLElement | null>(null)
const showPromotion = computed(() => props.allowPromotion && shouldPromoteInstall.value)
const installButtonLabel = computed(() => (canPromptInstall.value ? '安装' : '安装方法'))

watch(guideVisible, async (visible) => {
  if (!visible) return
  await nextTick()
  guideDialog.value?.focus()
})

onMounted(() => document.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', handleKeydown))

async function install() {
  if (installing.value) return
  installing.value = true
  await requestInstall()
  installing.value = false
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape' && guideVisible.value) closeInstallGuide()
}
</script>

<template>
  <Transition name="install-promotion">
    <aside
      v-if="showPromotion"
      class="pwa-install-promotion"
      :class="{ 'pwa-install-promotion--above-navigation': withBottomNavigation }"
      aria-label="安装成信友友"
    >
      <img src="/icons/app-icon-192.png" alt="" />
      <div class="pwa-install-promotion__copy">
        <strong>安装成信友友</strong>
        <span>从桌面打开，并继续查看已缓存的最近课表</span>
      </div>
      <button
        class="pwa-install-promotion__install"
        type="button"
        :disabled="installing"
        @click="install"
      >
        {{ installing ? '请稍候' : installButtonLabel }}
      </button>
      <button
        class="pwa-install-promotion__dismiss"
        type="button"
        aria-label="暂不安装"
        @click="dismissInstallPromotion"
      >
        <svg aria-hidden="true" viewBox="0 0 20 20">
          <path d="m5 5 10 10M15 5 5 15" />
        </svg>
      </button>
    </aside>
  </Transition>

  <Teleport to="body">
    <Transition name="install-guide">
      <div v-if="guideVisible" class="pwa-install-guide-backdrop" @click.self="closeInstallGuide">
        <section
          ref="guideDialog"
          class="pwa-install-guide"
          role="dialog"
          aria-modal="true"
          aria-labelledby="pwa-install-guide-title"
          tabindex="-1"
        >
          <div class="pwa-install-guide__handle" aria-hidden="true"></div>
          <header>
            <img src="/icons/app-icon-192.png" alt="" />
            <div>
              <p>{{ installGuide.browserName }}</p>
              <h2 id="pwa-install-guide-title">安装到桌面</h2>
            </div>
          </header>
          <p class="pwa-install-guide__description">{{ installGuide.description }}</p>
          <ol>
            <li v-for="(step, index) in installGuide.steps" :key="step">
              <span>{{ index + 1 }}</span>
              <p>{{ step }}</p>
            </li>
          </ol>
          <button class="pwa-install-guide__done" type="button" @click="closeInstallGuide">
            我知道了
          </button>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
