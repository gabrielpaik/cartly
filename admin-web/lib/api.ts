export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

async function parseErrorMessage(res: Response) {
  try {
    const body = await res.json()
    const detail = body?.detail
    if (typeof detail === 'string' && detail) return detail
    if (detail?.message) return detail.message as string
    if (body?.error?.message) return body.error.message as string
  } catch {
    // ignore non-json error bodies
  }
  return `Request failed: ${res.status}`
}

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`/api/wimc-admin${path}`, {
    cache: 'no-store',
    credentials: 'same-origin',
  })
  if (!res.ok) {
    throw new ApiError(await parseErrorMessage(res), res.status)
  }
  return res.json()
}

export async function fetchJsonSafe<T>(path: string, fallback: T): Promise<{ data: T; usingFallback: boolean }> {
  try {
    const data = await fetchJson<T>(path)
    return { data, usingFallback: false }
  } catch (error) {
    if (error instanceof ApiError && (error.status === 401 || error.status === 403)) {
      throw error
    }
    return { data: fallback, usingFallback: true }
  }
}

export async function putJson<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`/api/wimc-admin${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
    credentials: 'same-origin',
  })
  if (!res.ok) {
    throw new ApiError(await parseErrorMessage(res), res.status)
  }
  return res.json()
}

export async function postFormData<T>(path: string, formData: FormData): Promise<T> {
  const res = await fetch(`/api/wimc-admin${path}`, {
    method: 'POST',
    body: formData,
    cache: 'no-store',
    credentials: 'same-origin',
  })
  if (!res.ok) {
    throw new ApiError(await parseErrorMessage(res), res.status)
  }
  return res.json()
}

export async function postJson<T>(path: string, body?: unknown): Promise<T> {
  const res = await fetch(`/api/wimc-admin${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body ?? {}),
    cache: 'no-store',
    credentials: 'same-origin',
  })
  if (!res.ok) {
    throw new ApiError(await parseErrorMessage(res), res.status)
  }
  return res.json()
}

export async function loginAdmin(password: string): Promise<void> {
  const res = await fetch('/api/admin-auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password }),
    credentials: 'same-origin',
  })
  if (!res.ok) {
    throw new ApiError(await parseErrorMessage(res), res.status)
  }
}

export async function logoutAdmin(): Promise<void> {
  await fetch('/api/admin-auth/logout', {
    method: 'POST',
    credentials: 'same-origin',
  })
}

export function isUnauthorizedError(error: unknown) {
  return error instanceof ApiError && (error.status === 401 || error.status === 403)
}
