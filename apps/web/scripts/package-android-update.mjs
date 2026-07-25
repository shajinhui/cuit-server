import { execFileSync } from 'node:child_process'
import {
  copyFileSync,
  mkdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs'
import { basename, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const APP_ID = 'org.dpdns.fanxiaogao05.chengxinyouyou'
const MAX_PAGES_FILE_SIZE = 25 * 1024 * 1024
const projectDirectory = resolve(fileURLToPath(new URL('..', import.meta.url)))
const packageJSON = JSON.parse(
  readFileSync(join(projectDirectory, 'package.json'), 'utf8'),
)
const nativeVersion = packageJSON.version

function readCommitSHA() {
  const environmentSHA =
    process.env.CF_PAGES_COMMIT_SHA || process.env.GITHUB_SHA
  if (environmentSHA) return environmentSHA

  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: projectDirectory,
      encoding: 'utf8',
    }).trim()
  } catch {
    return 'local'
  }
}

function normalizedHTTPSBaseURL(value) {
  const url = new URL(value)
  if (url.protocol !== 'https:') {
    throw new Error(`OTA 资源地址必须使用 HTTPS: ${value}`)
  }
  return url.toString().replace(/\/$/, '')
}

const revision = readCommitSHA().slice(0, 12).replace(/[^0-9A-Za-z-]/g, '')
const bundleVersion =
  process.env.OTA_BUNDLE_VERSION || `${nativeVersion}-web.${revision || 'local'}`
const publicURL = normalizedHTTPSBaseURL(
  process.env.OTA_ASSET_BASE_URL ||
    'https://fanxiaogao05.dpdns.org',
)
const deploymentURL = process.env.CF_PAGES_URL
  ? normalizedHTTPSBaseURL(process.env.CF_PAGES_URL)
  : undefined

const otaDirectory = join(projectDirectory, '.ota')
const webDirectory = join(otaDirectory, 'web')
const workDirectory = join(otaDirectory, 'release')
const outputDirectory = join(
  projectDirectory,
  'dist',
  'app-updates',
  'android',
)
const bundleOutputDirectory = join(outputDirectory, 'bundles')

const otaIndex = join(webDirectory, 'index.html')
const otaHTML = readFileSync(otaIndex, 'utf8')
if (/((?:src|href)=["'])\/assets\//.test(otaHTML)) {
  throw new Error('Android OTA 构建仍包含绝对 /assets 路径')
}
rmSync(join(webDirectory, '_headers'), { force: true })
rmSync(join(webDirectory, '.DS_Store'), { force: true })

rmSync(workDirectory, { force: true, recursive: true })
mkdirSync(workDirectory, { recursive: true })
mkdirSync(bundleOutputDirectory, { recursive: true })

const capgoExecutable = join(
  projectDirectory,
  'node_modules',
  '.bin',
  process.platform === 'win32' ? 'capgo.cmd' : 'capgo',
)
const result = JSON.parse(
  execFileSync(
    capgoExecutable,
    [
      'bundle',
      'zip',
      APP_ID,
      '--path',
      webDirectory,
      '--bundle',
      bundleVersion,
      '--name',
      join('.ota', 'release', `${APP_ID}_${bundleVersion}.zip`),
      '--json',
    ],
    {
      cwd: projectDirectory,
      encoding: 'utf8',
    },
  ),
)

if (!/^[a-f0-9]{64}$/.test(result.checksum)) {
  throw new Error('Capgo CLI 没有返回有效的 SHA-256')
}

const sourceBundle = resolve(projectDirectory, result.filename)
const bundleSize = statSync(sourceBundle).size
if (bundleSize > MAX_PAGES_FILE_SIZE) {
  throw new Error(
    `Android 更新包 ${(bundleSize / 1024 / 1024).toFixed(2)} MiB，超过 Cloudflare Pages 25 MiB 单文件限制`,
  )
}

const outputFilename = basename(result.filename)
const outputBundle = join(bundleOutputDirectory, outputFilename)
copyFileSync(sourceBundle, outputBundle)

const manifest = {
  schema: 1,
  platform: 'android',
  channel: 'stable',
  version: bundleVersion,
  nativeVersion,
  url: `${publicURL}/app-updates/android/bundles/${encodeURIComponent(outputFilename)}`,
  ...(deploymentURL && deploymentURL !== publicURL
    ? {
        fallbackUrl: `${deploymentURL}/app-updates/android/bundles/${encodeURIComponent(outputFilename)}`,
      }
    : {}),
  checksum: result.checksum,
  publishedAt: new Date().toISOString(),
}
writeFileSync(
  join(outputDirectory, 'latest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
)

console.log(
  `Android OTA ${bundleVersion}: ${(bundleSize / 1024 / 1024).toFixed(2)} MiB`,
)
