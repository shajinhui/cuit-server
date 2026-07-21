import { fileURLToPath, URL } from 'node:url'

import vue from '@vitejs/plugin-vue'
import { defineConfig, loadEnv } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [
      vue(),
      VitePWA({
        registerType: 'autoUpdate',
        includeAssets: ['icons/app-icon-192.png', 'icons/app-icon-512.png'],
        manifest: {
          id: '/',
          name: '成信校园助手',
          short_name: '校园助手',
          description: '课表、成绩与校园服务助手',
          lang: 'zh-CN',
          theme_color: '#75b82a',
          background_color: '#fbfcf9',
          display: 'standalone',
          display_override: ['standalone'],
          orientation: 'portrait',
          start_url: '/',
          icons: [
            {
              src: '/icons/app-icon-192.png',
              sizes: '192x192',
              type: 'image/png',
              purpose: 'any',
            },
            {
              src: '/icons/app-icon-512.png',
              sizes: '512x512',
              type: 'image/png',
              purpose: 'any maskable',
            },
          ],
        },
        devOptions: {
          enabled: true,
        },
        workbox: {
          globPatterns: ['**/*.{js,css,html,svg,webp,woff,woff2}', 'assets/**/*.png'],
          navigateFallbackDenylist: [/^\/api\//],
        },
      }),
    ],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
    server: {
      host: '127.0.0.1',
      port: 5173,
      proxy: {
        '/api': {
          target: env.VITE_DEV_API_TARGET || 'http://127.0.0.1:8888',
          changeOrigin: true,
        },
      },
    },
  }
})
