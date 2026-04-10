import { cookies } from 'next/headers'
import { NextRequest, NextResponse } from 'next/server'

import { ADMIN_COOKIE_NAME, getBackendApiBase, shouldUseSecureAdminCookie } from '../../../../lib/serverConfig'

async function forward(request: NextRequest, path: string[]) {
  const cookieStore = await cookies()
  const token = cookieStore.get(ADMIN_COOKIE_NAME)?.value?.trim()

  if (!token) {
    return NextResponse.json(
      {
        detail: {
          code: 'ADMIN_UNAUTHORIZED',
          message: 'admin 로그인이 필요해',
        },
      },
      { status: 401 },
    )
  }

  const upstreamUrl = `${getBackendApiBase()}/${path.join('/')}${request.nextUrl.search}`
  const headers = new Headers()
  headers.set('Authorization', `Bearer ${token}`)

  const accept = request.headers.get('accept')
  if (accept) headers.set('accept', accept)

  let body: BodyInit | undefined
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    const contentType = request.headers.get('content-type') ?? ''
    if (contentType.includes('multipart/form-data')) {
      body = await request.formData()
    } else {
      const text = await request.text()
      if (text) body = text
      if (contentType) headers.set('content-type', contentType)
    }
  }

  try {
    const upstream = await fetch(upstreamUrl, {
      method: request.method,
      headers,
      body,
      cache: 'no-store',
    })

    const responseHeaders: Record<string, string> = {
      'content-type': upstream.headers.get('content-type') ?? 'application/json',
    }

    const contentDisposition = upstream.headers.get('content-disposition')
    if (contentDisposition) {
      responseHeaders['content-disposition'] = contentDisposition
    }

    const response = new NextResponse(await upstream.arrayBuffer(), {
      status: upstream.status,
      headers: responseHeaders,
    })

    if (upstream.status === 401 || upstream.status === 403) {
      response.cookies.set({
        name: ADMIN_COOKIE_NAME,
        value: '',
        httpOnly: true,
        sameSite: 'lax',
        secure: shouldUseSecureAdminCookie(request),
        path: '/',
        maxAge: 0,
      })
    }

    return response
  } catch {
    return NextResponse.json(
      {
        detail: {
          code: 'ADMIN_UPSTREAM_UNAVAILABLE',
          message: 'backend admin API에 연결하지 못했어',
        },
      },
      { status: 502 },
    )
  }
}

export async function GET(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forward(request, path)
}

export async function POST(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forward(request, path)
}

export async function PUT(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forward(request, path)
}

export async function PATCH(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forward(request, path)
}

export async function DELETE(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forward(request, path)
}
