import { defineStore } from 'pinia'

import { ApiError } from '@/shared/api/client'

import { getSessionStatus, loginJWXT, logoutJWXT } from './api'

type SessionState = 'unknown' | 'anonymous' | 'authenticated' | 'offline'

export const useSessionStore = defineStore('session', {
  state: () => ({
    status: 'unknown' as SessionState,
    loading: false,
    error: '',
  }),
  actions: {
    async check(hasOfflineData: () => Promise<boolean> = async () => false) {
      if (this.status !== 'unknown') return this.status === 'authenticated'
      try {
        const result = await getSessionStatus()
        if (result.authenticated) {
          this.status = 'authenticated'
        } else {
          this.markAnonymous()
        }
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          this.markAnonymous()
        } else {
          // 网络不可用不代表会话已经失效；是否允许离线访问由应用层根据本地业务数据判断。
          this.status = (await hasOfflineData()) ? 'offline' : 'anonymous'
        }
      }
      return this.status === 'authenticated'
    },
    async login(username: string, password: string) {
      this.loading = true
      this.error = ''
      try {
        await loginJWXT(username, password)
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
