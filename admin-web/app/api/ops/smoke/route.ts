import { NextResponse } from 'next/server'

import { CARTLY_PUBLIC_ADMIN_BASE_URL, CARTLY_PUBLIC_APP_BASE_URL } from '../../../../lib/publicUrlConfig'
import { getBackendApiBase } from '../../../../lib/serverConfig'

const TARGETS = [
  {
    key: 'localBackendHealth',
    label: 'Local backend /health',
    url: 'http://127.0.0.1:8011/health',
    expectedStatuses: [200],
  },
  {
    key: 'publicApiHealth',
    label: 'Public API /health',
    url: `${CARTLY_PUBLIC_APP_BASE_URL}/health`,
    expectedStatuses: [200],
  },
  {
    key: 'publicLanding',
    label: 'Public landing /',
    url: `${CARTLY_PUBLIC_APP_BASE_URL}/`,
    expectedStatuses: [200],
  },
  {
    key: 'publicPrivacy',
    label: 'Public privacy /privacy',
    url: `${CARTLY_PUBLIC_APP_BASE_URL}/privacy`,
    expectedStatuses: [200],
  },
  {
    key: 'publicAppConfig',
    label: 'Public app-config /v1/app-config',
    url: `${CARTLY_PUBLIC_APP_BASE_URL}/v1/app-config`,
    expectedStatuses: [200],
  },
  {
    key: 'adminLogin',
    label: 'Admin login /login',
    url: `${CARTLY_PUBLIC_ADMIN_BASE_URL}/login`,
    expectedStatuses: [200],
  },
] as const

type SmokeResult = {
  key: string
  label: string
  url: string
  status: number | null
  ok: boolean
  durationMs: number
  error?: string
}

type SmokeHistoryEntry = {
  checkedAt: string
  ok: boolean
  failureCount: number
  results: SmokeResult[]
}

async function persistSmokeHistory(entry: { checkedAt: string; ok: boolean; results: SmokeResult[] }) {
  const adminToken = process.env.ADMIN_TOKEN?.trim()
  if (!adminToken) {
    return [] as SmokeHistoryEntry[]
  }

  try {
    const response = await fetch(`${getBackendApiBase()}/admin/config/smoke-history`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify(entry),
      cache: 'no-store',
    })

    if (!response.ok) {
      return [] as SmokeHistoryEntry[]
    }

    const payload = (await response.json()) as { data?: { history?: SmokeHistoryEntry[] } }
    return payload.data?.history ?? []
  } catch {
    return [] as SmokeHistoryEntry[]
  }
}

export async function GET() {
  const results = await Promise.all(
    TARGETS.map(async (target) => {
      const startedAt = Date.now()
      try {
        const response = await fetch(target.url, {
          method: 'GET',
          cache: 'no-store',
          headers: {
            accept: 'text/html,application/json;q=0.9,*/*;q=0.8',
            'user-agent': 'CartlyAdminSmoke/1.0',
          },
        })
        const durationMs = Date.now() - startedAt
        return {
          key: target.key,
          label: target.label,
          url: target.url,
          status: response.status,
          ok: target.expectedStatuses.some((status) => status === response.status),
          durationMs,
        }
      } catch (error) {
        const durationMs = Date.now() - startedAt
        return {
          key: target.key,
          label: target.label,
          url: target.url,
          status: null,
          ok: false,
          durationMs,
          error: error instanceof Error ? error.message : 'unknown error',
        }
      }
    }),
  )

  const checkedAt = new Date().toISOString()
  const ok = results.every((result) => result.ok)
  const history = await persistSmokeHistory({ checkedAt, ok, results })

  return NextResponse.json({
    ok,
    checkedAt,
    results,
    history,
  })
}
