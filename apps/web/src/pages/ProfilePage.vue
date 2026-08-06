<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import aboutIcon from '@/assets/icons/profile-about.png'
import graduationIcon from '@/assets/icons/profile-graduation-cap.png'
import profileIcon from '@/assets/icons/nav-profile.png'
import { logoutSession } from '@/app/sessionLifecycle'
import { useProfileStore } from '@/features/profile'
import AvatarPicker from '@/features/profile/components/AvatarPicker.vue'
import { usePwaInstall } from '@/features/pwa-install'
import { useSessionStore } from '@/features/session'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import AppShell from '@/shared/ui/AppShell.vue'

defineOptions({ name: 'ProfilePage' })

const router = useRouter()
const profileStore = useProfileStore()
const session = useSessionStore()
const { isInstalled, requestInstall } = usePwaInstall()
const notice = ref('')
const loggingOut = ref(false)
const avatarPickerOpen = ref(false)
let noticeTimer: number | undefined

const avatarSrc = computed(() => profileStore.avatar?.src || profileIcon)
const selectedPresetId = computed(() =>
  profileStore.avatar?.kind === 'preset' ? profileStore.avatar.presetId : null,
)
const identityName = computed(() => profileStore.profile?.Name || (profileStore.loading ? '正在加载…' : '同学'))
const academicIdentity = computed(() => {
  const profile = profileStore.profile
  if (!profile) return ''
  return [profile.Grade ? `${profile.Grade}级` : '', profile.College].filter(Boolean).join(' · ')
})
const majorAndClass = computed(() => {
  const profile = profileStore.profile
  if (!profile) return ''
  return [profile.Major, profile.ClassName].filter(Boolean).join(' · ')
})
const studentNumber = computed(() => maskStudentNumber(profileStore.profile?.StudentNo || ''))
const installLabel = computed(() => (isInstalled.value ? '已安装到桌面' : '安装到桌面'))

usePageTheme('#f2f2f7')

onMounted(() => {
  void loadProfile()
  void profileStore.loadAvatar()
})

onBeforeUnmount(() => {
  window.clearTimeout(noticeTimer)
})

function showNotice(message: string) {
  notice.value = message
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 1800)
}

async function loadProfile(force = false) {
  await profileStore.load(force)
  if (session.status === 'anonymous') {
    await router.replace({ name: 'login', query: { redirect: '/profile' } })
  }
}

async function logout() {
  if (loggingOut.value) return
  loggingOut.value = true
  try {
    await logoutSession()
  } catch {
    // 本地登录态会由 session store 清除，即使远端会话已经失效也继续返回登录页。
  } finally {
    loggingOut.value = false
    await router.replace({ name: 'login' })
  }
}

async function installApp() {
  const result = await requestInstall()
  if (result === 'accepted') showNotice('已添加到桌面')
  if (result === 'installed') showNotice('当前已在桌面应用中打开')
}

async function selectPresetAvatar(presetId: number) {
  await profileStore.selectPresetAvatar(presetId)
  avatarPickerOpen.value = false
  showNotice('头像已更新')
}

async function uploadAvatar(file: File) {
  try {
    await profileStore.setCustomAvatar(file)
    avatarPickerOpen.value = false
    showNotice('头像已更新')
  } catch (error) {
    showNotice(error instanceof Error ? error.message : '头像保存失败，请重试')
  }
}

function maskStudentNumber(studentNo: string) {
  if (!studentNo) return ''
  if (studentNo.length <= 4) return studentNo
  return `${studentNo.slice(0, 4)}${'*'.repeat(studentNo.length - 4)}`
}
</script>

<template>
  <AppShell variant="profile">
    <section class="profile-page page-padding">
      <header class="profile-hero">
        <button
          type="button"
          class="profile-avatar"
          aria-label="更换头像"
          @click="avatarPickerOpen = true"
        >
          <img :src="avatarSrc" alt="" />
          <span class="profile-avatar__edit" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path d="M4 20h4.2L20 8.2l-4.2-4.2L4 16v4Zm8.6-12.8 4.2 4.2" />
            </svg>
          </span>
        </button>
        <div class="profile-hero__identity">
          <h1>{{ identityName }}</h1>
          <p>{{ academicIdentity || '学籍信息' }}</p>
        </div>
      </header>

      <article class="student-card surface-card">
        <div v-if="profileStore.profile" class="student-card__rows">
          <div class="student-card__row">
            <div class="student-card__icon">
              <img class="profile-graduation-icon" :src="graduationIcon" alt="" />
            </div>
            <div class="student-card__copy">
              <h2>学籍信息</h2>
              <p>{{ academicIdentity || '学籍信息未提供' }}</p>
            </div>
          </div>
          <div class="student-card__row">
            <div class="student-card__icon">
              <svg aria-hidden="true" viewBox="0 0 24 24">
                <path d="M4 20h16M6.5 20V9.5L12 5l5.5 4.5V20M9 12h.01M12 12h.01M15 12h.01M9 16h.01M15 16h.01M12 16v4" />
              </svg>
            </div>
            <div class="student-card__copy">
              <h2>专业与班级</h2>
              <p>{{ majorAndClass || '专业信息未提供' }}</p>
            </div>
          </div>
          <div class="student-card__row">
            <div class="student-card__icon">
              <svg aria-hidden="true" viewBox="0 0 24 24">
                <rect x="3.5" y="6" width="17" height="12" rx="2" />
                <circle cx="8.5" cy="11" r="2" />
                <path d="M5.8 15c.7-1.2 1.6-1.8 2.7-1.8s2 .6 2.7 1.8M13.5 10h4M13.5 14h4" />
              </svg>
            </div>
            <div class="student-card__copy">
              <h2>学号</h2>
              <p>{{ studentNumber || '学号未提供' }}</p>
            </div>
          </div>
        </div>
        <div v-else-if="profileStore.loading" class="profile-status" aria-live="polite">
          <h2>正在同步个人信息…</h2>
          <p>请稍候</p>
        </div>
        <div v-else class="profile-status profile-status--error" role="alert">
          <h2>个人信息暂时无法读取</h2>
          <p>{{ profileStore.error }}</p>
          <button type="button" @click="loadProfile(true)">重新读取</button>
        </div>
      </article>

      <div class="profile-menu surface-card">
        <button type="button" @click="router.push({ name: 'plan-completion' })">
          <img :src="graduationIcon" alt="" />
          <span>学业完成情况</span>
          <svg class="profile-menu__chevron" aria-hidden="true" viewBox="0 0 20 20">
            <path d="m7.5 4.5 5 5.5-5 5.5" />
          </svg>
        </button>
        <button type="button" @click="installApp">
          <svg class="profile-menu__leading-icon" aria-hidden="true" viewBox="0 0 24 24">
            <path d="M12 3v11M7.5 9.5 12 14l4.5-4.5M5 14.5V20h14v-5.5" />
          </svg>
          <span>{{ installLabel }}</span>
          <svg class="profile-menu__chevron" aria-hidden="true" viewBox="0 0 20 20">
            <path d="m7.5 4.5 5 5.5-5 5.5" />
          </svg>
        </button>
        <button type="button" @click="router.push({ name: 'feedback' })">
          <svg class="profile-menu__leading-icon" aria-hidden="true" viewBox="0 0 24 24">
            <path d="M5 5.5h14v10H9l-4 3v-13Z" />
            <path d="M8.5 9h7M8.5 12h4.5" />
          </svg>
          <span>问题反馈</span>
          <svg class="profile-menu__chevron" aria-hidden="true" viewBox="0 0 20 20">
            <path d="m7.5 4.5 5 5.5-5 5.5" />
          </svg>
        </button>
        <button type="button" @click="router.push({ name: 'about' })">
          <img :src="aboutIcon" alt="" />
          <span>关于我们</span>
          <svg class="profile-menu__chevron" aria-hidden="true" viewBox="0 0 20 20">
            <path d="m7.5 4.5 5 5.5-5 5.5" />
          </svg>
        </button>
      </div>

      <div class="profile-logout surface-card">
        <button type="button" :disabled="loggingOut" @click="logout">
          <span>{{ loggingOut ? '正在退出…' : '退出教务' }}</span>
        </button>
      </div>

      <AvatarPicker
        :open="avatarPickerOpen"
        :selected-preset-id="selectedPresetId"
        :saving="profileStore.avatarSaving"
        @close="avatarPickerOpen = false"
        @select-preset="selectPresetAvatar"
        @upload="uploadAvatar"
      />

      <Transition name="toast">
        <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
      </Transition>
    </section>
  </AppShell>
</template>
