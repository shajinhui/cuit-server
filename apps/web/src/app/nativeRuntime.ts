import { App } from '@capacitor/app'
import { Capacitor } from '@capacitor/core'

export function registerNativeRuntime() {
  if (!Capacitor.isNativePlatform()) return

  void App.addListener('backButton', ({ canGoBack }) => {
    if (canGoBack) {
      window.history.back()
      return
    }
    void App.minimizeApp()
  })
}
