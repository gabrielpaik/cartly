'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'

import { fetchJsonSafe, isUnauthorizedError } from './api'

const AUTO_REFRESH_HOUR_KST = 0
const KST_TIME_ZONE = 'Asia/Seoul'
const CACHE_PREFIX = 'wimc_admin_cache:'

type CacheRecord<T> = {
  data: T
  usingFallback: boolean
  fetchedAt: number
}

function getKstParts(date: Date) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: KST_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hour12: false,
  }).formatToParts(date)

  return Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  ) as Record<'year' | 'month' | 'day' | 'hour', string>
}

function getKstDateKey(date: Date) {
  const { year, month, day } = getKstParts(date)
  return `${year}-${month}-${day}`
}

function getRefreshSlotKey(date: Date, refreshHourKst = AUTO_REFRESH_HOUR_KST) {
  const { hour } = getKstParts(date)
  if (Number(hour) >= refreshHourKst) {
    return getKstDateKey(date)
  }
  return getKstDateKey(new Date(date.getTime() - 24 * 60 * 60 * 1000))
}

function readCache<T>(storageKey: string): CacheRecord<T> | null {
  if (typeof window === 'undefined') return null

  try {
    const raw = window.localStorage.getItem(storageKey)
    if (!raw) return null
    const parsed = JSON.parse(raw) as CacheRecord<T>
    if (!parsed || typeof parsed.fetchedAt !== 'number') return null
    return parsed
  } catch {
    return null
  }
}

function writeCache<T>(storageKey: string, record: CacheRecord<T>) {
  if (typeof window === 'undefined') return

  try {
    window.localStorage.setItem(storageKey, JSON.stringify(record))
  } catch {
    // ignore localStorage failures
  }
}

export function useAdminData<T>(path: string, fallback: T) {
  const router = useRouter()
  const fallbackRef = useRef(fallback)
  const initializedRef = useRef(false)
  const storageKey = useMemo(() => `${CACHE_PREFIX}${path}`, [path])

  const [data, setData] = useState<T>(fallbackRef.current)
  const [usingFallback, setUsingFallback] = useState(true)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchJsonSafe<T>(path, fallbackRef.current)
      const fetchedAt = Date.now()
      setData(res.data)
      setUsingFallback(res.usingFallback)
      writeCache(storageKey, {
        data: res.data,
        usingFallback: res.usingFallback,
        fetchedAt,
      })
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : '데이터를 불러오지 못했어')
    } finally {
      setLoading(false)
    }
  }, [path, router, storageKey])

  useEffect(() => {
    if (initializedRef.current) return
    initializedRef.current = true

    const cached = readCache<T>(storageKey)
    if (cached) {
      setData(cached.data)
      setUsingFallback(cached.usingFallback)
    }

    const shouldRefresh =
      !cached || getRefreshSlotKey(new Date(cached.fetchedAt)) !== getRefreshSlotKey(new Date())

    if (shouldRefresh) {
      void load()
      return
    }

    setLoading(false)
  }, [load, storageKey])

  return { data, usingFallback, loading, error, reload: load }
}
