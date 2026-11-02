import { defineStore } from 'pinia'
import { onScopeDispose, ref } from 'vue'
import { onRatingSessionCleared } from '@/features/ratings/auth'
import { RatingsApiError } from '@/features/ratings/client'
import { getCommunityProfile, updateCommunityProfile, type CommunityProfile } from './api'

export const useCommunityStore = defineStore('community', () => {
  const profile = ref<CommunityProfile | null>(null)
  const loading = ref(false)
  const error = ref('')
  const supported = ref<boolean | null>(null)
  let generation = 0
  let attempted = false
  let pending: Promise<void> | undefined

  function clear() {
    generation++
    profile.value = null
    loading.value = false
    error.value = ''
    supported.value = null
    attempted = false
    pending = undefined
  }
  onScopeDispose(onRatingSessionCleared(clear))

  function load(force = false): Promise<void> {
    if (pending) return pending
    if (attempted && !force) return Promise.resolve()
    attempted = true
    const requestGeneration = generation
    loading.value = true
    error.value = ''
    const task = getCommunityProfile().then(value => {
      if (requestGeneration !== generation) return
      profile.value = value
      supported.value = true
    }).catch(reason => {
      if (requestGeneration !== generation) return
      if (reason instanceof RatingsApiError && reason.status === 404) {
        supported.value = false
        error.value = '社区资料服务尚未上线，请稍后再试'
      } else error.value = reason instanceof Error ? reason.message : '公开资料读取失败'
    }).finally(() => {
      if (requestGeneration === generation) loading.value = false
      if (pending === task) pending = undefined
    })
    pending = task
    return task
  }

  async function save(input: { display_name: string; avatar_preset: number; avatar_asset_id: string | null }) {
    if (!profile.value) throw new Error('请先加载公开资料')
    const requestGeneration = generation
    const updated = await updateCommunityProfile({ ...input, expected_version: profile.value.profile_version })
    if (requestGeneration !== generation) throw new Error('登录状态已变化，请重新操作')
    profile.value = updated
  }
  return { profile, loading, error, supported, load, save, clear }
})
