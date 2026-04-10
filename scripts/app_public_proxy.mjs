import http from 'node:http'

const port = Number(process.env.APP_PUBLIC_PROXY_PORT || '3100')
const host = process.env.APP_PUBLIC_PROXY_HOST || '127.0.0.1'
const backendBase = (process.env.APP_PUBLIC_PROXY_BACKEND_BASE || process.env.WIMC_API_BASE || 'http://127.0.0.1:8011').replace(/\/$/, '')

const allowedExact = new Set(['/v1/app-config', '/v1/carts', '/health'])
const allowedPrefixes = [
  '/v1/auth/',
  '/v1/scan/',
  '/v1/carts/',
  '/v1/events/',
  '/v1/ads/',
  '/assets/branding/',
  '/assets/ads/',
]

function isAllowedPath(pathname) {
  if (allowedExact.has(pathname)) return true
  return allowedPrefixes.some((prefix) => pathname.startsWith(prefix))
}

function copyHeaders(req) {
  const headers = new Headers()
  const accept = req.headers['accept']
  if (accept) headers.set('accept', Array.isArray(accept) ? accept.join(', ') : accept)

  const authorization = req.headers['authorization']
  if (authorization) headers.set('authorization', Array.isArray(authorization) ? authorization.join(', ') : authorization)

  const contentType = req.headers['content-type']
  if (contentType) headers.set('content-type', Array.isArray(contentType) ? contentType.join(', ') : contentType)

  const userAgent = req.headers['user-agent']
  if (userAgent) headers.set('user-agent', Array.isArray(userAgent) ? userAgent.join(', ') : userAgent)

  const contentLength = req.headers['content-length']
  if (contentLength) headers.set('content-length', Array.isArray(contentLength) ? contentLength.join(', ') : contentLength)

  return headers
}

async function readBody(req) {
  if (req.method === 'GET' || req.method === 'HEAD') {
    return undefined
  }

  const chunks = []
  for await (const chunk of req) {
    chunks.push(chunk)
  }

  if (chunks.length === 0) {
    return undefined
  }

  return Buffer.concat(chunks)
}

function writeJson(res, statusCode, payload) {
  const body = Buffer.from(JSON.stringify(payload, null, 2))
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': String(body.length),
  })
  res.end(body)
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', `http://${req.headers.host || `${host}:${port}`}`)
    if (!isAllowedPath(url.pathname)) {
      return writeJson(res, 404, {
        detail: {
          code: 'APP_PUBLIC_ROUTE_NOT_FOUND',
          message: '허용되지 않은 public app route야',
        },
      })
    }

    const upstreamUrl = `${backendBase}${url.pathname}${url.search}`
    const upstream = await fetch(upstreamUrl, {
      method: req.method,
      headers: copyHeaders(req),
      body: await readBody(req),
    })

    const responseHeaders = {}
    const contentType = upstream.headers.get('content-type')
    if (contentType) responseHeaders['content-type'] = contentType

    const contentDisposition = upstream.headers.get('content-disposition')
    if (contentDisposition) responseHeaders['content-disposition'] = contentDisposition

    const cacheControl = upstream.headers.get('cache-control')
    if (cacheControl) responseHeaders['cache-control'] = cacheControl

    const body = Buffer.from(await upstream.arrayBuffer())
    responseHeaders['content-length'] = String(body.length)

    res.writeHead(upstream.status, responseHeaders)
    if (req.method === 'HEAD') {
      res.end()
      return
    }
    res.end(body)
  } catch (error) {
    console.error('[app-public-proxy] upstream failure', error)
    writeJson(res, 502, {
      detail: {
        code: 'APP_PUBLIC_UPSTREAM_UNAVAILABLE',
        message: 'public app API upstream에 연결하지 못했어',
      },
    })
  }
})

server.listen(port, host, () => {
  console.log(`[app-public-proxy] listening on http://${host}:${port} -> ${backendBase}`)
})
