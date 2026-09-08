import { Capacitor } from '@capacitor/core'

export type CalendarShareResult = 'shared' | 'downloaded'

export async function shareCalendarFile(
  content: string,
  fileName: string,
  title: string,
): Promise<CalendarShareResult> {
  if (Capacitor.isNativePlatform()) {
    return shareNativeCalendarFile(content, fileName, title)
  }

  const file = new File([content], fileName, { type: 'text/calendar;charset=utf-8' })
  const canShareFile =
    typeof navigator.share === 'function' &&
    typeof navigator.canShare === 'function' &&
    navigator.canShare({ files: [file] })

  if (canShareFile) {
    try {
      await navigator.share({ files: [file], title })
      return 'shared'
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') throw error
    }
  }

  downloadCalendarFile(file, fileName)
  return 'downloaded'
}

async function shareNativeCalendarFile(
  content: string,
  fileName: string,
  title: string,
): Promise<CalendarShareResult> {
  const [{ Directory, Encoding, Filesystem }, { Share }] = await Promise.all([
    import('@capacitor/filesystem'),
    import('@capacitor/share'),
  ])
  const path = `calendar/${fileName}`
  const written = await Filesystem.writeFile({
    path,
    data: content,
    directory: Directory.Cache,
    encoding: Encoding.UTF8,
    recursive: true,
  })

  try {
    await Share.share({
      title,
      dialogTitle: '导入系统日历',
      files: [written.uri],
    })
    return 'shared'
  } finally {
    await Filesystem.deleteFile({ path, directory: Directory.Cache }).catch(() => undefined)
  }
}

function downloadCalendarFile(file: File, fileName: string) {
  const url = URL.createObjectURL(file)
  const link = document.createElement('a')
  link.href = url
  link.download = fileName
  link.style.display = 'none'
  document.body.append(link)
  link.click()
  link.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 1_000)
}
