<script setup lang="ts">
import { useRouter } from 'vue-router'

import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'AboutPage' })

const router = useRouter()
const repositoryURL = 'https://github.com/shajinhui/cuit-server'

usePageTheme('#f2f2f7')
</script>

<template>
  <main class="about-page">
    <header class="about-topbar">
      <button type="button" class="about-back-button" aria-label="返回我的页面" @click="router.push({ name: 'profile' })">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <h1>关于我们</h1>
      <span aria-hidden="true" />
    </header>

    <section class="about-content">
      <header class="about-hero">
        <img src="/icons/app-icon-192.png" alt="成信友友应用图标" />
        <h2>成信友友</h2>
        <p>校园教务与生活助手</p>
      </header>

      <section class="about-card" aria-labelledby="about-introduction-title">
        <h2 id="about-introduction-title">应用介绍</h2>
        <p>
          成信友友是一款面向成都信息工程大学学生的校园助手，提供课表、成绩、考试、空教室和学籍信息等常用服务，
          并支持 PWA 与 Android 安装。
        </p>
        <p class="about-card__note">本应用为非官方学生项目，与学校及教务系统运营方无隶属或授权关系。</p>
      </section>

      <section class="about-links" aria-label="项目链接">
        <a :href="repositoryURL" target="_blank" rel="noopener noreferrer">
          <span class="about-links__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path
                d="M12 2.7a9.5 9.5 0 0 0-3 18.5c.5.1.7-.2.7-.5v-1.8c-2.8.6-3.4-1.2-3.4-1.2-.5-1.1-1.1-1.4-1.1-1.4-.9-.6.1-.6.1-.6 1 0 1.5 1 1.5 1 .9 1.5 2.3 1.1 2.9.8.1-.6.3-1.1.6-1.3-2.2-.3-4.6-1.1-4.6-4.7 0-1 .4-1.9 1-2.6-.1-.3-.4-1.3.1-2.6 0 0 .8-.3 2.7 1a9.2 9.2 0 0 1 4.9 0c1.9-1.3 2.7-1 2.7-1 .5 1.3.2 2.3.1 2.6.7.7 1 1.6 1 2.6 0 3.7-2.3 4.5-4.6 4.7.4.3.7.9.7 1.8v2.7c0 .4.2.6.7.5A9.5 9.5 0 0 0 12 2.7Z"
              />
            </svg>
          </span>
          <span class="about-links__copy">
            <strong>GitHub</strong>
            <small>查看源代码与项目说明</small>
          </span>
          <svg class="about-links__external" aria-hidden="true" viewBox="0 0 20 20">
            <path d="M8 4h8v8M16 4l-9 9M14 11v4H5V6h4" />
          </svg>
        </a>
      </section>

      <p class="about-version">版本 0.1.0</p>
    </section>
  </main>
</template>
