import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPOSITORY = 'andream7/cuit_sharing'
const BRANCH = 'main'
const SCHEMA_VERSION = 1
const RELEVANT_PATH =
  /试卷|真题|历年|期末(?:考试|考|试卷|练习|复习)|考试(?:试卷|题|资料|复习)|题库|复习题|模拟试卷|模拟题|考题|试题|中期测验/
const SUPPORTED_EXTENSIONS = new Set([
  '7z',
  'doc',
  'docx',
  'gif',
  'heic',
  'jpeg',
  'jpg',
  'md',
  'pdf',
  'png',
  'ppt',
  'pptx',
  'rar',
  'txt',
  'webp',
  'xls',
  'xlsx',
  'zip',
])

const projectDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const outputPath = resolve(projectDirectory, 'public/past-exams/index.json')
const options = readOptions(process.argv.slice(2))

const tree = options.treeFile
  ? JSON.parse(await readFile(resolve(options.treeFile), 'utf8'))
  : await githubJSON(`/repos/${REPOSITORY}/git/trees/${BRANCH}?recursive=1`)

if (tree.truncated || !isCommit(tree.sha) || !Array.isArray(tree.tree)) {
  throw new Error('GitHub 返回的目录树不完整，已停止生成索引')
}

const updatedAt =
  options.updatedAt ||
  (await githubJSON(`/repos/${REPOSITORY}/commits/${tree.sha}`)).commit?.committer?.date

if (typeof updatedAt !== 'string' || Number.isNaN(Date.parse(updatedAt))) {
  throw new Error('无法读取源仓库的最后更新时间')
}

const files = tree.tree
  .filter(isIncludedBlob)
  .map((entry) => ({
    path: entry.path,
    name: entry.path.slice(entry.path.lastIndexOf('/') + 1),
    extension: extensionOf(entry.path),
    size: entry.size,
  }))
  .sort((left, right) => left.path.localeCompare(right.path, 'zh-CN', { numeric: true }))

const index = {
  schemaVersion: SCHEMA_VERSION,
  repository: REPOSITORY,
  branch: BRANCH,
  commit: tree.sha,
  updatedAt: new Date(updatedAt).toISOString(),
  sourceURL: `https://github.com/${REPOSITORY}`,
  totalFiles: files.length,
  totalBytes: files.reduce((total, file) => total + file.size, 0),
  files,
}

await mkdir(dirname(outputPath), { recursive: true })
await writeFile(outputPath, `${JSON.stringify(index)}\n`)
console.log(`Generated ${outputPath} with ${index.totalFiles} files at ${index.commit.slice(0, 7)}.`)

function readOptions(args) {
  const result = { treeFile: '', updatedAt: '' }
  for (let index = 0; index < args.length; index += 1) {
    const name = args[index]
    const value = args[index + 1]
    if ((name === '--tree-file' || name === '--updated-at') && !value) {
      throw new Error(`${name} 缺少参数`)
    }
    if (name === '--tree-file') {
      result.treeFile = value
      index += 1
    } else if (name === '--updated-at') {
      result.updatedAt = value
      index += 1
    } else {
      throw new Error(`未知参数：${name}`)
    }
  }
  return result
}

async function githubJSON(path) {
  const headers = {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'chengxin-youyou-past-exams-indexer',
    'X-GitHub-Api-Version': '2022-11-28',
  }
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`

  const response = await fetch(`https://api.github.com${path}`, { headers })
  if (!response.ok) {
    throw new Error(`GitHub API 请求失败：${response.status} ${response.statusText}`)
  }
  return response.json()
}

function isIncludedBlob(entry) {
  if (
    !entry ||
    entry.type !== 'blob' ||
    typeof entry.path !== 'string' ||
    typeof entry.size !== 'number'
  ) {
    return false
  }

  const segments = entry.path.split('/')
  if (segments.some((segment) => segment.startsWith('.') || segment.startsWith('~$'))) return false
  return RELEVANT_PATH.test(entry.path) && SUPPORTED_EXTENSIONS.has(extensionOf(entry.path))
}

function extensionOf(path) {
  const filename = path.slice(path.lastIndexOf('/') + 1)
  const dot = filename.lastIndexOf('.')
  return dot < 0 ? '' : filename.slice(dot + 1).toLowerCase()
}

function isCommit(value) {
  return typeof value === 'string' && /^[0-9a-f]{40}$/.test(value)
}
