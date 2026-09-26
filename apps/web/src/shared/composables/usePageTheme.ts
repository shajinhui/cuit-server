import { onBeforeUnmount, onMounted } from 'vue'

import { setNativeSystemBarTheme } from '@/shared/native/systemBars'

const defaultThemeColor = '#fbfcf9'

export function usePageTheme(backgroundColor: string) {
  let previousThemeColor = ''
  let previousHtmlBackground = ''
  let previousBodyBackground = ''
  let previousStatusStripColor = ''

  onMounted(() => {
    const theme = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
    const statusStrip = document.querySelector<HTMLElement>('#ios-pwa-status-strip')
    previousThemeColor = theme?.content ?? ''
    previousHtmlBackground = document.documentElement.style.backgroundColor
    previousBodyBackground = document.body.style.backgroundColor
    previousStatusStripColor = statusStrip?.style.backgroundColor ?? ''
    theme?.setAttribute('content', backgroundColor)
    document.documentElement.style.backgroundColor = backgroundColor
    document.body.style.backgroundColor = backgroundColor
    statusStrip?.style.setProperty('background-color', backgroundColor)
    void setNativeSystemBarTheme(backgroundColor)
  })

  onBeforeUnmount(() => {
    const restoredThemeColor = previousThemeColor || defaultThemeColor
    const statusStrip = document.querySelector<HTMLElement>('#ios-pwa-status-strip')
    document
      .querySelector<HTMLMetaElement>('meta[name="theme-color"]')
      ?.setAttribute('content', restoredThemeColor)
    document.documentElement.style.backgroundColor = previousHtmlBackground
    document.body.style.backgroundColor = previousBodyBackground
    if (previousStatusStripColor) {
      statusStrip?.style.setProperty('background-color', previousStatusStripColor)
    } else {
      statusStrip?.style.removeProperty('background-color')
    }
    void setNativeSystemBarTheme(restoredThemeColor)
  })
}
