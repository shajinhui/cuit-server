import { createRouter, createWebHistory } from 'vue-router'

import { checkSession, restoreOfflineAccess } from '@/app/sessionLifecycle'
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
      path: '/about',
      name: 'about',
      component: () => import('@/pages/AboutPage.vue'),
    },
    {
      path: '/admin/stats',
      name: 'admin-stats',
      component: () => import('@/pages/AdminStatsPage.vue'),
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

let backgroundSessionVerification: Promise<void> | undefined

router.beforeEach(async (to) => {
  const session = useSessionStore()
  const needsSession = to.name === 'login' || Boolean(to.meta.requiresAuth)
  if (!needsSession) return true

  if (session.status === 'unknown') {
    const canStartOffline = await restoreOfflineAccess()
    if (canStartOffline) {
      verifySessionInBackground()
    } else {
      await checkSession()
    }
  }

  const authenticated = session.status === 'authenticated'
  const canReadOfflineData = session.status === 'offline'
  if (to.name === 'login' && (authenticated || canReadOfflineData)) {
    return { name: 'schedule' }
  }
  if (to.meta.requiresAuth && !authenticated && !canReadOfflineData) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

function verifySessionInBackground() {
  if (backgroundSessionVerification) return

  backgroundSessionVerification = checkSession(true)
    .then(async () => {
      const session = useSessionStore()
      if (session.status !== 'anonymous') return

      await router.isReady()
      const currentRoute = router.currentRoute.value
      if (!currentRoute.meta.requiresAuth) return

      await router.replace({
        name: 'login',
        query: { redirect: currentRoute.fullPath },
      })
    })
    .finally(() => {
      backgroundSessionVerification = undefined
    })
}

export default router
