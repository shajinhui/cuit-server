export interface AndroidUpdateManifest {
  schema: 1
  platform: 'android'
  channel: 'stable'
  version: string
  nativeVersion: string
  title?: string
  releaseNotes?: string
  url: string
  fallbackUrl?: string
  checksum: string
  publishedAt: string
}

const SEMVER_PATTERN =
  /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/
const SHA256_PATTERN = /^[a-f0-9]{64}$/

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

export function parseAndroidUpdateManifest(
  value: unknown,
  manifestURL: string,
): AndroidUpdateManifest | null {
  if (!isRecord(value)) return null

  const candidate = value as Partial<AndroidUpdateManifest>
  if (
    candidate.schema !== 1 ||
    candidate.platform !== 'android' ||
    candidate.channel !== 'stable' ||
    typeof candidate.version !== 'string' ||
    !SEMVER_PATTERN.test(candidate.version) ||
    typeof candidate.nativeVersion !== 'string' ||
    !SEMVER_PATTERN.test(candidate.nativeVersion) ||
    (candidate.title !== undefined &&
      (typeof candidate.title !== 'string' ||
        candidate.title.trim().length === 0 ||
        candidate.title.length > 80)) ||
    (candidate.releaseNotes !== undefined &&
      (typeof candidate.releaseNotes !== 'string' ||
        candidate.releaseNotes.trim().length === 0 ||
        candidate.releaseNotes.length > 500)) ||
    typeof candidate.url !== 'string' ||
    typeof candidate.checksum !== 'string' ||
    !SHA256_PATTERN.test(candidate.checksum) ||
    typeof candidate.publishedAt !== 'string' ||
    Number.isNaN(Date.parse(candidate.publishedAt))
  ) {
    return null
  }

  try {
    const source = new URL(manifestURL)
    const bundle = new URL(candidate.url)
    if (source.protocol !== 'https:' || bundle.protocol !== 'https:') return null
    if (!isTrustedUpdateOrigin(bundle, source)) return null
    if (candidate.fallbackUrl) {
      const fallback = new URL(candidate.fallbackUrl)
      if (fallback.protocol !== 'https:' || !isTrustedUpdateOrigin(fallback, source)) {
        return null
      }
    }
  } catch {
    return null
  }

  return candidate as AndroidUpdateManifest
}

function isTrustedUpdateOrigin(candidate: URL, source: URL): boolean {
  const isProjectPagesDomain =
    candidate.hostname === 'cuit-server.pages.dev' ||
    candidate.hostname.endsWith('.cuit-server.pages.dev')
  const isProductionDomain =
    candidate.origin === 'https://fanxiaogao05.dpdns.org'
  return isProjectPagesDomain || isProductionDomain || candidate.origin === source.origin
}

export function shouldDownloadAndroidUpdate(
  manifest: AndroidUpdateManifest,
  nativeVersion: string,
  currentVersion: string,
  pendingVersion?: string,
): boolean {
  return (
    manifest.nativeVersion === nativeVersion &&
    manifest.version !== currentVersion &&
    manifest.version !== pendingVersion
  )
}
