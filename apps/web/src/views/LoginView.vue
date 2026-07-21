<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import graduationIcon from '@/assets/icons/profile-graduation-cap.png'
import securityIcon from '@/assets/icons/profile-security.png'
import { useSessionStore } from '@/stores/session'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const username = ref('')
const password = ref('')
const remember = ref(true)
const showPassword = ref(false)
const notice = ref('')
let noticeTimer: number | undefined

async function submitLogin() {
  try {
    await session.login(username.value, password.value, remember.value)
    password.value = ''
    const redirect = typeof route.query.redirect === 'string' && route.query.redirect.startsWith('/')
      ? route.query.redirect
      : '/schedule'
    await router.replace(redirect)
  } catch {
    password.value = ''
  }
}

function showNotice(message: string) {
  notice.value = message
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 1800)
}
</script>

<template>
  <main class="login-page">
    <section class="login-content">
      <header class="login-brand">
        <div class="login-logo"><img :src="graduationIcon" alt="校园助手" /></div>
        <h1>校园助手</h1>
        <p>你的校园生活，一站搞定</p>
      </header>

      <form class="app-login-form" @submit.prevent="submitLogin">
        <label class="login-field">
          <span>学号</span>
          <div class="login-input">
            <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 8a7 7 0 0 1 14 0" /></svg>
            <input v-model.trim="username" autocomplete="username" inputmode="numeric" placeholder="请输入学号" required />
          </div>
        </label>

        <label class="login-field">
          <span>密码</span>
          <div class="login-input">
            <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0 1 10 0v3M6 10h12v10H6zM12 14v3" /></svg>
            <input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="current-password"
              placeholder="请输入密码"
              required
            />
            <button type="button" class="password-toggle" :aria-label="showPassword ? '隐藏密码' : '显示密码'" @click="showPassword = !showPassword">
              <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z" /><circle cx="12" cy="12" r="2.5" /></svg>
            </button>
          </div>
        </label>

        <div class="login-options">
          <label class="remember-login">
            <input v-model="remember" type="checkbox" />
            <span aria-hidden="true">✓</span>
            保持登录状态
          </label>
          <button type="button" @click="showNotice('请检查学号、密码或联系学校信息中心')">登录遇到问题？</button>
        </div>

        <p v-if="session.error" class="login-error" role="alert">{{ session.error }}</p>
        <button type="submit" class="login-submit" :disabled="session.loading">
          {{ session.loading ? '正在登录…' : '登录' }}
        </button>
      </form>

      <div class="secure-login-note">
        <img :src="securityIcon" alt="" />
        <span>安全连接学校统一身份认证</span>
      </div>

      <p class="login-legal">
        登录即表示你已阅读并同意<br />
        <button type="button" @click="showNotice('用户协议正在完善中')">《用户协议》</button>
        和
        <button type="button" @click="showNotice('隐私政策正在完善中')">《隐私政策》</button>
      </p>
    </section>

    <Transition name="toast">
      <div v-if="notice" class="toast-message login-toast" role="status">{{ notice }}</div>
    </Transition>
  </main>
</template>
