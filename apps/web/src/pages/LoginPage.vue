<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { loginSession } from '@/app/sessionLifecycle'
import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'LoginPage' })

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const privacyAcceptanceKey = 'privacy-policy-accepted'
const privacyPolicyVersion = '2026-07-28'
const username = ref('')
const password = ref('')
const showPassword = ref(false)
const notice = ref('')
const retrySeconds = ref(0)
const privacyAccepted = ref(readPrivacyAcceptance())
const privacyAttention = ref(false)
let noticeTimer: number | undefined
let retryTimer: number | undefined

usePageTheme('#f2f2f7')

onBeforeUnmount(() => {
  window.clearTimeout(noticeTimer)
  window.clearInterval(retryTimer)
})

async function submitLogin() {
  if (retrySeconds.value > 0) return
  if (!privacyAccepted.value) {
    privacyAttention.value = true
    showNotice('请先阅读并同意隐私政策')
    return
  }
  try {
    await loginSession(username.value, password.value)
    password.value = ''
    const redirect = typeof route.query.redirect === 'string' && route.query.redirect.startsWith('/')
      ? route.query.redirect
      : '/schedule'
    await router.replace(redirect)
  } catch (error) {
    password.value = ''
    if (error instanceof ApiError && error.code === 50301) {
      startRetryCountdown(error.retryAfterSeconds ?? 5)
    }
  }
}

function startRetryCountdown(seconds: number) {
  window.clearInterval(retryTimer)
  retrySeconds.value = Math.max(1, Math.ceil(seconds))
  retryTimer = window.setInterval(() => {
    retrySeconds.value -= 1
    if (retrySeconds.value <= 0) {
      retrySeconds.value = 0
      window.clearInterval(retryTimer)
    }
  }, 1000)
}

function showNotice(message: string) {
  notice.value = message
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => {
    notice.value = ''
    privacyAttention.value = false
  }, 1800)
}

function readPrivacyAcceptance() {
  try {
    return window.localStorage.getItem(privacyAcceptanceKey) === privacyPolicyVersion
  } catch {
    return false
  }
}

function togglePrivacyAcceptance() {
  privacyAccepted.value = !privacyAccepted.value
  privacyAttention.value = false
  try {
    if (privacyAccepted.value) {
      window.localStorage.setItem(privacyAcceptanceKey, privacyPolicyVersion)
    } else {
      window.localStorage.removeItem(privacyAcceptanceKey)
    }
  } catch {
    // 存储不可用时仍允许本次会话完成明确选择。
  }
}
</script>

<template>
  <main class="login-page">
    <section class="login-content">
      <header class="login-brand">
        <div class="login-logo" role="img" aria-label="成信友友">
          <svg class="login-logo-mark" aria-hidden="true" viewBox="0 0 32 32">
            <path class="login-logo-cap" d="m3.5 12.1 12.5-6 12.5 6L16 18.2 3.5 12.1Z" />
            <path class="login-logo-base" d="M8.1 15.1v5.2c2 2.2 4.7 3.3 7.9 3.3s5.9-1.1 7.9-3.3v-5.2" />
            <path class="login-logo-tassel" d="M28.5 12.2v7.1" />
            <circle class="login-logo-dot" cx="28.5" cy="21.5" r="1.6" />
          </svg>
        </div>
        <div class="login-brand-copy">
          <h1>成信友友</h1>
        </div>
      </header>

      <section class="login-panel" aria-labelledby="login-panel-title">
        <div class="login-panel-heading">
          <h2 id="login-panel-title">登录教务系统</h2>
          <p>使用学校统一身份认证账号</p>
        </div>

        <form class="app-login-form" @submit.prevent="submitLogin">
          <div class="login-input-group">
            <div class="login-field">
              <label for="login-username">学号</label>
              <div class="login-input">
                <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 8a7 7 0 0 1 14 0" /></svg>
                <input id="login-username" v-model.trim="username" autocomplete="username" inputmode="numeric" placeholder="学号" required />
              </div>
            </div>

            <div class="login-field">
              <label for="login-password">密码</label>
              <div class="login-input">
                <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0 1 10 0v3M6 10h12v10H6zM12 14v3" /></svg>
                <input
                  id="login-password"
                  v-model="password"
                  :type="showPassword ? 'text' : 'password'"
                  autocomplete="current-password"
                  placeholder="密码"
                  required
                />
                <button
                  type="button"
                  class="password-toggle"
                  :class="{ 'is-visible': showPassword }"
                  :aria-label="showPassword ? '隐藏密码' : '显示密码'"
                  :aria-pressed="showPassword"
                  @click="showPassword = !showPassword"
                >
                  <svg aria-hidden="true" viewBox="0 0 24 24">
                    <path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z" />
                    <circle cx="12" cy="12" r="2.5" />
                    <path class="password-toggle-slash" d="m4.5 4.5 15 15" />
                  </svg>
                </button>
              </div>
            </div>
          </div>

          <div class="login-error-slot">
            <Transition name="login-error">
              <p v-if="session.error" class="login-error" role="alert">{{ session.error }}</p>
            </Transition>
          </div>

          <button
            type="submit"
            class="login-submit"
            :disabled="session.loading || retrySeconds > 0"
            :aria-busy="session.loading"
            :aria-label="session.loading ? '正在登录' : retrySeconds > 0 ? `请在 ${retrySeconds} 秒后重试` : '登录'"
            aria-describedby="login-privacy-consent"
          >
            <span class="login-submit-state" aria-hidden="true">
              <span class="login-submit-label" :class="{ 'is-hidden': session.loading }">
                {{ retrySeconds > 0 ? `请稍后重试（${retrySeconds}s）` : '登录' }}
              </span>
              <span class="login-submit-loading" :class="{ 'is-visible': session.loading }">
                <svg class="login-spinner" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /></svg>
                正在登录…
              </span>
            </span>
          </button>

          <button class="login-help" type="button" @click="showNotice('请检查学号、密码或联系学校信息中心')">登录遇到问题？</button>
        </form>

        <div class="secure-login-note">
          <svg aria-hidden="true" viewBox="0 0 24 24">
            <path d="M12 3 5.5 5.8v5.1c0 4.2 2.7 7.7 6.5 9.1 3.8-1.4 6.5-4.9 6.5-9.1V5.8L12 3Z" />
            <path d="m9.2 11.7 1.8 1.8 3.9-4" />
          </svg>
          <span>安全连接学校统一身份认证</span>
        </div>
      </section>

      <div
        id="login-privacy-consent"
        class="login-privacy-consent"
        :class="{ 'needs-attention': privacyAttention }"
      >
        <button
          type="button"
          class="login-privacy-check"
          role="checkbox"
          :aria-checked="privacyAccepted"
          aria-label="同意隐私政策"
          @click="togglePrivacyAcceptance"
        >
          <svg v-if="privacyAccepted" aria-hidden="true" viewBox="0 0 20 20">
            <path d="m4.5 10.2 3.3 3.3 7.7-7.7" />
          </svg>
        </button>
        <p>
          我已阅读并同意
          <button type="button" @click="router.push({ name: 'privacy' })">《隐私政策》</button>
          ，知悉登录将处理学号、密码及学业信息。
        </p>
      </div>

      <p class="login-legal">
        <button type="button" @click="showNotice('用户协议正在完善中')">用户协议</button>
      </p>
    </section>

    <Transition name="toast">
      <div v-if="notice" class="toast-message login-toast" role="status">{{ notice }}</div>
    </Transition>
  </main>
</template>
