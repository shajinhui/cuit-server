import { clientDeviceHeaders } from '@/shared/device/clientDevice'

import {
  clearRatingAccessToken,
  currentRatingSessionGeneration,
  getRatingAccessToken,
} from './auth'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export class RatingsApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: number,
  ) {
    super(message)
  }
}

const apiBaseURL = (import.meta.env.VITE_RATINGS_API_BASE_URL || '').replace(/\/$/, '')

export async function ratingsRequest<T>(
  path: string,
  options: RequestInit = {},
  retryAuthentication = true,
): Promise<T> {
  if (!apiBaseURL) throw new RatingsApiError('评分服务尚未配置', 503, 50300)

  const token = await getRatingAccessToken()
  const generation = currentRatingSessionGeneration()
  const deviceHeaders = await clientDeviceHeaders()
  const response = await fetch(`${apiBaseURL}${path}`, {
    ...options,
    credentials: 'omit',
    headers: {
      Accept: 'application/json',
      ...deviceHeaders,
      Authorization: `Bearer ${token}`,
      ...(options.body && !(options.body instanceof FormData)
        ? { 'Content-Type': 'application/json' }
        : {}),
      ...options.headers,
    },
  })
  if (generation !== currentRatingSessionGeneration()) {
    throw new RatingsApiError('账号已切换，请重新操作', 409, 40907)
  }

  if (response.status === 401 && retryAuthentication) {
    clearRatingAccessToken()
    await getRatingAccessToken(true)
    return ratingsRequest<T>(path, options, false)
  }

  const payload = await readPayload<T>(response)
  if (!response.ok || payload.code !== 0) {
    throw new RatingsApiError(payload.message || '请求失败', response.status, payload.code)
  }
  return payload.data
}

export async function ratingsBlob(path: string) {
  if (!apiBaseURL) throw new RatingsApiError('评分服务尚未配置', 503, 50300)
  const token = await getRatingAccessToken()
  const generation = currentRatingSessionGeneration()
  const response = await fetch(`${apiBaseURL}${path}`, {
    credentials: 'omit',
    headers: { Accept: 'image/*', Authorization: `Bearer ${token}` },
  })
  if (generation !== currentRatingSessionGeneration()) {
    throw new RatingsApiError('账号已切换，请重新操作', 409, 40907)
  }
  if (response.status === 401) {
    clearRatingAccessToken()
    const refreshedToken = await getRatingAccessToken(true)
    const refreshedGeneration = currentRatingSessionGeneration()
    const retried = await fetch(`${apiBaseURL}${path}`, {
      credentials: 'omit',
      headers: { Accept: 'image/*', Authorization: `Bearer ${refreshedToken}` },
    })
    if (refreshedGeneration !== currentRatingSessionGeneration()) {
      throw new RatingsApiError('账号已切换，请重新操作', 409, 40907)
    }
    if (retried.ok) return retried.blob()
    throw await responseError(retried)
  }
  if (!response.ok) throw await responseError(response)
  return response.blob()
}

export async function revokeRatingToken(token: string) {
  if (!apiBaseURL || !token) return
  await fetch(`${apiBaseURL}/api/v1/ratings/auth/logout`, {
    method: 'POST',
    credentials: 'omit',
    headers: { Accept: 'application/json', Authorization: `Bearer ${token}` },
  })
}

async function readPayload<T>(response: Response): Promise<ApiResponse<T>> {
  try {
    return (await response.json()) as ApiResponse<T>
  } catch {
    throw new RatingsApiError('评分服务响应格式异常', response.status, 50000)
  }
}

async function responseError(response: Response) {
  try {
    const payload = (await response.json()) as ApiResponse<unknown>
    return new RatingsApiError(payload.message || '请求失败', response.status, payload.code)
  } catch {
    return new RatingsApiError('请求失败', response.status, 50000)
  }
}
