import { defineStore } from 'pinia'

import { getSessionStatus, loginJWXT, logoutJWXT } from '@/api/session'

type SessionState = 'unknown' | 'anonymous' | 'authenticated'

export const useSessionStore = defineStore('session', {
  state: () => ({
    status: 'unknown' as SessionState,
    loading: false,
    error: '',
  }),
  actions: {
    async check() {
      if (this.status !== 'unknown') return this.status === 'authenticated'
      try {
        const result = await getSessionStatus()
        this.status = result.authenticated ? 'authenticated' : 'anonymous'
      } catch {
        this.status = 'anonymous'
      }
      return this.status === 'authenticated'
    },
    async login(username: string, password: string, remember: boolean) {
      this.loading = true
      this.error = ''
      try {
        await loginJWXT(username, password, remember)
        this.status = 'authenticated'
      } catch (error) {
        this.status = 'anonymous'
        this.error = error instanceof Error ? error.message : '登录失败，请稍后重试'
        throw error
      } finally {
        this.loading = false
      }
    },
    async logout() {
      try {
        await logoutJWXT()
      } finally {
        this.markAnonymous()
      }
    },
    markAuthenticated() {
      this.status = 'authenticated'
      this.error = ''
    },
    markAnonymous() {
      this.status = 'anonymous'
      this.error = ''
    },
  },
})
