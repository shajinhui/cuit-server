<script setup lang="ts">
import { Capacitor } from '@capacitor/core'
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import landingClassrooms from '@/assets/landing/landing-classrooms.webp'
import landingClub from '@/assets/landing/landing-club.webp'
import landingExams from '@/assets/landing/landing-exams.webp'
import landingGrades from '@/assets/landing/landing-grades.webp'
import landingLibrary from '@/assets/landing/landing-library.webp'
import landingProfile from '@/assets/landing/landing-profile.webp'
import landingResources from '@/assets/landing/landing-resources.webp'
import landingRun from '@/assets/landing/landing-run.webp'
import landingSchedule from '@/assets/landing/landing-schedule.webp'
import landingTools from '@/assets/landing/landing-tools.webp'
import { usePwaInstall } from '@/features/pwa-install'
import { QQ_GROUP_NUMBER, QQ_GROUP_URL } from '@/shared/config/community'
import { ANDROID_DOWNLOAD_URL } from '@/shared/config/downloads'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'LandingPage' })

const router = useRouter()
const { openInstallGuide } = usePwaInstall()
const usageChooserVisible = ref(false)
const usageDialog = ref<HTMLElement | null>(null)
const heroStage = ref<HTMLElement | null>(null)
let revealObserver: IntersectionObserver | undefined
let previousTitle = ''
let previousBodyOverflow = ''
let usageTrigger: HTMLElement | null = null

usePageTheme('bg-page-blue')

onMounted(() => {
  previousTitle = document.title
  document.title = '成信友友｜成都信息工程大学校园助手'

  revealObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue
        entry.target.classList.add('is-visible')
        revealObserver?.unobserve(entry.target)
      }
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.14 },
  )

  document.querySelectorAll<HTMLElement>('.landing-reveal').forEach((element) => {
    revealObserver?.observe(element)
  })

  document.addEventListener('keydown', handleUsageChooserKeydown)
})

onBeforeUnmount(() => {
  revealObserver?.disconnect()
  document.title = previousTitle
  if (usageChooserVisible.value) document.body.style.overflow = previousBodyOverflow
  document.removeEventListener('keydown', handleUsageChooserKeydown)
})

async function openApp() {
  if (usageChooserVisible.value) return
  usageTrigger = document.activeElement instanceof HTMLElement ? document.activeElement : null
  previousBodyOverflow = document.body.style.overflow
  document.body.style.overflow = 'hidden'
  usageChooserVisible.value = true
  await nextTick()
  usageDialog.value?.querySelector<HTMLButtonElement>('button')?.focus()
}

function openWebApp() {
  // 官网未注册应用 Worker；进入网页版时完整导航，让应用正常初始化离线能力。
  if (!Capacitor.isNativePlatform()) {
    window.location.assign('/login')
    return
  }
  void router.push({ name: 'login' })
}

function chooseInstallGuide(kind: 'ios' | 'android-pwa') {
  closeUsageChooser()
  openInstallGuide(kind)
}

function closeUsageChooser() {
  if (!usageChooserVisible.value) return
  usageChooserVisible.value = false
  document.body.style.overflow = previousBodyOverflow
  usageTrigger?.focus()
}

function handleUsageChooserKeydown(event: KeyboardEvent) {
  if (!usageChooserVisible.value) return
  if (event.key === 'Escape') {
    event.preventDefault()
    closeUsageChooser()
    return
  }
  if (event.key !== 'Tab') return
  const controls = usageDialog.value?.querySelectorAll<HTMLElement>('button, a[href]')
  const first = controls?.[0]
  const last = controls?.[controls.length - 1]
  if (!first || !last) return
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}

function scrollToFeatures() {
  scrollToSection('landing-features')
}

function scrollToSection(id: string) {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  document.getElementById(id)?.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth' })
}

function updateHeroPerspective(event: PointerEvent) {
  if (
    !heroStage.value ||
    event.pointerType === 'touch' ||
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  ) return
  const bounds = heroStage.value.getBoundingClientRect()
  const x = (event.clientX - bounds.left) / bounds.width - 0.5
  const y = (event.clientY - bounds.top) / bounds.height - 0.5
  heroStage.value.style.setProperty('--pointer-x', x.toFixed(3))
  heroStage.value.style.setProperty('--pointer-y', y.toFixed(3))
}

function resetHeroPerspective() {
  heroStage.value?.style.setProperty('--pointer-x', '0')
  heroStage.value?.style.setProperty('--pointer-y', '0')
}
</script>

<template>
  <main class="landing-page">
    <nav class="landing-nav" aria-label="官网导航">
      <RouterLink class="landing-brand" :to="{ name: 'landing' }" aria-label="成信友友首页">
        <img src="/icons/app-icon-192.png" alt="" />
        <span>成信友友</span>
      </RouterLink>
      <div class="landing-nav__links">
        <button type="button" @click="scrollToFeatures">功能</button>
        <button type="button" @click="scrollToSection('landing-campus')">校园</button>
        <button type="button" @click="scrollToSection('landing-platforms')">下载</button>
        <RouterLink :to="{ name: 'privacy' }">隐私</RouterLink>
      </div>
      <button class="landing-nav__open" type="button" @click="openWebApp">体验网页版</button>
    </nav>

    <section class="landing-hero" aria-labelledby="landing-title">
      <div class="landing-hero__copy">
        <p class="landing-eyebrow landing-hero__item">为成都信息工程大学学生而做</p>
        <h1 id="landing-title" class="landing-hero__item">
          <span class="landing-hero__line">把校园日常，</span>
          <span class="landing-hero__line landing-hero__line--accent">装进一个 App。</span>
        </h1>
        <p class="landing-hero__description landing-hero__item">
          从课表、成绩和图书馆，到校园评分、闲置交换与论坛交流。学习有安排，校园有回声。
        </p>
        <div class="landing-hero__actions landing-hero__item">
          <button class="landing-button landing-button--primary" type="button" @click="openApp">
            立即使用
            <svg aria-hidden="true" viewBox="0 0 20 20"><path d="m7 4 6 6-6 6" /></svg>
          </button>
          <button class="landing-button landing-button--secondary" type="button" @click="scrollToFeatures">
            看看能做什么
          </button>
        </div>
        <p class="landing-hero__note landing-hero__item">网页 / PWA · Android 安装包 · 新版原生客户端持续完善</p>
      </div>

      <div
        ref="heroStage"
        class="landing-hero-stage"
        aria-label="成信友友应用界面预览"
        @pointermove="updateHeroPerspective"
        @pointerleave="resetHeroPerspective"
      >
        <div class="landing-orb landing-orb--blue" aria-hidden="true" />
        <div class="landing-orb landing-orb--green" aria-hidden="true" />

        <div class="landing-phone landing-phone--left" aria-hidden="true">
          <div class="landing-phone__island" />
          <img :src="landingProfile" alt="" />
        </div>
        <div class="landing-phone landing-phone--center">
          <div class="landing-phone__island" aria-hidden="true" />
          <img :src="landingSchedule" alt="成信友友课表页面" />
        </div>
        <div class="landing-phone landing-phone--right" aria-hidden="true">
          <div class="landing-phone__island" />
          <img :src="landingTools" alt="" />
        </div>

        <div class="landing-float-card landing-float-card--schedule" aria-hidden="true">
          <span class="landing-float-card__icon landing-float-card__icon--blue">
            <svg viewBox="0 0 24 24"><path d="M5 4v3M19 4v3M4 9h16M5 6h14v14H5zM8 12h3v3H8z" /></svg>
          </span>
          <div><strong>本周课表</strong><small>随时清楚掌握</small></div>
        </div>
        <div class="landing-float-card landing-float-card--library" aria-hidden="true">
          <span class="landing-float-card__dot" />
          <div><strong>图书馆选座</strong><small>在平面图里找到座位</small></div>
        </div>
        <div class="landing-float-card landing-float-card--sync" aria-hidden="true">
          <span class="landing-float-card__icon landing-float-card__icon--green">
            <svg viewBox="0 0 24 24"><path d="M20 7h-8M16 3l4 4-4 4M4 17h8M8 13l-4 4 4 4" /></svg>
          </span>
          <div><strong>校园评分与二手</strong><small>发现身边的好东西</small></div>
        </div>
      </div>
    </section>

    <section class="landing-trust landing-reveal" aria-label="产品特点">
      <div><strong>教务与生活</strong><span>常用查询与校园交流放在一起</span></div>
      <div><strong>按设备选择</strong><span>浏览器、主屏幕或 Android 安装</span></div>
      <div><strong>持续打磨</strong><span>代码公开可查，认真听取反馈</span></div>
    </section>

    <section id="landing-features" class="landing-section landing-section--intro">
      <header class="landing-section-heading landing-reveal">
        <p class="landing-eyebrow">熟悉，但更轻松</p>
        <h2>你的校园信息，<br />应该一眼就懂。</h2>
        <p>从今天上什么课，到这学期的成绩与考试。把高频的事情放在前面，让信息更好找。</p>
      </header>

      <div class="landing-bento">
        <article class="landing-bento-card landing-bento-card--large landing-reveal">
          <div class="landing-bento-card__copy">
            <span class="landing-feature-icon landing-feature-icon--blue">
              <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M5 4v3M19 4v3M4 9h16M5 6h14v14H5zM8 12h3v3H8z" /></svg>
            </span>
            <p>学习安排</p>
            <h3>课表就在手边，<br />一周节奏自然展开。</h3>
            <span>切换学期与周次，本机增删改课程、自定义配色与非本周透明度，还能导出到日历。</span>
          </div>
          <div class="landing-bento-card__screen landing-bento-card__screen--schedule">
            <img :src="landingSchedule" alt="一周课表界面" loading="lazy" />
          </div>
        </article>

        <article class="landing-bento-card landing-bento-card--grades landing-reveal">
          <div class="landing-bento-card__copy">
            <span class="landing-feature-icon landing-feature-icon--purple">
              <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M6 3v3M18 3v3M4 8h16v12H4zM8 12h3M13 12h3M8 16h3" /></svg>
            </span>
            <p>成绩与考试</p>
            <h3>学习结果与安排，不再散落。</h3>
          </div>
          <div class="landing-dual-preview">
            <img :src="landingGrades" alt="成绩查询页面" loading="lazy" />
            <img :src="landingExams" alt="考试安排页面" loading="lazy" />
          </div>
        </article>

        <article class="landing-bento-card landing-bento-card--classroom landing-reveal">
          <div class="landing-bento-card__copy">
            <span class="landing-feature-icon landing-feature-icon--orange">
              <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M4 19h16M6 19V7l6-3 6 3v12M9 10h2M13 10h2M9 14h2M13 14h2" /></svg>
            </span>
            <p>空教室</p>
            <h3>想自习时，先查空教室。</h3>
          </div>
          <div class="landing-bento-card__screen landing-bento-card__screen--classroom">
            <img :src="landingClassrooms" alt="空教室查询页面" loading="lazy" />
          </div>
        </article>
      </div>
    </section>

    <section id="landing-campus" class="landing-section landing-campus" aria-labelledby="landing-campus-title">
      <header class="landing-section-heading landing-reveal">
        <p class="landing-eyebrow">校园，不只是一个工具入口</p>
        <h2 id="landing-campus-title">有用的信息，<br />也来自身边的人。</h2>
        <p>聊聊校园里的事，分享真实体验，让闲置找到下一位主人。</p>
      </header>
      <div class="landing-campus-grid">
        <article class="landing-campus-card landing-reveal">
          <span class="landing-capability-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9z" /></svg>
          </span>
          <span class="landing-capability-label">网页与客户端</span>
          <h3>校园评分</h3>
          <p>创建评分板块、添加对象，留下评分与评论。看热门，也看看不同的声音。</p>
          <ul><li>板块与对象</li><li>评分、评论与回复</li><li>我的内容与举报</li></ul>
        </article>
        <article class="landing-campus-card landing-reveal">
          <span class="landing-capability-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M5 7h14l1 14H4zM8 8V6a4 4 0 0 1 8 0v2" /></svg>
          </span>
          <span class="landing-capability-label">网页与客户端</span>
          <h3>校园二手</h3>
          <p>发布出售或求购，搜索感兴趣的闲置，联系发布者，管理自己的发布状态。</p>
          <ul><li>出售与求购</li><li>价格、预算与校区</li><li>联系与状态管理</li></ul>
          <small>仅提供信息与联系方式，不处理支付或担保交易。</small>
        </article>
        <article class="landing-campus-card landing-reveal">
          <span class="landing-capability-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M4 4h16v12H9l-5 4zM8 8h8M8 12h5" /></svg>
          </span>
          <span class="landing-capability-label landing-capability-label--native">新版原生客户端</span>
          <h3>校园论坛</h3>
          <p>按分类浏览话题，发帖交流，回复、点赞，也能继续展开楼中楼讨论。</p>
          <ul><li>分类与话题搜索</li><li>发帖、回复与点赞</li><li>内容管理与举报</li></ul>
          <small>论坛已接入服务端，需安装支持论坛的新版客户端。</small>
        </article>
      </div>
    </section>

    <section class="landing-section landing-showcase">
      <header class="landing-section-heading landing-section-heading--center landing-reveal">
        <p class="landing-eyebrow">校园服务，一步直达</p>
        <h2>少一点来回寻找，<br />多一点从容。</h2>
      </header>

      <article class="landing-feature-row landing-reveal">
        <div class="landing-feature-row__visual landing-feature-row__visual--library">
          <div class="landing-phone landing-phone--feature">
            <div class="landing-phone__island" aria-hidden="true" />
            <img :src="landingLibrary" alt="图书馆可视化选座界面" loading="lazy" />
          </div>
          <span class="landing-availability" aria-hidden="true"><i />座位状态，一图看清</span>
        </div>
        <div class="landing-feature-row__copy">
          <span class="landing-feature-number">01</span>
          <p class="landing-eyebrow">图书馆预约</p>
          <h3>从查询到选座，<br />看得见，也点得到。</h3>
          <p>按日期和时段查询座位，在平面图中直接选择；支持立即续座和一次性自动续座。</p>
          <ul>
            <li>可视化座位平面图</li>
            <li>自修室与预约记录</li>
            <li>日期、时间选择体验一致</li>
          </ul>
        </div>
      </article>

      <article class="landing-feature-row landing-feature-row--reverse landing-reveal">
        <div class="landing-feature-row__visual landing-feature-row__visual--resources">
          <div class="landing-phone landing-phone--feature">
            <div class="landing-phone__island" aria-hidden="true" />
            <img :src="landingResources" alt="历年试卷课程资料页面" loading="lazy" />
          </div>
          <span class="landing-resource-pill" aria-hidden="true">按课程查找资料</span>
        </div>
        <div class="landing-feature-row__copy">
          <span class="landing-feature-number">02</span>
          <p class="landing-eyebrow">历年试卷</p>
          <h3>复习资料，<br />按课程整齐收好。</h3>
          <p>搜索课程、文件夹或文件名，快速浏览开源课程共享库，让考试周少一点手忙脚乱。</p>
          <ul>
            <li>课程、目录与文件名搜索</li>
            <li>目录层级清晰浏览</li>
            <li>移动端文件下载</li>
          </ul>
        </div>
      </article>
    </section>

    <section class="landing-life">
      <div class="landing-life__copy landing-reveal">
        <p class="landing-eyebrow">不止教务</p>
        <h2>校园生活，<br />也可以更简单。</h2>
        <p>查看校园跑进度、俱乐部活动与签到状态。校历、校园地图和学业完成情况，也有各自清楚的入口。</p>
        <small class="landing-life__note">校园跑使用独立服务，需要单独登录；服务是否可用以实际响应为准。</small>
      </div>
      <div class="landing-life__visual landing-reveal">
        <div class="landing-phone landing-phone--life landing-phone--life-left">
          <div class="landing-phone__island" aria-hidden="true" />
          <img :src="landingRun" alt="校园跑页面" loading="lazy" />
        </div>
        <div class="landing-phone landing-phone--life landing-phone--life-right">
          <div class="landing-phone__island" aria-hidden="true" />
          <img :src="landingClub" alt="俱乐部活动页面" loading="lazy" />
        </div>
      </div>
    </section>

    <section class="landing-section landing-details" aria-labelledby="landing-details-title">
      <header class="landing-section-heading landing-reveal">
        <p class="landing-eyebrow">每天用到的细节，也值得认真</p>
        <h2 id="landing-details-title">顺手，<br />不只在第一次打开。</h2>
      </header>
      <div class="landing-details-grid">
        <article class="landing-detail landing-reveal">
          <span class="landing-capability-label">外观与交互</span>
          <h3>浅色、深色，或跟随系统。</h3>
          <p>液态玻璃导航搭配清晰的页面层级。新版客户端可开启轻量效果，在不支持折射的设备上使用磨砂降级。</p>
        </article>
        <article class="landing-detail landing-reveal">
          <span class="landing-capability-label landing-capability-label--native">新版原生客户端</span>
          <h3>今天的课，也能放在桌面。</h3>
          <p>Android / iOS 桌面小组件展示今日课程与下一节课，点击回到课表；需要安装带小组件的对应客户端。</p>
        </article>
        <article class="landing-detail landing-reveal">
          <span class="landing-capability-label">本机个性化</span>
          <h3>把常用的样子，留在手边。</h3>
          <p>选择头像、调整课程颜色与非本周显示。头像与课程自定义保存在本机，不会自动同步到其他设备或公开资料。</p>
        </article>
        <article class="landing-detail landing-reveal">
          <span class="landing-capability-label">应用内公告</span>
          <h3>重要消息，不用重新发一个包。</h3>
          <p>接入在线公告的版本可在打开或回到 App 时读取消息，也可在工具页主动查看；不是关闭 App 后的系统推送。</p>
        </article>
      </div>
    </section>

    <section id="landing-platforms" class="landing-platform" aria-labelledby="landing-platform-title">
      <div class="landing-platform__copy landing-reveal">
        <p class="landing-eyebrow">选择适合你的入口</p>
        <h2 id="landing-platform-title">先用起来，<br />再选择怎么安装。</h2>
        <p>电脑直接用网页；iPhone / iPad 可将 PWA 添加到主屏幕；Android 可选择 PWA 或安装包。</p>
        <button class="landing-button landing-button--primary" type="button" @click="openWebApp">体验网页版</button>
        <small class="landing-platform__note">展示界面为示意，不同平台与版本的布局和功能可能略有差异。</small>
      </div>
      <div class="landing-platform-options landing-reveal">
        <article>
          <span class="landing-capability-label">无需安装</span>
          <h3>网页 / PWA</h3>
          <p>课表与校园工具、评分、二手等功能。主屏幕安装方式按设备提供指引。</p>
          <div class="landing-platform-links">
            <button type="button" @click="chooseInstallGuide('ios')">iPhone / iPad 安装指引</button>
            <button type="button" @click="chooseInstallGuide('android-pwa')">Android PWA 安装指引</button>
          </div>
        </article>
        <article>
          <span class="landing-capability-label">当前公开下载</span>
          <h3>Android 安装包</h3>
          <p>固定下载入口自动获取服务器当前提供的安装包。</p>
          <a class="landing-platform-download" :href="ANDROID_DOWNLOAD_URL" rel="noopener noreferrer">下载 Android APK <span aria-hidden="true">↗</span></a>
          <small>当前入口仍为原版客户端，不等同于下方的新版原生客户端。</small>
        </article>
        <article>
          <span class="landing-capability-label landing-capability-label--native">新版客户端进展</span>
          <h3>Android / iOS 原生版</h3>
          <p>论坛、桌面小组件与原生交互已实现。Android 新版支持补丁更新，首次仍需安装对应基础包。</p>
          <small>新版正式下载另行公告；iOS 暂未提供 App Store / TestFlight 公开分发，当前可使用 PWA。原生鸿蒙仍在验证中。</small>
        </article>
      </div>
    </section>

    <section class="landing-final-cta landing-reveal">
      <img src="/icons/app-icon-192.png" alt="成信友友应用图标" />
      <p class="landing-eyebrow">成信友友</p>
      <h2>让校园生活，<br />从今天开始更顺手。</h2>
      <div class="landing-final-cta__actions">
        <button class="landing-button landing-button--primary" type="button" @click="openApp">立即使用</button>
      </div>
      <p>非官方学生项目，与学校及教务系统运营方无隶属或授权关系。</p>
    </section>

    <footer class="landing-footer">
      <RouterLink class="landing-brand" :to="{ name: 'landing' }">
        <img src="/icons/app-icon-192.png" alt="" />
        <span>成信友友</span>
      </RouterLink>
      <p>校园教务、生活与交流助手</p>
      <div>
        <RouterLink :to="{ name: 'privacy' }">隐私政策</RouterLink>
        <a :href="QQ_GROUP_URL" target="_blank" rel="noopener noreferrer">交流群 {{ QQ_GROUP_NUMBER }}</a>
        <a href="https://github.com/shajinhui/cuit-server" target="_blank" rel="noopener noreferrer">GitHub</a>
      </div>
    </footer>

    <Teleport to="body">
      <Transition name="landing-usage">
        <div
          v-if="usageChooserVisible"
          class="landing-usage-backdrop"
          role="presentation"
          @click.self="closeUsageChooser"
        >
          <section
            ref="usageDialog"
            class="landing-usage-dialog"
            role="dialog"
            aria-modal="true"
            aria-labelledby="landing-usage-title"
          >
            <button class="landing-usage-dialog__close" type="button" aria-label="关闭" @click="closeUsageChooser">
              <svg aria-hidden="true" viewBox="0 0 20 20"><path d="m5 5 10 10M15 5 5 15" /></svg>
            </button>
            <p class="landing-eyebrow">选择你的使用方式</p>
            <h2 id="landing-usage-title">安装成信友友</h2>
            <p class="landing-usage-dialog__intro">网页 / PWA 现在即可使用；不同安装包的功能以实际版本为准。</p>
            <div class="landing-usage-options">
              <button class="landing-usage-option landing-usage-option--blue" type="button" @click="openWebApp">
                <span class="landing-usage-option__icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24"><path d="M3 4h18v16H3zM3 9h18M6 6.5h.1M9 6.5h.1" /></svg>
                </span>
                <span class="landing-usage-option__copy">
                  <strong>直接使用网页版</strong>
                  <small>无需安装，登录后使用课表与校园服务</small>
                </span>
                <svg class="landing-usage-option__arrow" aria-hidden="true" viewBox="0 0 20 20"><path d="m7 4 6 6-6 6" /></svg>
              </button>
              <button class="landing-usage-option landing-usage-option--blue" type="button" @click="chooseInstallGuide('ios')">
                <span class="landing-usage-option__icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24"><path d="M12 14V3M8.5 6.5 12 3l3.5 3.5M6 12v9h12v-9" /></svg>
                </span>
                <span class="landing-usage-option__copy">
                  <strong>iPhone / iPad PWA</strong>
                  <small>添加到主屏幕，不是 App Store 原生安装包</small>
                </span>
                <svg class="landing-usage-option__arrow" aria-hidden="true" viewBox="0 0 20 20"><path d="m7 4 6 6-6 6" /></svg>
              </button>
              <button class="landing-usage-option landing-usage-option--orange" type="button" @click="chooseInstallGuide('android-pwa')">
                <span class="landing-usage-option__icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24"><path d="M4 5.5h16v11H4zM8 20h8M12 16.5V20" /></svg>
                </span>
                <span class="landing-usage-option__copy">
                  <strong>安卓 PWA 安装</strong>
                  <small>用 Chrome 或 Edge 添加到桌面</small>
                </span>
                <svg class="landing-usage-option__arrow" aria-hidden="true" viewBox="0 0 20 20"><path d="m7 4 6 6-6 6" /></svg>
              </button>
              <a class="landing-usage-option landing-usage-option--blue" :href="ANDROID_DOWNLOAD_URL" rel="noopener noreferrer">
                <span class="landing-usage-option__icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24"><path d="M12 3v10M8.5 9.5 12 13l3.5-3.5M6 16v4h12v-4" /></svg>
                </span>
                <span class="landing-usage-option__copy">
                  <strong>Android 安装包</strong>
                  <small>当前公开的原版 APK；新版原生客户端另行公告</small>
                </span>
                <svg class="landing-usage-option__arrow" aria-hidden="true" viewBox="0 0 20 20"><path d="m7 4 6 6-6 6" /></svg>
              </a>
            </div>
            <p class="landing-usage-dialog__footnote">Android 安装时可能需要允许“安装未知来源应用”。论坛、桌面小组件需对应新版客户端。</p>
          </section>
        </div>
      </Transition>
    </Teleport>
  </main>
</template>
