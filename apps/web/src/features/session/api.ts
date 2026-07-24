import { request } from '@/shared/api/client'

interface SessionStatus {
  authenticated: boolean
}

export function loginJWXT(username: string, password: string) {
  return request<SessionStatus>('/api/v1/jwxt/session', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  })
}

export function getSessionStatus() {
  return request<SessionStatus>('/api/v1/jwxt/session')
}

export function logoutJWXT() {
  return request<SessionStatus>('/api/v1/jwxt/session', { method: 'DELETE' })
}
