const API_BASE = process.env.NEXT_PUBLIC_WIMC_API_BASE ?? 'http://127.0.0.1:8011'

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { cache: 'no-store' })
  if (!res.ok) {
    throw new Error(`Request failed: ${res.status}`)
  }
  return res.json()
}

export async function fetchJsonSafe<T>(path: string, fallback: T): Promise<{ data: T; usingFallback: boolean }> {
  try {
    const data = await fetchJson<T>(path)
    return { data, usingFallback: false }
  } catch {
    return { data: fallback, usingFallback: true }
  }
}

export async function putJson<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
  })
  if (!res.ok) {
    throw new Error(`Request failed: ${res.status}`)
  }
  return res.json()
}

export { API_BASE }
