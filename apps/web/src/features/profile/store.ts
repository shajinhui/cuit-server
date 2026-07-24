import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'

import { getStudentProfile, type StudentProfile } from './api'
import { readProfileCache, writeProfileCache } from './cache'

export const useProfileStore = defineStore('profile', {
  state: () => ({
    profile: null as StudentProfile | null,
    loading: false,
    error: '',
  }),
  actions: {
    async load(force = false) {
      if ((this.profile && !force) || this.loading) return

      this.loading = true
      this.error = ''
      const cached = force ? null : await readProfileCache().catch(() => null)
      if (cached) this.profile = cached.profile

      try {
        const profile = await getStudentProfile()
        this.profile = profile
        await writeProfileCache(profile).catch(() => undefined)
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          this.profile = null
          useSessionStore().markAnonymous()
        }
        this.error = error instanceof Error ? error.message : '个人信息读取失败，请稍后重试'
      } finally {
        this.loading = false
      }
    },
    clearData() {
      this.profile = null
      this.loading = false
      this.error = ''
    },
  },
})
