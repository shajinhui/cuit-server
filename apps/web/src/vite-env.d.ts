/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string
  readonly VITE_ANDROID_UPDATE_MANIFEST_URL?: string
  readonly VITE_AUTORUN_API_BASE_URL?: string
  readonly VITE_PAST_EXAMS_PROXY_BASE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
