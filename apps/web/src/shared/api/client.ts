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
  const response = await fetch(`${apiBaseURL}${path}`, {
    ...options,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
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
