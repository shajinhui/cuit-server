import { onBeforeUnmount, onMounted } from 'vue'

import { setNativeSystemBarTheme } from '@/shared/native/systemBars'

const defaultThemeColor = '#fbfcf9'

export function usePageTheme(backgroundColor: string) {
  let previousThemeColor = ''
  let previousHtmlBackground = ''
  let previousBodyBackground = ''

  onMounted(() => {
    const theme = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
    previousThemeColor = theme?.content ?? ''
    previousHtmlBackground = document.documentElement.style.backgroundColor
    previousBodyBackground = document.body.style.backgroundColor
    theme?.setAttribute('content', backgroundColor)
    document.documentElement.style.backgroundColor = backgroundColor
    document.body.style.backgroundColor = backgroundColor
    void setNativeSystemBarTheme(backgroundColor)
  })

  onBeforeUnmount(() => {
    const restoredThemeColor = previousThemeColor || defaultThemeColor
    document
      .querySelector<HTMLMetaElement>('meta[name="theme-color"]')
      ?.setAttribute('content', restoredThemeColor)
    document.documentElement.style.backgroundColor = previousHtmlBackground
    document.body.style.backgroundColor = previousBodyBackground
    void setNativeSystemBarTheme(restoredThemeColor)
  })
}
