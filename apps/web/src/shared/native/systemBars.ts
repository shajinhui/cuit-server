import {
  Capacitor,
  registerPlugin,
  SystemBars,
  SystemBarsStyle,
} from '@capacitor/core'

interface SystemBarBackgroundPlugin {
  setBackgroundColor(options: { color: string }): Promise<void>
}

const SystemBarBackground = registerPlugin<SystemBarBackgroundPlugin>('SystemBarBackground')

export async function setNativeSystemBarTheme(backgroundColor: string) {
  if (Capacitor.getPlatform() !== 'android') return

  try {
    await SystemBars.setStyle({ style: SystemBarsStyle.Light })
    await SystemBarBackground.setBackgroundColor({ color: backgroundColor })
  } catch (error) {
    console.warn('无法同步 Android 系统栏主题', error)
  }
}
