import { onBeforeUnmount, onMounted } from 'vue'

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
  })

  onBeforeUnmount(() => {
    document
      .querySelector<HTMLMetaElement>('meta[name="theme-color"]')
      ?.setAttribute('content', previousThemeColor || defaultThemeColor)
    document.documentElement.style.backgroundColor = previousHtmlBackground
    document.body.style.backgroundColor = previousBodyBackground
  })
}
