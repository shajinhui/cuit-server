import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'org.dpdns.fanxiaogao05.chengxinyouyou',
  appName: '成信友友',
  webDir: 'dist',
  server: {
    // 与正式 Web 站点保持同站，现有的 Secure + SameSite=Lax 会话 Cookie 才能继续访问 API 子域名。
    hostname: 'fanxiaogao05.dpdns.org',
    androidScheme: 'https',
    iosScheme: 'capacitor',
  },
  ios: {
    preferredContentMode: 'mobile',
    includePlugins: [
      '@capacitor/app',
      '@capacitor/device',
      '@capacitor/filesystem',
      '@capacitor/share',
    ],
  },
  plugins: {
    // iOS 本地资源使用 capacitor://，由原生 HTTP 处理 API 请求和 HttpOnly Cookie，
    // 避免 WebView 的跨源限制阻断登录会话。
    CapacitorHttp: {
      enabled: true,
    },
    CapacitorCookies: {
      enabled: true,
    },
    CapacitorUpdater: {
      autoUpdate: 'off',
      appReadyTimeout: 10_000,
      autoDeleteFailed: true,
      autoDeletePrevious: true,
      resetWhenUpdate: true,
      statsUrl: '',
    },
    SystemBars: {
      insetsHandling: 'css',
      style: 'LIGHT',
    },
  },
}

export default config
