import { NextRequest, NextResponse } from 'next/server'

import { getBackendApiBase } from './serverConfig'

function copyHeaders(request: NextRequest) {
  const headers = new Headers()

  const accept = request.headers.get('accept')
  if (accept) headers.set('accept', accept)

  const authorization = request.headers.get('authorization')
  if (authorization) headers.set('authorization', authorization)

  const contentType = request.headers.get('content-type')
  if (contentType) headers.set('content-type', contentType)

  const userAgent = request.headers.get('user-agent')
  if (userAgent) headers.set('user-agent', userAgent)

  return headers
}

async function buildBody(request: NextRequest) {
  if (request.method === 'GET' || request.method === 'HEAD') {
    return undefined
  }

  const contentType = request.headers.get('content-type') ?? ''
  if (contentType.includes('multipart/form-data')) {
    return request.formData()
  }

  const arrayBuffer = await request.arrayBuffer()
  if (arrayBuffer.byteLength === 0) {
    return undefined
  }

  return arrayBuffer
}

export async function forwardPublicRequest(request: NextRequest, upstreamPath: string) {
  const upstreamUrl = `${getBackendApiBase()}${upstreamPath}${request.nextUrl.search}`

  try {
    const upstream = await fetch(upstreamUrl, {
      method: request.method,
      headers: copyHeaders(request),
      body: await buildBody(request),
      cache: 'no-store',
    })

    const responseHeaders = new Headers()
    const contentType = upstream.headers.get('content-type')
    if (contentType) responseHeaders.set('content-type', contentType)

    const contentDisposition = upstream.headers.get('content-disposition')
    if (contentDisposition) responseHeaders.set('content-disposition', contentDisposition)

    const cacheControl = upstream.headers.get('cache-control')
    if (cacheControl) responseHeaders.set('cache-control', cacheControl)

    return new NextResponse(await upstream.arrayBuffer(), {
      status: upstream.status,
      headers: responseHeaders,
    })
  } catch {
    return NextResponse.json(
      {
        detail: {
          code: 'APP_PUBLIC_UPSTREAM_UNAVAILABLE',
          message: 'public app API upstream에 연결하지 못했어',
        },
      },
      { status: 502 },
    )
  }
}

export async function forwardPublicAsset(upstreamPath: string) {
  const upstreamUrl = `${getBackendApiBase()}${upstreamPath}`

  try {
    const upstream = await fetch(upstreamUrl, {
      method: 'GET',
      cache: 'no-store',
    })

    const responseHeaders = new Headers()
    responseHeaders.set('content-type', upstream.headers.get('content-type') ?? 'application/octet-stream')
    responseHeaders.set('cache-control', upstream.headers.get('cache-control') ?? 'public, max-age=300')

    return new NextResponse(await upstream.arrayBuffer(), {
      status: upstream.status,
      headers: responseHeaders,
    })
  } catch {
    return NextResponse.json(
      {
        detail: {
          code: 'APP_PUBLIC_ASSET_UPSTREAM_UNAVAILABLE',
          message: 'public app asset upstream에 연결하지 못했어',
        },
      },
      { status: 502 },
    )
  }
}
