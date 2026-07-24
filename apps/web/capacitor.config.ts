import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'org.dpdns.fanxiaogao05.chengxinyouyou',
  appName: '成信友友',
  webDir: 'dist',
  server: {
    // 与正式 Web 站点保持同站，现有的 Secure + SameSite=Lax 会话 Cookie 才能继续访问 API 子域名。
    hostname: 'fanxiaogao05.dpdns.org',
    androidScheme: 'https',
  },
  plugins: {
    SystemBars: {
      insetsHandling: 'css',
      style: 'LIGHT',
    },
  },
}

export default config
