import { Buffer } from 'node:buffer'
import type { ServerResponse } from 'node:http'

import type { Connect, Plugin } from 'vite'

import { createMockHandler, type MockResponse } from './api'

function sendJSON(res: ServerResponse, result: MockResponse) {
  const payload = JSON.stringify(result.body)
  res.statusCode = result.status
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  res.setHeader('Content-Length', Buffer.byteLength(payload))
  res.end(payload)
}

async function readJSONBody(req: Connect.IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = []
  for await (const chunk of req) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : (chunk as Buffer))
  }
  const raw = Buffer.concat(chunks).toString('utf8')
  if (!raw) return undefined
  try {
    return JSON.parse(raw)
  } catch {
    return undefined
  }
}

/**
 * 开发期把教务接口换成本地演示数据。
 *
 * 开启方式：在 apps/web 的 .env.local 里写 VITE_MOCK_API=true。
 * 只在 dev server 生效（apply: 'serve'），不进入生产构建，也不需要后端服务；
 * 用 fixtures.ts 里的演示账号登录即可。
 *
 * 中间件注册在 vite 内置 proxy 之前，所以 /api/v1/jwxt/* 会被拦下；
 * 没有演示数据的接口（评分、校园跑、图书馆等）会继续走正常代理。
 */
export function mockApiPlugin(enabled: boolean): Plugin {
  return {
    name: 'cuit-mock-jwxt-api',
    apply: 'serve',
    configureServer(server) {
      if (!enabled) return

      const handle = createMockHandler()

      server.middlewares.use((req, res, next) => {
        const url = req.url ?? ''
        if (!url.startsWith('/api/v1/')) return next()

        const method = (req.method ?? 'GET').toUpperCase()

        if (method === 'GET' || method === 'DELETE') {
          const result = handle(method, url, undefined)
          if (!result) return next()
          sendJSON(res, result)
          return
        }

        if (method === 'POST' || method === 'PUT' || method === 'PATCH') {
          void readJSONBody(req)
            .then((body) => {
              const result = handle(method, url, body)
              if (!result) return next()
              sendJSON(res, result)
            })
            .catch(next)
          return
        }

        next()
      })

      server.config.logger.info('  ➜  演示数据已启用：/api/v1/jwxt/* 由本地 mock 返回')
    },
  }
}
