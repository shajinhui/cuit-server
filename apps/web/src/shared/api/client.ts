import { clientDeviceHeaders } from '@/shared/device/clientDevice'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: number,
    readonly retryAfterSeconds?: number,
  ) {
    super(message)
  }
}

const apiBaseURL = (import.meta.env.VITE_API_BASE_URL || '').replace(/\/$/, '')

export async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const deviceHeaders = await clientDeviceHeaders()
  const response = await fetch(`${apiBaseURL}${path}`, {
    ...options,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      ...deviceHeaders,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    },
  })

  let payload: ApiResponse<T>
  try {
    payload = (await response.json()) as ApiResponse<T>
  } catch {
    throw new ApiError('服务响应格式异常', response.status, 50000)
  }
  if (!response.ok || payload.code !== 0) {
    const retryAfter = Number.parseInt(response.headers.get('Retry-After') ?? '', 10)
    throw new ApiError(
      payload.message || '请求失败',
      response.status,
      payload.code,
      Number.isInteger(retryAfter) && retryAfter > 0 ? retryAfter : undefined,
    )
  }
  return payload.data
}

export async function requestBlob(path: string): Promise<Blob> {
  const deviceHeaders = await clientDeviceHeaders()
  const response = await fetch(`${apiBaseURL}${path}`, {
    credentials: 'include',
    headers: {
      Accept: 'image/*, application/json',
      ...deviceHeaders,
    },
  })
  if (response.ok) return response.blob()

  let message = '请求失败'
  let code = 50000
  try {
    const payload = (await response.json()) as ApiResponse<unknown>
    message = payload.message || message
    code = payload.code
  } catch {
    message = '服务响应格式异常'
  }
  throw new ApiError(message, response.status, code)
}
