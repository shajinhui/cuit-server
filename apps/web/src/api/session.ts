import { request } from './client'

export interface SessionStatus {
  authenticated: boolean
}

export function loginJWXT(username: string, password: string, remember: boolean) {
  return request<SessionStatus>('/api/v1/jwxt/session', {
    method: 'POST',
    body: JSON.stringify({ username, password, remember }),
  })
}

export function getSessionStatus() {
  return request<SessionStatus>('/api/v1/jwxt/session')
}

export function logoutJWXT() {
  return request<SessionStatus>('/api/v1/jwxt/session', { method: 'DELETE' })
}
