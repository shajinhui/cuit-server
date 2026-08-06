import { defineStore } from 'pinia'

import { useSessionStore } from '@/features/session'
import { ApiError } from '@/shared/api/client'

import { getStudentProfile, type StudentProfile } from './api'
import { randomPresetAvatarId, createSquareAvatar, presetAvatarById, presetAvatars } from './avatar'
import { readAvatarCache, writeAvatarCache, type AvatarKind, type CachedAvatar } from './avatarCache'
import { readProfileCache, writeProfileCache } from './cache'

export interface ActiveAvatar {
  kind: AvatarKind
  presetId: number | null
  src: string
}

export const useProfileStore = defineStore('profile', {
  state: () => ({
    profile: null as StudentProfile | null,
    avatar: null as ActiveAvatar | null,
    avatarSaving: false,
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
    async loadAvatar() {
      if (this.avatar) return

      const cached = await readAvatarCache().catch(() => null)
      this.avatar = cached ? activeAvatarFromCache(cached) : null
      if (this.avatar) return

      // 首次进入“我的”时随机分配一个默认头像并保存在本机，后续选择会覆盖它。
      await this.selectPresetAvatar(randomPresetAvatarId())
    },
    async selectPresetAvatar(presetId: number, options: { persist?: boolean } = {}) {
      const preset = presetAvatarById(presetId)
      if (!preset) return

      this.revokeCustomAvatarUrl()
      this.avatar = { kind: 'preset', presetId: preset.id, src: preset.src }
      if (options.persist === false) return
      await this.persistAvatar({ kind: 'preset', presetId: preset.id, blob: null })
    },
    async setCustomAvatar(file: File) {
      if (this.avatarSaving) return
      this.avatarSaving = true
      try {
        const blob = await createSquareAvatar(file)
        const url = URL.createObjectURL(blob)
        this.revokeCustomAvatarUrl()
        this.avatar = { kind: 'custom', presetId: null, src: url }
        await this.persistAvatar({ kind: 'custom', presetId: null, blob })
      } finally {
        this.avatarSaving = false
      }
    },
    async persistAvatar(avatar: Omit<CachedAvatar, 'version' | 'updatedAt'>) {
      await writeAvatarCache({
        ...avatar,
        version: 1,
        updatedAt: Date.now(),
      }).catch(() => undefined)
    },
    clearData() {
      this.revokeCustomAvatarUrl()
      this.avatar = null
      this.avatarSaving = false
      this.profile = null
      this.loading = false
      this.error = ''
    },
    revokeCustomAvatarUrl() {
      if (this.avatar?.kind === 'custom' && this.avatar.src.startsWith('blob:')) {
        URL.revokeObjectURL(this.avatar.src)
      }
    },
  },
})

function activeAvatarFromCache(cached: CachedAvatar): ActiveAvatar {
  if (cached.kind === 'preset') {
    return {
      kind: 'preset',
      presetId: cached.presetId,
      src: presetAvatarById(cached.presetId ?? 0)?.src ?? (presetAvatars[0]?.src ?? ''),
    }
  }
  return { kind: 'custom', presetId: null, src: URL.createObjectURL(cached.blob as Blob) }
}
