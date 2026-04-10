import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

import { ADMIN_COOKIE_NAME } from './lib/serverConfig'

function publicUrlFromRequest(request: NextRequest) {
  const forwardedHost = request.headers.get('x-forwarded-host')?.trim()
  const forwardedProto = request.headers.get('x-forwarded-proto')?.trim()
  const url = request.nextUrl.clone()

  if (forwardedHost) {
    const [hostname, port] = forwardedHost.split(':')
    url.hostname = hostname
    url.port = port ?? ''
  } else {
    url.port = ''
  }

  if (forwardedProto) {
    url.protocol = `${forwardedProto}:`
  }

  return url
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  if (
    pathname.startsWith('/api/') ||
    pathname.startsWith('/_next/') ||
    pathname.startsWith('/app-preview/') ||
    pathname === '/favicon.ico'
  ) {
    return NextResponse.next()
  }

  const hasToken = Boolean(request.cookies.get(ADMIN_COOKIE_NAME)?.value)
  const isLoginPage = pathname === '/login'

  if (!hasToken && !isLoginPage) {
    const url = publicUrlFromRequest(request)
    url.pathname = '/login'
    url.search = ''
    url.searchParams.set('next', pathname)
    return NextResponse.redirect(url)
  }

  if (hasToken && isLoginPage) {
    const url = publicUrlFromRequest(request)
    url.pathname = '/overview'
    url.search = ''
    return NextResponse.redirect(url)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
