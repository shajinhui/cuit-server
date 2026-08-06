const avatarModules = import.meta.glob<{ default: string }>('@/assets/avatars/avatar-*.jpg', {
  eager: true,
})

export interface PresetAvatar {
  id: number
  src: string
}

export const presetAvatars: PresetAvatar[] = Object.entries(avatarModules)
  .sort(([left], [right]) => left.localeCompare(right, 'en', { numeric: true }))
  .map(([, module], index) => ({ id: index + 1, src: module.default }))

export function randomPresetAvatarId() {
  return Math.floor(Math.random() * presetAvatars.length) + 1
}

export function presetAvatarById(id: number) {
  return presetAvatars.find((avatar) => avatar.id === id)
}

export async function createSquareAvatar(file: File): Promise<Blob> {
  let bitmap: ImageBitmap
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' })
  } catch {
    bitmap = await loadImageBitmapFallback(file)
  }

  try {
    const side = Math.min(bitmap.width, bitmap.height)
    const canvas = document.createElement('canvas')
    canvas.width = 512
    canvas.height = 512
    const context = canvas.getContext('2d')
    if (!context) throw new Error('当前浏览器无法处理图片')

    context.imageSmoothingEnabled = true
    context.imageSmoothingQuality = 'high'
    // JPEG 不支持透明通道，先铺白色底，避免透明 PNG 上传后变成黑底。
    context.fillStyle = '#ffffff'
    context.fillRect(0, 0, 512, 512)
    context.drawImage(
      bitmap,
      (bitmap.width - side) / 2,
      (bitmap.height - side) / 2,
      side,
      side,
      0,
      0,
      512,
      512,
    )
    const blob = await canvasToBlob(canvas)
    if (!blob) throw new Error('图片处理失败，请换一张重试')
    return blob
  } finally {
    bitmap.close()
  }
}

function loadImageBitmapFallback(file: File): Promise<ImageBitmap> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const image = new Image()
    image.onload = () => {
      createImageBitmap(image)
        .then(resolve)
        .catch(reject)
        .finally(() => URL.revokeObjectURL(url))
    }
    image.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('图片读取失败，请换一张重试'))
    }
    image.src = url
  })
}

function canvasToBlob(canvas: HTMLCanvasElement): Promise<Blob | null> {
  return new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.85))
}
