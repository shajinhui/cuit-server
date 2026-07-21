<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'

import aboutIcon from '@/assets/icons/profile-about.png'
import cardIcon from '@/assets/icons/profile-campus-card.png'
import favoriteIcon from '@/assets/icons/profile-favorite.png'
import graduationIcon from '@/assets/icons/profile-graduation-cap.png'
import notificationIcon from '@/assets/icons/profile-notification.png'
import securityIcon from '@/assets/icons/profile-security.png'
import coursesIcon from '@/assets/icons/profile-weekly-courses.png'
import profileIcon from '@/assets/icons/nav-profile.png'
import AppShell from '@/layouts/AppShell.vue'

const notice = ref('')
const profileBackground = '#e9ece8'
let noticeTimer: number | undefined
let previousThemeColor = ''
let previousHtmlBackground = ''
let previousBodyBackground = ''

const menuItems = [
  { label: '我的收藏', icon: favoriteIcon },
  { label: '账号与安全', icon: securityIcon },
  { label: '通知设置', icon: notificationIcon },
  { label: '关于我们', icon: aboutIcon },
]

onMounted(() => {
  const theme = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
  previousThemeColor = theme?.content ?? ''
  previousHtmlBackground = document.documentElement.style.backgroundColor
  previousBodyBackground = document.body.style.backgroundColor
  theme?.setAttribute('content', profileBackground)
  document.documentElement.style.backgroundColor = profileBackground
  document.body.style.backgroundColor = profileBackground
})

onBeforeUnmount(() => {
  document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')?.setAttribute('content', previousThemeColor || '#fbfcf9')
  document.documentElement.style.backgroundColor = previousHtmlBackground
  document.body.style.backgroundColor = previousBodyBackground
})

function showPlaceholder(label: string) {
  notice.value = `${label}暂未接入`
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 1800)
}
</script>

<template>
  <AppShell variant="profile">
    <section class="profile-page page-padding">
      <header class="profile-hero">
        <div class="profile-avatar"><img :src="profileIcon" alt="用户头像" /></div>
        <div class="profile-hero__identity">
          <h1>张同学</h1>
          <span class="verified-badge">✓&nbsp; 已认证</span>
        </div>
        <button type="button" aria-label="查看个人资料" @click="showPlaceholder('个人资料')">›</button>
      </header>

      <article class="student-card surface-card">
        <div class="student-card__icon"><img :src="graduationIcon" alt="" /></div>
        <div>
          <h2>2024级 · 计算机学院</h2>
          <p>软件工程</p>
          <span>学号 2024****</span>
        </div>
      </article>

      <div class="profile-stats">
        <article class="surface-card">
          <img :src="coursesIcon" alt="" />
          <div><span>本周课程</span><strong>18</strong></div>
        </article>
        <article class="surface-card">
          <img :src="cardIcon" alt="" />
          <div><span>校园卡</span><strong class="is-orange">¥86.40</strong></div>
        </article>
      </div>

      <div class="profile-menu surface-card">
        <button v-for="item in menuItems" :key="item.label" type="button" @click="showPlaceholder(item.label)">
          <img :src="item.icon" alt="" />
          <span>{{ item.label }}</span>
          <strong>›</strong>
        </button>
      </div>

      <Transition name="toast">
        <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
      </Transition>
    </section>
  </AppShell>
</template>
