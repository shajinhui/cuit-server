// 临时预览入口：打印导航栏的真实 DOM 结构与 class 落点。验证完即删除。
import { createApp, h } from 'vue'
import { createMemoryHistory, createRouter } from 'vue-router'

import BottomNavigation from '@/app/components/BottomNavigation.vue'
import './styles/main.css'

const blank = { render: () => h('div') }

const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/', name: 'schedule', component: blank },
    { path: '/tools', name: 'tools', component: blank },
    { path: '/profile', name: 'profile', component: blank },
  ],
})

const app = createApp({ render: () => h(BottomNavigation) })
app.use(router)
void router.isReady().then(() => {
  app.mount('#app')
  requestAnimationFrame(() => {
    const q = (sel: string) => document.querySelector<HTMLElement>(sel)
    const box = (el: HTMLElement | null) => {
      if (!el) return null
      const r = el.getBoundingClientRect()
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) }
    }
    const warp = q('.glass__warp')
    const glass = q('.glass')
    const parent = glass?.parentElement ?? null
    const pre = document.createElement('pre')
    pre.id = 'probe'
    pre.textContent = JSON.stringify(
      {
        viewport: [innerWidth, innerHeight],
        nav: box(q('.bottom-navigation')),
        glassWrap: box(q('.bottom-navigation__glass')),
        glass: box(glass),
        warp: box(warp),
        warpStyle: warp
          ? {
              backdropFilter: getComputedStyle(warp).backdropFilter,
              filter: getComputedStyle(warp).filter,
              opacity: getComputedStyle(warp).opacity,
            }
          : null,
        glassParent: parent
          ? {
              box: box(parent),
              position: getComputedStyle(parent).position,
              top: getComputedStyle(parent).top,
              left: getComputedStyle(parent).left,
              transform: getComputedStyle(parent).transform,
            }
          : null,
      },
      null,
      1,
    )
    document.body.appendChild(pre)
  })
})
