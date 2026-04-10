import { NextRequest, NextResponse } from 'next/server'

import { ADMIN_COOKIE_NAME, getBackendApiBase, shouldUseSecureAdminCookie } from '../../../../lib/serverConfig'

type LoginResponse = {
  ok?: boolean
  data?: {
    session?: {
      token?: string
      expiresAt?: string | null
    }
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = (await request.json()) as { password?: string }
    const password = (body.password ?? '').trim()

    if (!password) {
      return NextResponse.json(
        {
          detail: {
            code: 'PASSWORD_REQUIRED',
            message: '관리자 비밀번호를 입력해',
          },
        },
        { status: 400 },
      )
    }

    const res = await fetch(`${getBackendApiBase()}/admin/session`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${password}`,
      },
      cache: 'no-store',
    })

    if (!res.ok) {
      const text = await res.text()
      return new NextResponse(text || 'admin 인증 실패', {
        status: res.status,
        headers: {
          'content-type': res.headers.get('content-type') ?? 'application/json',
        },
      })
    }

    const payload = (await res.json()) as LoginResponse
    const sessionToken = payload?.data?.session?.token?.trim()
    if (!sessionToken) {
      return NextResponse.json(
        {
          detail: {
            code: 'ADMIN_SESSION_ISSUE_FAILED',
            message: 'admin 세션을 만들지 못했어',
          },
        },
        { status: 502 },
      )
    }

    const response = NextResponse.json({ ok: true })
    response.cookies.set({
      name: ADMIN_COOKIE_NAME,
      value: sessionToken,
      httpOnly: true,
      sameSite: 'lax',
      secure: shouldUseSecureAdminCookie(request),
      path: '/',
      maxAge: 60 * 60 * 12,
    })
    return response
  } catch {
    return NextResponse.json(
      {
        detail: {
          code: 'LOGIN_FAILED',
          message: 'admin 로그인 처리 중 오류가 났어',
        },
      },
      { status: 500 },
    )
  }
}
