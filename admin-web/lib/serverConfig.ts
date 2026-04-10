import type { NextRequest } from 'next/server'

export const ADMIN_COOKIE_NAME = 'wimc_admin_session'

export function getBackendApiBase() {
  return (process.env.WIMC_API_BASE ?? process.env.NEXT_PUBLIC_WIMC_API_BASE ?? 'http://127.0.0.1:8011').replace(/\/$/, '')
}

export function shouldUseSecureAdminCookie(request: NextRequest) {
  const forwardedProto = request.headers.get('x-forwarded-proto')?.trim().toLowerCase()
  if (forwardedProto) {
    return forwardedProto === 'https'
  }

  const hostname = request.nextUrl.hostname.trim().toLowerCase()
  if (hostname === '127.0.0.1' || hostname === 'localhost') {
    return false
  }

  return request.nextUrl.protocol === 'https:' || process.env.NODE_ENV === 'production'
}
