import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'

import { getPlanCompletion, type PlanCompletion } from './api'

export const usePlanCompletionStore = defineStore('plan-completion', {
  state: () => ({
    data: null as PlanCompletion | null,
    loading: false,
    error: '',
  }),
  actions: {
    async load(force = false) {
      if ((this.data && !force) || this.loading) return

      this.loading = true
      this.error = ''
      try {
        this.data = await getPlanCompletion()
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          this.data = null
          useSessionStore().markAnonymous()
        }
        this.error = error instanceof Error ? error.message : '学业完成情况读取失败，请稍后重试'
      } finally {
        this.loading = false
      }
    },
    clearData() {
      this.data = null
      this.loading = false
      this.error = ''
    },
  },
})
