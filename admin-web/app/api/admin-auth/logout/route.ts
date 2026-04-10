import { NextRequest, NextResponse } from 'next/server'

import { ADMIN_COOKIE_NAME, getBackendApiBase, shouldUseSecureAdminCookie } from '../../../../lib/serverConfig'

export async function POST(request: NextRequest) {
  const sessionToken = request.cookies.get(ADMIN_COOKIE_NAME)?.value?.trim()

  if (sessionToken) {
    try {
      await fetch(`${getBackendApiBase()}/admin/logout`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${sessionToken}`,
        },
        cache: 'no-store',
      })
    } catch {
      // ignore upstream logout failures and still clear cookie locally
    }
  }

  const response = NextResponse.json({ ok: true })
  response.cookies.set({
    name: ADMIN_COOKIE_NAME,
    value: '',
    httpOnly: true,
    sameSite: 'lax',
    secure: shouldUseSecureAdminCookie(request),
    path: '/',
    maxAge: 0,
  })
  return response
}
