import { Capacitor } from '@capacitor/core'

import { parsePastExamsIndex, pastExamFileProxyPath, type PastExamFile } from './model'

export const DEFAULT_NATIVE_PAST_EXAMS_ORIGIN = 'https://cuit-server.pages.dev'

let cachedIndex: ReturnType<typeof parsePastExamsIndex> | undefined

export async function loadPastExamsIndex(signal?: AbortSignal) {
  if (cachedIndex) return cachedIndex

  const indexURL = `${import.meta.env.BASE_URL}past-exams/index.json`
  let response: Response
  try {
    response = await fetch(indexURL, { cache: 'force-cache', signal })
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') throw error
    throw new Error('无法读取资料目录，请检查网络后重试', { cause: error })
  }
  if (!response.ok) throw new Error(`资料目录读取失败（${response.status}）`)

  let body: unknown
  try {
    body = await response.json()
  } catch {
    throw new Error('资料目录格式不正确')
  }
  cachedIndex = parsePastExamsIndex(body)
  return cachedIndex
}

export function pastExamFileURL(commit: string, file: Pick<PastExamFile, 'path'>) {
  const configuredOrigin = (import.meta.env.VITE_PAST_EXAMS_PROXY_BASE_URL || '').replace(/\/$/, '')
  const origin = configuredOrigin || (Capacitor.isNativePlatform() ? DEFAULT_NATIVE_PAST_EXAMS_ORIGIN : '')
  return `${origin}${pastExamFileProxyPath(commit, file.path)}?view=1`
}

export function pastExamFileDownloadURL(commit: string, file: Pick<PastExamFile, 'path'>) {
  const configuredOrigin = (import.meta.env.VITE_PAST_EXAMS_PROXY_BASE_URL || '').replace(/\/$/, '')
  const origin = configuredOrigin || (Capacitor.isNativePlatform() ? DEFAULT_NATIVE_PAST_EXAMS_ORIGIN : '')
  return `${origin}${pastExamFileProxyPath(commit, file.path)}?download=1`
}
