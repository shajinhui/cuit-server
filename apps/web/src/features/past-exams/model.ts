export interface PastExamFile {
  path: string
  name: string
  extension: string
  size: number
}

export interface PastExamsIndex {
  schemaVersion: 1
  repository: string
  branch: string
  commit: string
  updatedAt: string
  sourceURL: string
  totalFiles: number
  totalBytes: number
  files: PastExamFile[]
}

export interface PastExamDirectory {
  type: 'directory'
  name: string
  path: string
  fileCount: number
  totalBytes: number
}

export interface PastExamFileItem extends PastExamFile {
  type: 'file'
}

export interface PastExamBreadcrumb {
  label: string
  path: string
}

export type PastExamBrowserItem = PastExamDirectory | PastExamFileItem
export type PastExamFileKind = 'archive' | 'document' | 'image' | 'sheet' | 'slides' | 'text'

export function parsePastExamsIndex(value: unknown): PastExamsIndex {
  if (!isRecord(value) || value.schemaVersion !== 1 || !Array.isArray(value.files)) {
    throw new Error('资料目录格式不正确')
  }
  if (
    typeof value.repository !== 'string' ||
    typeof value.branch !== 'string' ||
    typeof value.commit !== 'string' ||
    !/^[0-9a-f]{40}$/.test(value.commit) ||
    typeof value.updatedAt !== 'string' ||
    Number.isNaN(Date.parse(value.updatedAt)) ||
    typeof value.sourceURL !== 'string' ||
    typeof value.totalFiles !== 'number' ||
    typeof value.totalBytes !== 'number'
  ) {
    throw new Error('资料目录元数据不完整')
  }

  const files = value.files.map(parseFile)
  const uniquePaths = new Set(files.map((file) => file.path))
  const totalBytes = files.reduce((total, file) => total + file.size, 0)
  if (
    uniquePaths.size !== files.length ||
    value.totalFiles !== files.length ||
    value.totalBytes !== totalBytes
  ) {
    throw new Error('资料目录统计信息不一致')
  }

  return {
    schemaVersion: 1,
    repository: value.repository,
    branch: value.branch,
    commit: value.commit,
    updatedAt: value.updatedAt,
    sourceURL: value.sourceURL,
    totalFiles: value.totalFiles,
    totalBytes: value.totalBytes,
    files,
  }
}

export function browsePastExamDirectory(
  files: readonly PastExamFile[],
  directoryPath: string,
): PastExamBrowserItem[] {
  const normalizedPath = normalizeDirectoryPath(directoryPath)
  const prefix = normalizedPath ? `${normalizedPath}/` : ''
  const directories = new Map<string, PastExamDirectory>()
  const directFiles: PastExamFileItem[] = []

  for (const file of files) {
    if (!file.path.startsWith(prefix)) continue
    const remainder = file.path.slice(prefix.length)
    const separator = remainder.indexOf('/')
    if (separator < 0) {
      directFiles.push({ ...file, type: 'file' })
      continue
    }

    const name = remainder.slice(0, separator)
    const path = prefix ? `${normalizedPath}/${name}` : name
    const existing = directories.get(name)
    if (existing) {
      existing.fileCount += 1
      existing.totalBytes += file.size
    } else {
      directories.set(name, {
        type: 'directory',
        name,
        path,
        fileCount: 1,
        totalBytes: file.size,
      })
    }
  }

  const collator = new Intl.Collator('zh-CN', { numeric: true, sensitivity: 'base' })
  return [
    ...Array.from(directories.values()).sort((left, right) =>
      collator.compare(left.name, right.name),
    ),
    ...directFiles.sort((left, right) => collator.compare(left.name, right.name)),
  ]
}

export function searchPastExamFiles(files: readonly PastExamFile[], query: string) {
  const keywords = query
    .trim()
    .toLocaleLowerCase('zh-CN')
    .split(/\s+/)
    .filter(Boolean)
  if (keywords.length === 0) return []

  return files.filter((file) => {
    const path = file.path.toLocaleLowerCase('zh-CN')
    return keywords.every((keyword) => path.includes(keyword))
  })
}

export function pastExamBreadcrumbs(directoryPath: string): PastExamBreadcrumb[] {
  const segments = normalizeDirectoryPath(directoryPath).split('/').filter(Boolean)
  return [
    { label: '全部课程', path: '' },
    ...segments.map((label, index) => ({
      label,
      path: segments.slice(0, index + 1).join('/'),
    })),
  ]
}

export function parentPastExamDirectory(directoryPath: string) {
  const segments = normalizeDirectoryPath(directoryPath).split('/').filter(Boolean)
  segments.pop()
  return segments.join('/')
}

export function pastExamFileProxyPath(commit: string, path: string) {
  if (!/^[0-9a-f]{40}$/.test(commit)) throw new Error('资料版本号无效')
  const segments = path.split('/')
  if (segments.length === 0 || segments.some((segment) => !segment || segment === '.' || segment === '..')) {
    throw new Error('资料路径无效')
  }
  return `/past-exams/files/${commit}/${segments.map(encodeURIComponent).join('/')}`
}

export function pastExamFileKind(extension: string): PastExamFileKind {
  if (['doc', 'docx', 'pdf'].includes(extension)) return 'document'
  if (['ppt', 'pptx'].includes(extension)) return 'slides'
  if (['xls', 'xlsx'].includes(extension)) return 'sheet'
  if (['gif', 'heic', 'jpeg', 'jpg', 'png', 'webp'].includes(extension)) return 'image'
  if (['7z', 'rar', 'zip'].includes(extension)) return 'archive'
  return 'text'
}

export function formatPastExamSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${trimTrailingZero(bytes / 1024)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${trimTrailingZero(bytes / (1024 * 1024))} MB`
  return `${trimTrailingZero(bytes / (1024 * 1024 * 1024))} GB`
}

function parseFile(value: unknown): PastExamFile {
  if (
    !isRecord(value) ||
    typeof value.path !== 'string' ||
    typeof value.name !== 'string' ||
    typeof value.extension !== 'string' ||
    typeof value.size !== 'number' ||
    !Number.isSafeInteger(value.size) ||
    value.size < 0
  ) {
    throw new Error('资料目录包含无效文件')
  }
  const segments = value.path.split('/')
  if (
    segments.some((segment) => !segment || segment === '.' || segment === '..') ||
    segments.at(-1) !== value.name
  ) {
    throw new Error('资料目录包含无效路径')
  }
  return {
    path: value.path,
    name: value.name,
    extension: value.extension.toLowerCase(),
    size: value.size,
  }
}

function normalizeDirectoryPath(path: string) {
  return path.split('/').filter(Boolean).join('/')
}

function trimTrailingZero(value: number) {
  return value.toFixed(value >= 10 ? 0 : 1).replace(/\.0$/, '')
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}
