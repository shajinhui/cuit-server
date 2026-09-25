import { createRouter, createWebHistory } from 'vue-router'

import {
  checkSession,
  restoreOfflineAccess,
  restoreScheduleOfflineAccess,
} from '@/app/sessionLifecycle'
import { hasUsableRatingAccessToken } from '@/features/ratings'
import { useSessionStore } from '@/features/session'
import SchedulePage from '@/pages/SchedulePage.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      redirect: { name: 'schedule' },
    },
    {
      path: '/official',
      name: 'landing',
      component: () => import('@/pages/LandingPage.vue'),
    },
    { path: '/login', name: 'login', component: () => import('@/pages/LoginPage.vue') },
    {
      path: '/schedule',
      name: 'schedule',
      component: SchedulePage,
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
      path: '/ratings',
      name: 'ratings',
      component: () => import('@/pages/RatingsPage.vue'),
      meta: { requiresAuth: true, ratingAuth: true },
    },
    {
      path: '/ratings/new',
      name: 'rating-create-board',
      component: () => import('@/pages/RatingEditorPage.vue'),
      meta: { requiresAuth: true, ratingAuth: true },
    },
    {
      path: '/ratings/mine',
      name: 'ratings-mine',
      component: () => import('@/pages/RatingsMinePage.vue'),
      meta: { requiresAuth: true, ratingAuth: true },
    },
    {
      path: '/ratings/boards/:boardId',
      name: 'rating-board',
      component: () => import('@/pages/RatingBoardPage.vue'),
      meta: { requiresAuth: true, ratingAuth: true },
    },
    {
      path: '/ratings/boards/:boardId/items/new',
      name: 'rating-create-item',
      component: () => import('@/pages/RatingEditorPage.vue'),
      meta: { requiresAuth: true, ratingAuth: true },
    },
    {
      path: '/ratings/items/:itemId',
      name: 'rating-item',
      component: () => import('@/pages/RatingItemPage.vue'),
      meta: { requiresAuth: true, ratingAuth: true },
    },
    {
      path: '/about',
      name: 'about',
      component: () => import('@/pages/AboutPage.vue'),
    },
    {
      path: '/privacy',
      name: 'privacy',
      component: () => import('@/pages/PrivacyPage.vue'),
    },
    {
      path: '/feedback',
      name: 'feedback',
      component: () => import('@/pages/FeedbackPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/ratings',
      name: 'admin-ratings',
      component: () => import('@/pages/RatingAdminPage.vue'),
      meta: { requiresAuth: true, ratingAuth: true },
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
    {
      path: '/past-exams',
      name: 'past-exams',
      component: () => import('@/pages/PastExamsPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/library',
      name: 'library',
      component: () => import('@/pages/LibraryPage.vue'),
      meta: { requiresAuth: true },
    },
  ],
  scrollBehavior: (to, _from, savedPosition) => {
    if (savedPosition && (to.meta.ratingAuth || to.path.startsWith('/ratings'))) return savedPosition
    return { top: 0 }
  },
})

let backgroundSessionVerification: Promise<void> | undefined

router.beforeEach(async (to) => {
  const session = useSessionStore()
  const needsSession = to.name === 'login' || Boolean(to.meta.requiresAuth)
  if (!needsSession) return true
  if (to.meta.ratingAuth && hasUsableRatingAccessToken()) return true

  if (session.status === 'unknown') {
    const canStartOffline =
      to.name === 'schedule' ? await restoreScheduleOfflineAccess() : await restoreOfflineAccess()
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
      if (currentRoute.meta.ratingAuth && hasUsableRatingAccessToken()) return

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
