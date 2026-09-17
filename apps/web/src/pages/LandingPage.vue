<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import landingCalendar from '@/assets/landing/landing-calendar.webp'
import landingClassrooms from '@/assets/landing/landing-classrooms.webp'
import landingClub from '@/assets/landing/landing-club.webp'
import landingExams from '@/assets/landing/landing-exams.webp'
import landingLibrary from '@/assets/landing/landing-library.webp'
import landingResources from '@/assets/landing/landing-resources.webp'
import landingRun from '@/assets/landing/landing-run.webp'
import landingSchedule from '@/assets/landing/landing-schedule.webp'
import { usePwaInstall } from '@/features/pwa-install'
import { QQ_GROUP_NUMBER, QQ_GROUP_URL } from '@/shared/config/community'
import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'LandingPage' })

const router = useRouter()
const { requestInstall } = usePwaInstall()
const installing = ref(false)
const heroStage = ref<HTMLElement | null>(null)
let revealObserver: IntersectionObserver | undefined
let previousTitle = ''

usePageTheme('#f4f7fb')

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
})

onBeforeUnmount(() => {
  revealObserver?.disconnect()
  document.title = previousTitle
})

function openApp() {
  void router.push({ name: 'login' })
}

async function installApp() {
  if (installing.value) return
  installing.value = true
  await requestInstall()
  installing.value = false
}

function scrollToFeatures() {
  document.querySelector('#landing-features')?.scrollIntoView({ behavior: 'smooth' })
}

function updateHeroPerspective(event: PointerEvent) {
  if (!heroStage.value || event.pointerType === 'touch') return
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
        <RouterLink :to="{ name: 'privacy' }">隐私</RouterLink>
        <a href="https://github.com/shajinhui/cuit-server" target="_blank" rel="noopener noreferrer">GitHub</a>
      </div>
      <button class="landing-nav__open" type="button" @click="openApp">打开网页版</button>
    </nav>

    <section class="landing-hero" aria-labelledby="landing-title">
      <div class="landing-hero__copy">
        <p class="landing-eyebrow landing-hero__item">为成都信息工程大学学生而做</p>
        <h1 id="landing-title" class="landing-hero__item">
          <span class="landing-hero__line">把校园日常，</span>
          <span class="landing-hero__line landing-hero__line--accent">装进一个 App。</span>
        </h1>
        <p class="landing-hero__description landing-hero__item">
          课表、成绩、考试、空教室、图书馆和校园生活，常用信息清楚呈现，需要时一步直达。
        </p>
        <div class="landing-hero__actions landing-hero__item">
          <button class="landing-button landing-button--primary" type="button" @click="openApp">
            立即使用
            <svg aria-hidden="true" viewBox="0 0 20 20"><path d="m7 4 6 6-6 6" /></svg>
          </button>
          <button class="landing-button landing-button--secondary" type="button" :disabled="installing" @click="installApp">
            <svg aria-hidden="true" viewBox="0 0 20 20">
              <path d="M10 3v9M6.5 8.5 10 12l3.5-3.5M4 15.5h12" />
            </svg>
            {{ installing ? '请稍候' : '安装到桌面' }}
          </button>
        </div>
        <p class="landing-hero__note landing-hero__item">支持网页、PWA、Android 与 iPhone / iPad</p>
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
          <img :src="landingLibrary" alt="" />
        </div>
        <div class="landing-phone landing-phone--center">
          <div class="landing-phone__island" aria-hidden="true" />
          <img :src="landingSchedule" alt="成信友友课表页面" />
        </div>
        <div class="landing-phone landing-phone--right" aria-hidden="true">
          <div class="landing-phone__island" />
          <img :src="landingRun" alt="" />
        </div>

        <div class="landing-float-card landing-float-card--schedule" aria-hidden="true">
          <span class="landing-float-card__icon landing-float-card__icon--blue">
            <svg viewBox="0 0 24 24"><path d="M5 4v3M19 4v3M4 9h16M5 6h14v14H5zM8 12h3v3H8z" /></svg>
          </span>
          <div><strong>本周课表</strong><small>随时清楚掌握</small></div>
        </div>
        <div class="landing-float-card landing-float-card--library" aria-hidden="true">
          <span class="landing-float-card__dot" />
          <div><strong>63 个座位可约</strong><small>可视化选座</small></div>
        </div>
        <div class="landing-float-card landing-float-card--sync" aria-hidden="true">
          <span class="landing-float-card__icon landing-float-card__icon--green">
            <svg viewBox="0 0 24 24"><path d="M20 7h-8M16 3l4 4-4 4M4 17h8M8 13l-4 4 4 4" /></svg>
          </span>
          <div><strong>校园数据同步</strong><small>信息保持更新</small></div>
        </div>
      </div>
    </section>

    <section class="landing-trust landing-reveal" aria-label="产品特点">
      <div><strong>一个账号</strong><span>常用校园服务集中查看</span></div>
      <div><strong>多端可用</strong><span>手机、平板与网页自然适配</span></div>
      <div><strong>开源透明</strong><span>代码公开，持续听取反馈</span></div>
    </section>

    <section id="landing-features" class="landing-section landing-section--intro">
      <header class="landing-section-heading landing-reveal">
        <p class="landing-eyebrow">熟悉，但更轻松</p>
        <h2>你的校园信息，<br />应该一眼就懂。</h2>
        <p>延续 App 的卡片、留白与清晰层级，在每一块屏幕上保持自然、安静、好用。</p>
      </header>

      <div class="landing-bento">
        <article class="landing-bento-card landing-bento-card--large landing-reveal">
          <div class="landing-bento-card__copy">
            <span class="landing-feature-icon landing-feature-icon--blue">
              <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M5 4v3M19 4v3M4 9h16M5 6h14v14H5zM8 12h3v3H8z" /></svg>
            </span>
            <p>学习安排</p>
            <h3>课表就在手边，<br />一周节奏自然展开。</h3>
            <span>单双周、课程调整与日历导出，都有自己的位置。</span>
          </div>
          <div class="landing-bento-card__screen landing-bento-card__screen--schedule">
            <img :src="landingSchedule" alt="一周课表界面" loading="lazy" />
          </div>
        </article>

        <article class="landing-bento-card landing-bento-card--calendar landing-reveal">
          <div class="landing-bento-card__copy">
            <span class="landing-feature-icon landing-feature-icon--purple">
              <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M6 3v3M18 3v3M4 8h16v12H4zM8 12h3M13 12h3M8 16h3" /></svg>
            </span>
            <p>校历与考试</p>
            <h3>重要日期，不再散落。</h3>
          </div>
          <div class="landing-dual-preview">
            <img :src="landingCalendar" alt="学校校历页面" loading="lazy" />
            <img :src="landingExams" alt="考试安排页面" loading="lazy" />
          </div>
        </article>

        <article class="landing-bento-card landing-bento-card--classroom landing-reveal">
          <div class="landing-bento-card__copy">
            <span class="landing-feature-icon landing-feature-icon--orange">
              <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M4 19h16M6 19V7l6-3 6 3v12M9 10h2M13 10h2M9 14h2M13 14h2" /></svg>
            </span>
            <p>空教室</p>
            <h3>想自习时，直接找到空位。</h3>
          </div>
          <div class="landing-bento-card__screen landing-bento-card__screen--classroom">
            <img :src="landingClassrooms" alt="空教室查询页面" loading="lazy" />
          </div>
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
          <span class="landing-availability" aria-hidden="true"><i />63 个座位可约</span>
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
          <span class="landing-resource-pill" aria-hidden="true">69 个课程目录</span>
        </div>
        <div class="landing-feature-row__copy">
          <span class="landing-feature-number">02</span>
          <p class="landing-eyebrow">历年试卷</p>
          <h3>复习资料，<br />按课程整齐收好。</h3>
          <p>搜索课程、文件夹或文件名，快速浏览开源课程共享库，让考试周少一点手忙脚乱。</p>
          <ul>
            <li>课程与文件全文搜索</li>
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
        <p>校园跑进度、俱乐部活动与签到状态，一起收进熟悉的 App 体验里。</p>
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

    <section class="landing-platform landing-reveal">
      <div class="landing-platform__copy">
        <p class="landing-eyebrow">随屏幕自然变化</p>
        <h2>手机、平板、网页，<br />依然像同一个 App。</h2>
        <p>竖屏快速查看，横屏高效浏览，大屏留出恰到好处的空间。无论在哪打开，操作方式始终熟悉。</p>
        <button class="landing-button landing-button--primary" type="button" @click="openApp">打开网页版</button>
      </div>
      <div class="landing-platform__devices" aria-hidden="true">
        <div class="landing-browser-frame">
          <div class="landing-browser-frame__bar"><i /><i /><i /><span>fanxiaogao05.dpdns.org</span></div>
          <img :src="landingSchedule" alt="" />
        </div>
        <div class="landing-tablet-frame">
          <img :src="landingLibrary" alt="" />
        </div>
      </div>
    </section>

    <section class="landing-final-cta landing-reveal">
      <img src="/icons/app-icon-192.png" alt="成信友友应用图标" />
      <p class="landing-eyebrow">成信友友</p>
      <h2>让校园生活，<br />从今天开始更顺手。</h2>
      <div class="landing-final-cta__actions">
        <button class="landing-button landing-button--primary" type="button" @click="openApp">立即使用</button>
        <button class="landing-button landing-button--secondary" type="button" :disabled="installing" @click="installApp">安装到桌面</button>
      </div>
      <p>非官方学生项目，与学校及教务系统运营方无隶属或授权关系。</p>
    </section>

    <footer class="landing-footer">
      <RouterLink class="landing-brand" :to="{ name: 'landing' }">
        <img src="/icons/app-icon-192.png" alt="" />
        <span>成信友友</span>
      </RouterLink>
      <p>校园教务与生活助手</p>
      <div>
        <RouterLink :to="{ name: 'privacy' }">隐私政策</RouterLink>
        <a :href="QQ_GROUP_URL" target="_blank" rel="noopener noreferrer">交流群 {{ QQ_GROUP_NUMBER }}</a>
        <a href="https://github.com/shajinhui/cuit-server" target="_blank" rel="noopener noreferrer">GitHub</a>
      </div>
    </footer>
  </main>
</template>
