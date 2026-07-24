import { createRouter, createWebHistory } from 'vue-router'

import { checkSession } from '@/app/sessionLifecycle'
import { useSessionStore } from '@/features/session'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/schedule' },
    { path: '/login', name: 'login', component: () => import('@/pages/LoginPage.vue') },
    {
      path: '/schedule',
      name: 'schedule',
      component: () => import('@/pages/SchedulePage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/tools',
      name: 'tools',
      component: () => import('@/pages/ToolsPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/profile',
      name: 'profile',
      component: () => import('@/pages/ProfilePage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/plan-completion',
      name: 'plan-completion',
      component: () => import('@/pages/PlanCompletionPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/classrooms',
      name: 'classrooms',
      component: () => import('@/pages/ClassroomsPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/exams',
      name: 'exams',
      component: () => import('@/pages/ExamsPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/grades',
      name: 'grades',
      component: () => import('@/pages/GradesPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/calendar',
      name: 'calendar',
      component: () => import('@/pages/CalendarPage.vue'),
    },
    {
      path: '/campus-map',
      name: 'campus-map',
      component: () => import('@/pages/CampusMapPage.vue'),
    },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const session = useSessionStore()
  const authenticated = await checkSession()
  const canReadOfflineData = session.status === 'offline'
  if (to.name === 'login' && (authenticated || canReadOfflineData)) {
    return { name: 'schedule' }
  }
  if (to.meta.requiresAuth && !authenticated && !canReadOfflineData) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router
