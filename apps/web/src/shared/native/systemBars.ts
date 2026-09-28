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

export interface NativeSystemBarTheme {
  /** 与页面底色一致的色值，用于系统栏背景。 */
  color: string
  /** 深色主题下系统栏图标需要反白。 */
  mode: 'light' | 'dark'
}

export async function setNativeSystemBarTheme({ color, mode }: NativeSystemBarTheme) {
  if (Capacitor.getPlatform() !== 'android') return

  try {
    // SystemBarsStyle 描述的是系统栏图标的明暗：Dark 表示深色背景配浅色图标。
    await SystemBars.setStyle({
      style: mode === 'dark' ? SystemBarsStyle.Dark : SystemBarsStyle.Light,
    })
    await SystemBarBackground.setBackgroundColor({ color })
  } catch (error) {
    console.warn('无法同步 Android 系统栏主题', error)
  }
}
