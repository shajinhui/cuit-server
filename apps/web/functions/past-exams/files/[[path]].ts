const SOURCE_ORIGIN = 'https://raw.githubusercontent.com'
const SOURCE_OWNER = 'andream7'
const SOURCE_REPOSITORY = 'cuit_sharing'
const ROUTE_PREFIX = '/past-exams/files/'
const IMMUTABLE_CACHE_SECONDS = 31_536_000

interface PagesContext {
  request: Request
}

interface CloudflareRequestInit extends RequestInit {
  cf: {
    cacheEverything: boolean
    cacheTtl: number
    cacheTtlByStatus: Record<string, number>
  }
}

export async function onRequest(context: PagesContext): Promise<Response> {
  const { request } = context

  if (request.method === 'OPTIONS') return corsPreflightResponse()
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return errorResponse('只支持读取文件', 405, { Allow: 'GET, HEAD, OPTIONS' })
  }

  const source = parseSourcePath(new URL(request.url))
  if (!source) return errorResponse('文件地址无效', 400)

  const upstreamURL = `${SOURCE_ORIGIN}/${SOURCE_OWNER}/${SOURCE_REPOSITORY}/${source.commit}/${source.encodedPath}`
  const upstreamHeaders = new Headers({ Accept: '*/*' })
  const requestedRange = request.headers.get('Range')
  if (request.method === 'GET' && requestedRange) upstreamHeaders.set('Range', requestedRange)

  let upstream: Response
  try {
    upstream = await fetch(upstreamURL, {
      method: request.method,
      headers: upstreamHeaders,
      redirect: 'follow',
      cf: {
        cacheEverything: true,
        cacheTtl: IMMUTABLE_CACHE_SECONDS,
        cacheTtlByStatus: {
          '200-299': IMMUTABLE_CACHE_SECONDS,
          '404': 300,
          '500-599': 0,
        },
      },
    } satisfies CloudflareRequestInit)
  } catch {
    return errorResponse('资料源暂时无法访问，请稍后重试', 502)
  }

  if (!upstream.ok) {
    await upstream.body?.cancel()
    if (upstream.status === 404) return errorResponse('资料不存在或已被移除', 404)
    if (upstream.status === 416) return errorResponse('请求的文件范围无效', 416)
    return errorResponse('资料源暂时无法访问', 502)
  }

  const headers = responseHeaders(upstream.headers, source.filename)
  return new Response(request.method === 'HEAD' ? null : upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  })
}

function parseSourcePath(url: URL) {
  if (!url.pathname.startsWith(ROUTE_PREFIX) || url.search) return undefined

  const rawSegments = url.pathname.slice(ROUTE_PREFIX.length).split('/')
  if (rawSegments.length < 2 || rawSegments.some((segment) => segment.length === 0)) {
    return undefined
  }

  let segments: string[]
  try {
    segments = rawSegments.map((segment) => decodeURIComponent(segment))
  } catch {
    return undefined
  }

  const [commit, ...pathSegments] = segments
  if (!/^[0-9a-f]{40}$/.test(commit)) return undefined
  if (pathSegments.length === 0 || pathSegments.join('/').length > 2_048) return undefined
  if (pathSegments.some(isUnsafeSegment)) return undefined

  return {
    commit,
    encodedPath: pathSegments.map(encodeURIComponent).join('/'),
    filename: pathSegments.at(-1) ?? 'download',
  }
}

function isUnsafeSegment(segment: string) {
  return (
    segment === '.' ||
    segment === '..' ||
    segment.includes('/') ||
    segment.includes('\\') ||
    Array.from(segment).some((character) => {
      const codePoint = character.codePointAt(0) ?? 0
      return codePoint <= 31 || codePoint === 127
    })
  )
}

function responseHeaders(upstream: Headers, filename: string) {
  const inferredContentType = contentTypeFor(filename)
  const headers = new Headers({
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': `public, max-age=86400, s-maxage=${IMMUTABLE_CACHE_SECONDS}, immutable`,
    'Content-Disposition': contentDisposition(filename),
    'Content-Type':
      inferredContentType === 'application/octet-stream'
        ? upstream.get('Content-Type') || inferredContentType
        : inferredContentType,
    'X-Content-Type-Options': 'nosniff',
  })

  for (const name of ['Accept-Ranges', 'Content-Length', 'Content-Range', 'ETag', 'Last-Modified']) {
    const value = upstream.get(name)
    if (value) headers.set(name, value)
  }
  if (!headers.has('Accept-Ranges')) headers.set('Accept-Ranges', 'bytes')
  return headers
}

function contentDisposition(filename: string) {
  const fallback = filename.replace(/[^\x20-\x7e]/g, '_').replace(/["\\]/g, '_') || 'download'
  const encoded = encodeURIComponent(filename).replace(/[!'()*]/g, (value) =>
    `%${value.charCodeAt(0).toString(16).toUpperCase()}`,
  )
  const extension = filename.slice(filename.lastIndexOf('.') + 1).toLowerCase()
  const behavior = ['7z', 'rar', 'zip'].includes(extension) ? 'attachment' : 'inline'
  return `${behavior}; filename="${fallback}"; filename*=UTF-8''${encoded}`
}

function contentTypeFor(filename: string) {
  const extension = filename.slice(filename.lastIndexOf('.') + 1).toLowerCase()
  const types: Record<string, string> = {
    '7z': 'application/x-7z-compressed',
    doc: 'application/msword',
    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    gif: 'image/gif',
    heic: 'image/heic',
    jpeg: 'image/jpeg',
    jpg: 'image/jpeg',
    md: 'text/markdown; charset=utf-8',
    pdf: 'application/pdf',
    png: 'image/png',
    ppt: 'application/vnd.ms-powerpoint',
    pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    rar: 'application/vnd.rar',
    txt: 'text/plain; charset=utf-8',
    webp: 'image/webp',
    xls: 'application/vnd.ms-excel',
    xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    zip: 'application/zip',
  }
  return types[extension] || 'application/octet-stream'
}

function corsPreflightResponse() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Headers': 'Range',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Max-Age': '86400',
    },
  })
}

function errorResponse(message: string, status: number, extraHeaders?: HeadersInit) {
  return Response.json(
    { error: message },
    {
      status,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'no-store',
        ...extraHeaders,
      },
    },
  )
}
