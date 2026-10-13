import { LATEST_ANDROID_APK_URL } from '../../src/shared/config/downloads'

// 固定下载入口不缓存跳转结果，不代理 APK 正文，也不接受请求参数指定跳转地址。
export function onRequestGet(): Response {
  return new Response(null, {
    status: 302,
    headers: {
      Location: LATEST_ANDROID_APK_URL,
      'Cache-Control': 'no-store, max-age=0',
      'X-Content-Type-Options': 'nosniff',
    },
  })
}

export const onRequestHead = onRequestGet
