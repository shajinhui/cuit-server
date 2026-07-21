import { createRouter, createWebHistory } from 'vue-router'

import { useSessionStore } from '@/stores/session'
import GradesView from '@/views/GradesView.vue'
import LoginView from '@/views/LoginView.vue'
import ProfileView from '@/views/ProfileView.vue'
import ScheduleView from '@/views/ScheduleView.vue'
import ToolsView from '@/views/ToolsView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/schedule' },
    { path: '/login', name: 'login', component: LoginView },
    { path: '/schedule', name: 'schedule', component: ScheduleView, meta: { requiresAuth: true } },
    { path: '/tools', name: 'tools', component: ToolsView, meta: { requiresAuth: true } },
    { path: '/profile', name: 'profile', component: ProfileView, meta: { requiresAuth: true } },
    { path: '/grades', name: 'grades', component: GradesView, meta: { requiresAuth: true } },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const session = useSessionStore()
  const authenticated = await session.check()
  if (to.name === 'login' && authenticated) {
    return { name: 'schedule' }
  }
  if (to.meta.requiresAuth && !authenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router
