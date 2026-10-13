import type { RuntimeCaching } from 'workbox-build'

export function isOfficialPagePath(pathname: string): boolean {
  return pathname === '/official' || pathname === '/official/'
}

// Workbox 的导航匹配包含查询参数；官网与下载入口不能回落到缓存的应用入口。
export const freshNavigationPatterns = [
  /^\/official(?:[/?]|$)/,
  /^\/downloads\/android(?:[/?]|$)/,
]

export const freshSiteRuntimeCaching = [
  {
    // 回调会序列化到 Service Worker，必须独立于本模块的其他变量。
    urlPattern: ({ url }: { url: URL }) => /^\/(?:official|downloads\/android)\/?$/.test(url.pathname),
    handler: 'NetworkOnly',
    options: { fetchOptions: { cache: 'no-store' } },
  },
] satisfies RuntimeCaching[]
