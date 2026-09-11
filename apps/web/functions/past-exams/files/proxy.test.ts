import { afterEach, describe, expect, it, vi } from 'vitest'

import { onRequest } from './[[path]]'

const commit = 'e75cb68572992fef61064b29c82713a19e7b8aef'

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('历年试卷文件代理', () => {
  it('只允许固定仓库中的 commit 文件路径', async () => {
    const fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)

    const malformedCommit = await request('/past-exams/files/main/数据结构/试卷.pdf')
    const traversal = await request(`/past-exams/files/${commit}/%2e%2e/secret.pdf`)
    const arbitraryURL = await request(`/past-exams/files/${commit}/https%3A%2F%2Fexample.com/file.pdf`)
    const unsupportedQuery = await request(`/past-exams/files/${commit}/数据结构/试卷.pdf?url=x`)

    expect(malformedCommit.status).toBe(400)
    expect(traversal.status).toBe(400)
    expect(arbitraryURL.status).toBe(400)
    expect(unsupportedQuery.status).toBe(400)
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('按 commit 流式转发文件并写入长期缓存响应头', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response('pdf-content', {
        headers: {
          'Accept-Ranges': 'bytes',
          'Content-Type': 'application/octet-stream',
          ETag: 'example-etag',
        },
      }),
    )
    vi.stubGlobal('fetch', fetchMock)

    const response = await request(
      `/past-exams/files/${commit}/数据结构/一堆卷子/数据结构历年题.pdf?view=1`,
    )

    expect(response.status).toBe(200)
    expect(await response.text()).toBe('pdf-content')
    expect(response.headers.get('Cache-Control')).toContain('immutable')
    expect(response.headers.get('Content-Type')).toBe('application/pdf')
    expect(response.headers.get('Content-Disposition')).toContain(
      encodeURIComponent('数据结构历年题.pdf'),
    )
    expect(fetchMock).toHaveBeenCalledWith(
      `https://raw.githubusercontent.com/andream7/cuit_sharing/${commit}/${encodeURIComponent('数据结构')}/${encodeURIComponent('一堆卷子')}/${encodeURIComponent('数据结构历年题.pdf')}`,
      expect.objectContaining({ method: 'GET' }),
    )
  })

  it('不把上游错误正文透传给用户', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('upstream details', { status: 404 })))

    const response = await request(`/past-exams/files/${commit}/数据结构/缺失.pdf`)

    expect(response.status).toBe(404)
    expect(await response.json()).toEqual({ error: '资料不存在或已被移除' })
    expect(response.headers.get('Cache-Control')).toBe('no-store')
  })

  it('转发断点续传范围并保留 Content-Range', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response('part', {
        status: 206,
        headers: {
          'Accept-Ranges': 'bytes',
          'Content-Range': 'bytes 10-13/100',
        },
      }),
    )
    vi.stubGlobal('fetch', fetchMock)

    const response = await request(`/past-exams/files/${commit}/数据结构/试卷.pdf`, {
      headers: { Range: 'bytes=10-13' },
    })

    const upstreamRequest = fetchMock.mock.calls[0]?.[1] as RequestInit
    expect(new Headers(upstreamRequest.headers).get('Range')).toBe('bytes=10-13')
    expect(response.status).toBe(206)
    expect(response.headers.get('Content-Range')).toBe('bytes 10-13/100')
  })

  it('为 Office 和压缩包设置可打开或下载的准确响应类型', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response('content', { headers: { 'Content-Type': 'application/octet-stream' } }))
    vi.stubGlobal('fetch', fetchMock)

    const office = await request(`/past-exams/files/${commit}/数据结构/试卷.docx`)
    const archive = await request(`/past-exams/files/${commit}/数据结构/试题.rar`)

    expect(office.headers.get('Content-Type')).toBe(
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    )
    expect(office.headers.get('Content-Disposition')).toMatch(/^inline;/)
    expect(archive.headers.get('Content-Type')).toBe('application/vnd.rar')
    expect(archive.headers.get('Content-Disposition')).toMatch(/^attachment;/)
  })

  it('通过 download 参数强制下载可预览文件', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response('pdf-content', { headers: { 'Content-Type': 'application/octet-stream' } }),
      ),
    )

    const response = await request(`/past-exams/files/${commit}/数据结构/试卷.pdf?download=1`)

    expect(response.status).toBe(200)
    expect(response.headers.get('Content-Type')).toBe('application/pdf')
    expect(response.headers.get('Content-Disposition')).toMatch(/^attachment;/)
  })
})

function request(path: string, init?: RequestInit) {
  return onRequest({ request: new Request(`https://example.com${path}`, init) })
}
