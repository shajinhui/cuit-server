import { Capacitor } from '@capacitor/core'

export type PastExamDownloadResult = 'downloaded' | 'shared'

export async function downloadPastExamFile(
  url: string,
  fileName: string,
  signal?: AbortSignal,
): Promise<PastExamDownloadResult> {
  if (Capacitor.isNativePlatform()) {
    return downloadAndShareNativeFile(url, fileName)
  }

  if (isIOSWebDevice()) {
    return downloadAndShareIOSFile(url, fileName, signal)
  }

  startBrowserDownload(url, fileName)
  return 'downloaded'
}

export function isIOSWebDevice(
  userAgent = navigator.userAgent,
  platform = navigator.platform,
  maxTouchPoints = navigator.maxTouchPoints,
) {
  return /iPad|iPhone|iPod/i.test(userAgent) || (platform === 'MacIntel' && maxTouchPoints > 1)
}

async function downloadAndShareNativeFile(
  url: string,
  fileName: string,
): Promise<PastExamDownloadResult> {
  const [{ Directory, Filesystem }, { Share }] = await Promise.all([
    import('@capacitor/filesystem'),
    import('@capacitor/share'),
  ])
  const path = `past-exams/${Date.now()}-${safeCacheFileName(fileName)}`
  const downloaded = await Filesystem.downloadFile({
    url,
    path,
    directory: Directory.Cache,
    recursive: true,
  })
  const fileURI =
    downloaded.path || (await Filesystem.getUri({ path, directory: Directory.Cache })).uri

  try {
    await Share.share({
      title: fileName,
      dialogTitle: '保存或打开资料',
      files: [fileURI],
    })
    return 'shared'
  } finally {
    await Filesystem.deleteFile({ path, directory: Directory.Cache }).catch(() => undefined)
  }
}

async function downloadAndShareIOSFile(
  url: string,
  fileName: string,
  signal?: AbortSignal,
): Promise<PastExamDownloadResult> {
  const response = await fetch(url, { signal })
  if (!response.ok) throw new Error(`资料下载失败（${response.status}）`)

  const blob = await response.blob()
  const file = new File([blob], fileName, { type: blob.type || 'application/octet-stream' })
  const canShareFile =
    typeof navigator.share === 'function' &&
    typeof navigator.canShare === 'function' &&
    navigator.canShare({ files: [file] })

  if (!canShareFile) {
    throw new Error('当前 iOS 版本无法保存此文件，请在浏览器中打开网站后重试')
  }

  await navigator.share({ files: [file], title: fileName })
  return 'shared'
}

function startBrowserDownload(url: string, fileName: string) {
  const link = document.createElement('a')
  link.href = url
  link.download = fileName
  link.style.display = 'none'
  document.body.append(link)
  link.click()
  link.remove()
}

function safeCacheFileName(fileName: string) {
  const forbidden = '/\\:*?"<>|'
  const sanitized = Array.from(fileName)
    .map((character) => {
      const codePoint = character.codePointAt(0) ?? 0
      return codePoint <= 31 || forbidden.includes(character) ? '_' : character
    })
    .join('')
  return sanitized.slice(-160) || '资料文件'
}
