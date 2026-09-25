import { request } from '@/shared/api/client'

import { clearRatingAssetCache } from './assetCache'

interface RatingTokenResponse {
  access_token: string
  token_type: 'Bearer'
  expires_at: string
}

interface ActiveRatingToken {
  value: string
  expiresAt: number
}

let activeToken: ActiveRatingToken | null = null
let tokenRequest: Promise<string> | null = null
let sessionGeneration = 0
const tokenRefreshMargin = 30_000
const channel = typeof BroadcastChannel === 'undefined' ? null : new BroadcastChannel('ratings-auth')

channel?.addEventListener('message', (event: MessageEvent<unknown>) => {
  if (event.data === 'clear') {
    clearRatingAssetCache()
    clearRatingAccessToken()
  }
})

export async function getRatingAccessToken(force = false) {
  if (!force && activeToken && activeToken.expiresAt - tokenRefreshMargin > Date.now()) {
    return activeToken.value
  }
  if (tokenRequest) return tokenRequest

  const requestGeneration = sessionGeneration
  const pending = request<RatingTokenResponse>('/api/v1/auth/ratings-token', { method: 'POST' })
    .then((response) => {
      const expiresAt = new Date(response.expires_at).getTime()
      if (!response.access_token || !Number.isFinite(expiresAt)) {
        throw new Error('评分凭证格式异常')
      }
      if (requestGeneration !== sessionGeneration) throw new Error('账号已切换，请重新操作')
      activeToken = { value: response.access_token, expiresAt }
      return response.access_token
    })
    .finally(() => {
      if (tokenRequest === pending) tokenRequest = null
    })
  tokenRequest = pending
  return pending
}

export function currentRatingAccessToken() {
  return activeToken?.value ?? ''
}

export function hasUsableRatingAccessToken() {
  return Boolean(activeToken && activeToken.expiresAt - tokenRefreshMargin > Date.now())
}

export function clearRatingAccessToken(broadcast = false) {
  activeToken = null
  tokenRequest = null
  sessionGeneration += 1
  if (broadcast) channel?.postMessage('clear')
}

export function currentRatingSessionGeneration() {
  return sessionGeneration
}

export function currentRatingAssetScope() {
  const token = activeToken?.value ?? ''
  const payload = token.split('.')[1]
  if (!payload) return 'anonymous'
  try {
    const normalized = payload.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (payload.length % 4)) % 4)
    const claims = JSON.parse(atob(normalized)) as { sub?: unknown }
    return typeof claims.sub === 'string' && claims.sub ? claims.sub : 'anonymous'
  } catch {
    return 'anonymous'
  }
}
