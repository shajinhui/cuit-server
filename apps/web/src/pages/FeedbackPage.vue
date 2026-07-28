<script setup lang="ts">
import { Capacitor } from '@capacitor/core'
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

import {
  submitFeedback,
  type FeedbackPlatform,
  type FeedbackType,
} from '@/features/feedback'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'FeedbackPage' })

const router = useRouter()
const feedbackType = ref<FeedbackType>('suggestion')
const platform = ref<FeedbackPlatform>(detectPlatform())
const content = ref('')
const submitting = ref(false)
const submitted = ref(false)
const error = ref('')

const contentLength = computed(() => Array.from(content.value.trim()).length)
const canSubmit = computed(
  () => contentLength.value >= 10 && contentLength.value <= 2000 && !submitting.value,
)

usePageTheme('#f2f2f7')

async function submit() {
  if (!canSubmit.value) return
  submitting.value = true
  submitted.value = false
  error.value = ''
  try {
    await submitFeedback({
      type: feedbackType.value,
      platform: platform.value,
      content: content.value.trim(),
    })
    content.value = ''
    submitted.value = true
  } catch {
    error.value = navigator.onLine
      ? '暂时无法提交，请稍后重试'
      : '当前网络不可用，请联网后重试'
  } finally {
    submitting.value = false
  }
}

function detectPlatform(): FeedbackPlatform {
  const nativePlatform = Capacitor.getPlatform()
  if (nativePlatform === 'ios') return 'ios'
  if (nativePlatform === 'android') return 'android'
  return /iPhone|iPad|iPod/i.test(navigator.userAgent) ? 'ios' : 'android'
}
</script>

<template>
  <main class="feedback-page">
    <header class="feedback-topbar">
      <button type="button" class="feedback-back-button" aria-label="返回我的页面" @click="router.push({ name: 'profile' })">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <h1>问题反馈</h1>
      <span aria-hidden="true" />
    </header>

    <form class="feedback-content" @submit.prevent="submit">
      <section class="feedback-section" aria-labelledby="feedback-type-title">
        <div class="feedback-section__heading">
          <h2 id="feedback-type-title">反馈类型</h2>
          <span>请选择一项</span>
        </div>
        <div class="feedback-segment" role="group" aria-label="反馈类型">
          <button
            type="button"
            :class="{ 'is-selected': feedbackType === 'suggestion' }"
            :aria-pressed="feedbackType === 'suggestion'"
            @click="feedbackType = 'suggestion'"
          >
            建议
          </button>
          <button
            type="button"
            :class="{ 'is-selected': feedbackType === 'bug' }"
            :aria-pressed="feedbackType === 'bug'"
            @click="feedbackType = 'bug'"
          >
            Bug
          </button>
        </div>
      </section>

      <section class="feedback-section" aria-labelledby="feedback-platform-title">
        <div class="feedback-section__heading">
          <h2 id="feedback-platform-title">问题平台</h2>
          <span>请确认发生问题的设备</span>
        </div>
        <div class="feedback-segment" role="group" aria-label="问题平台">
          <button
            type="button"
            :class="{ 'is-selected': platform === 'android' }"
            :aria-pressed="platform === 'android'"
            @click="platform = 'android'"
          >
            Android
          </button>
          <button
            type="button"
            :class="{ 'is-selected': platform === 'ios' }"
            :aria-pressed="platform === 'ios'"
            @click="platform = 'ios'"
          >
            iOS
          </button>
        </div>
      </section>

      <section class="feedback-section feedback-description" aria-labelledby="feedback-description-title">
        <div class="feedback-section__heading">
          <h2 id="feedback-description-title">详细描述</h2>
          <span>{{ contentLength }}/2000</span>
        </div>
        <textarea
          v-model="content"
          maxlength="2000"
          rows="7"
          placeholder="请描述你的建议，或说明问题出现的页面、操作步骤和实际表现（至少 10 个字）"
          aria-describedby="feedback-privacy-note"
          @input="submitted = false; error = ''"
        />
        <p id="feedback-privacy-note">提交时会记录应用平台和设备浏览器信息，不会上传密码或教务系统 Cookie。</p>
      </section>

      <p v-if="error" class="feedback-message is-error" role="alert">{{ error }}</p>
      <p v-else-if="submitted" class="feedback-message is-success" role="status">
        已收到，谢谢你的反馈
      </p>

      <button class="feedback-submit" type="submit" :disabled="!canSubmit">
        <span v-if="submitting" class="feedback-spinner" aria-hidden="true" />
        {{ submitting ? '正在提交…' : '提交反馈' }}
      </button>
    </form>
  </main>
</template>
