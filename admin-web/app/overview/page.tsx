'use client'

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { fetchJsonSafe, isUnauthorizedError, postJson } from '../../lib/api'
import { formatDate, formatNumber, formatPercent } from '../../lib/format'
import { mockConfig, mockPeriodSummary, mockSummary } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type PeriodKey = 'week' | 'month' | 'quarter' | 'year'
type ComparisonPeriodKey = 'day' | 'week' | 'month'
type SummaryComparisonMap = Partial<Record<'dau' | 'wau' | 'mau', Partial<Record<ComparisonPeriodKey, number>>>>
type AlertTone = 'critical' | 'warn' | 'info'

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

type SmokeDto = {
  ok: boolean
  checkedAt: string
  results: SmokeResult[]
  history?: SmokeHistoryEntry[]
}

type PublicSiteCopy = {
  enabledSections?: string
  sectionOrder?: string
}

type OverviewAlert = {
  tone: AlertTone
  title: string
  detail: string
}

const landingSectionIds = ['hero', 'flow', 'status', 'partnerReview', 'linkPlacement'] as const
const defaultPublicSiteCopy: PublicSiteCopy = {
  enabledSections: 'hero,flow,status,partnerReview,linkPlacement',
  sectionOrder: 'hero,flow,status,partnerReview,linkPlacement',
}
const landingSectionLabels: Record<(typeof landingSectionIds)[number], string> = {
  hero: 'hero',
  flow: 'flow',
  status: 'status',
  partnerReview: 'partnerReview',
  linkPlacement: 'linkPlacement',
}

function formatSignedNumber(value: number) {
  if (value === 0) return '0'
  return `${value > 0 ? '+' : '-'}${formatNumber(Math.abs(value))}`
}

function getDeltaTone(delta: number) {
  if (delta > 0) return 'up'
  if (delta < 0) return 'down'
  return 'flat'
}

function buildComparisonSummary(current: number, previous?: number) {
  if (previous == null || previous <= 0) {
    return {
      previousText: '-',
      deltaText: '-',
      tone: 'flat',
    } as const
  }

  const delta = current - previous
  const ratio = (delta / previous) * 100

  return {
    previousText: formatNumber(previous),
    deltaText: `${formatSignedNumber(delta)} (${ratio > 0 ? '+' : ratio < 0 ? '-' : ''}${Math.abs(ratio).toFixed(1)}%)`,
    tone: getDeltaTone(delta),
  } as const
}

function parseSectionList(value?: string) {
  const requested = String(value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter((item): item is (typeof landingSectionIds)[number] => Boolean(item) && landingSectionIds.includes(item as (typeof landingSectionIds)[number]))

  return requested.length > 0 ? requested : [...landingSectionIds]
}

function mergeSmokeHistory(primary?: SmokeHistoryEntry[], fallback?: SmokeHistoryEntry[]) {
  const merged = [...(primary ?? []), ...(fallback ?? [])]
  const seen = new Set<string>()
  const deduped: SmokeHistoryEntry[] = []

  for (const entry of merged) {
    if (!entry?.checkedAt || seen.has(entry.checkedAt)) continue
    seen.add(entry.checkedAt)
    deduped.push(entry)
  }

  return deduped
}

export default function OverviewPage() {
  const router = useRouter()
  const { t } = useAdminCopy()
  const [period, setPeriod] = useState<PeriodKey>('month')
  const [refreshingSnapshot, setRefreshingSnapshot] = useState(false)
  const [refreshMessage, setRefreshMessage] = useState<string | null>(null)
  const [periodData, setPeriodData] = useState(mockPeriodSummary)
  const [periodLoading, setPeriodLoading] = useState(true)
  const [periodError, setPeriodError] = useState<string | null>(null)
  const [periodUsingFallback, setPeriodUsingFallback] = useState(true)
  const [smoke, setSmoke] = useState<SmokeDto>(mockConfig.smoke)
  const [smokeLoading, setSmokeLoading] = useState(true)
  const [smokeMessage, setSmokeMessage] = useState<string | null>(null)
  const [publicSiteCopy, setPublicSiteCopy] = useState<PublicSiteCopy>(defaultPublicSiteCopy)
  const [publicSiteLoading, setPublicSiteLoading] = useState(true)
  const [publicSiteMessage, setPublicSiteMessage] = useState<string | null>(null)

  const periodOptions: Array<{ key: PeriodKey; label: string }> = [
    { key: 'week', label: t('admin.overview.period.option.week', '주') },
    { key: 'month', label: t('admin.overview.period.option.month', '월') },
    { key: 'quarter', label: t('admin.overview.period.option.quarter', '분기') },
    { key: 'year', label: t('admin.overview.period.option.year', '연') },
  ]

  const comparisonPeriodLabels: Record<ComparisonPeriodKey, string> = {
    day: t('admin.overview.compare.day', '전일'),
    week: t('admin.overview.compare.week', '전주'),
    month: t('admin.overview.compare.month', '전월'),
  }

  const res = useAdminData<{ ok: boolean; data: typeof mockSummary }>('/admin/dashboard/summary', {
    ok: true,
    data: mockSummary,
  })
  const configRes = useAdminData<{ ok: boolean; data: typeof mockConfig }>('/admin/config', {
    ok: true,
    data: mockConfig,
  })

  const data = res.data.data
  const config = configRes.data.data
  const overviewUsingFallback = res.usingFallback || periodUsingFallback
  const overviewLoading = res.loading || periodLoading || configRes.loading || smokeLoading || publicSiteLoading

  useEffect(() => {
    let cancelled = false

    async function loadPeriodSummary() {
      setPeriodLoading(true)
      setPeriodError(null)
      try {
        const result = await fetchJsonSafe<{ ok: boolean; data: typeof mockPeriodSummary }>(
          `/admin/dashboard/period-summary?period=${period}`,
          { ok: true, data: mockPeriodSummary },
        )
        if (cancelled) return
        setPeriodData(result.data.data)
        setPeriodUsingFallback(result.usingFallback)
        setPeriodError(result.usingFallback ? result.fallbackMessage ?? t('admin.overview.period.fallbackWarning', '기간 집계가 live가 아니라 fallback data야') : null)
      } catch (err) {
        if (isUnauthorizedError(err)) {
          router.replace('/login?reason=expired')
          return
        }
        if (cancelled) return
        setPeriodUsingFallback(true)
        setPeriodData(mockPeriodSummary)
        setPeriodError(err instanceof Error ? err.message : t('admin.overview.period.loadFailed', '기간 집계를 불러오지 못했어'))
      } finally {
        if (!cancelled) {
          setPeriodLoading(false)
        }
      }
    }

    void loadPeriodSummary()
    return () => {
      cancelled = true
    }
  }, [period, router, t])

  async function loadSmoke() {
    setSmokeLoading(true)
    setSmokeMessage(null)
    try {
      const response = await fetch('/api/ops/smoke', {
        cache: 'no-store',
        credentials: 'same-origin',
      })
      if (!response.ok) {
        throw new Error(`Request failed: ${response.status}`)
      }
      const payload = (await response.json()) as SmokeDto
      setSmoke(payload)
    } catch (error) {
      setSmokeMessage(error instanceof Error ? error.message : 'Smoke 결과를 불러오지 못했어')
      setSmoke({
        ...mockConfig.smoke,
        ok: false,
      })
    } finally {
      setSmokeLoading(false)
    }
  }

  async function loadPublicSiteCopy() {
    setPublicSiteLoading(true)
    setPublicSiteMessage(null)
    try {
      const response = await fetch('/v1/app-config', {
        cache: 'no-store',
        credentials: 'same-origin',
      })
      if (!response.ok) {
        throw new Error(`Request failed: ${response.status}`)
      }
      const payload = (await response.json()) as {
        data?: {
          copy?: {
            publicSite?: PublicSiteCopy
          }
        }
      }
      setPublicSiteCopy(payload.data?.copy?.publicSite ?? defaultPublicSiteCopy)
    } catch (error) {
      setPublicSiteMessage(error instanceof Error ? error.message : '공개 랜딩 app-config를 불러오지 못했어')
      setPublicSiteCopy(defaultPublicSiteCopy)
    } finally {
      setPublicSiteLoading(false)
    }
  }

  useEffect(() => {
    void loadSmoke()
    void loadPublicSiteCopy()
  }, [])

  async function onRefreshSnapshot() {
    if (res.usingFallback) {
      setRefreshMessage(t('admin.overview.refresh.blockedFallback', 'fallback/mock 상태에서는 snapshot refresh를 막아둘게'))
      return
    }
    setRefreshingSnapshot(true)
    setRefreshMessage(null)
    try {
      await postJson('/admin/dashboard/summary/refresh')
      await res.reload()
      setRefreshMessage(t('admin.overview.refresh.done', '오늘 스냅샷 갱신 완료'))
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setRefreshMessage(err instanceof Error ? err.message : t('admin.overview.refresh.failed', '스냅샷 갱신 실패'))
    } finally {
      setRefreshingSnapshot(false)
    }
  }

  async function onRefreshOverview() {
    await Promise.allSettled([
      onRefreshSnapshot(),
      configRes.reload(),
      loadSmoke(),
      loadPublicSiteCopy(),
    ])
  }

  const summaryComparisons =
    typeof (data as { comparisons?: unknown }).comparisons === 'object' && (data as { comparisons?: unknown }).comparisons
      ? ((data as { comparisons?: SummaryComparisonMap }).comparisons ?? {})
      : undefined

  const enabledSections = useMemo(() => parseSectionList(publicSiteCopy.enabledSections), [publicSiteCopy.enabledSections])
  const hiddenSections = useMemo(
    () => landingSectionIds.filter((sectionId) => !enabledSections.includes(sectionId)),
    [enabledSections],
  )
  const smokeHistory = useMemo(
    () => mergeSmokeHistory(smoke.history, config.smokeHistory),
    [config.smokeHistory, smoke.history],
  )
  const recentSmokeHistory = useMemo(() => smokeHistory.slice(0, 5), [smokeHistory])
  const smokeTargetStats = useMemo(() => {
    const stats = new Map<string, {
      key: string
      label: string
      failCount: number
      totalChecks: number
      lastStatus: number | null
      lastCheckedAt: string
      lastFailureAt: string | null
      lastError: string
    }>()

    for (const entry of smokeHistory) {
      for (const result of entry.results) {
        const current = stats.get(result.key) ?? {
          key: result.key,
          label: result.label,
          failCount: 0,
          totalChecks: 0,
          lastStatus: null,
          lastCheckedAt: '',
          lastFailureAt: null,
          lastError: '',
        }

        current.totalChecks += 1
        if (!current.lastCheckedAt) {
          current.lastCheckedAt = entry.checkedAt
          current.lastStatus = result.status
        }
        if (!result.ok) {
          current.failCount += 1
          if (!current.lastFailureAt) {
            current.lastFailureAt = entry.checkedAt
            current.lastError = result.error ?? ''
          }
        }

        stats.set(result.key, current)
      }
    }

    return Array.from(stats.values()).sort((a, b) => {
      if (b.failCount !== a.failCount) return b.failCount - a.failCount
      return a.label.localeCompare(b.label)
    })
  }, [smokeHistory])
  const failingSmokeTargets = useMemo(() => smokeTargetStats.filter((item) => item.failCount > 0), [smokeTargetStats])
  const smokeHotSpotTargets = useMemo(() => failingSmokeTargets.slice(0, 3), [failingSmokeTargets])
  const recentSmokeFailureStreak = useMemo(() => {
    let streak = 0
    for (const entry of smokeHistory) {
      if (entry.ok) break
      streak += 1
    }
    return streak
  }, [smokeHistory])
  const lastSmokeFailure = useMemo(
    () => smokeHistory.find((entry) => !entry.ok) ?? null,
    [smokeHistory],
  )

  const opsAlerts = useMemo<OverviewAlert[]>(() => {
    const alerts: OverviewAlert[] = []

    if (res.usingFallback || periodUsingFallback) {
      alerts.push({
        tone: 'warn',
        title: t('admin.overview.ops.summaryFallbackTitle', '요약 지표가 fallback 상태야'),
        detail: t('admin.overview.ops.summaryFallbackBody', 'overview 숫자 중 일부가 live가 아니라 운영 판단 전에 새로고침이나 API 상태 확인이 필요해.'),
      })
    }

    if (!configRes.loading) {
      if (!config.storageWritable) {
        alerts.push({
          tone: 'critical',
          title: t('admin.overview.ops.storageBlockedTitle', 'storage가 writable 상태가 아니야'),
          detail: config.storageErrors.length > 0
            ? `${t('admin.overview.ops.storageBlockedBody', '실패 사유를 먼저 봐야 해')}: ${config.storageErrors.join(' | ')}`
            : t('admin.overview.ops.storageBlockedBodyNoDetail', '파일 저장 경로가 막혀 있으면 스캔/브랜딩/운영 로그가 같이 흔들릴 수 있어.'),
        })
      } else if (config.storageErrors.length > 0) {
        alerts.push({
          tone: 'warn',
          title: t('admin.overview.ops.storageErrorsTitle', 'storage 경고가 남아 있어'),
          detail: config.storageErrors.join(' | '),
        })
      }

      if (!config.publicSite.dynamicLandingEnabled) {
        alerts.push({
          tone: 'warn',
          title: t('admin.overview.ops.publicSiteStaticTitle', '공개 랜딩이 dynamic surface로 안 잡혀 있어'),
          detail: t('admin.overview.ops.publicSiteStaticBody', 'admin content와 공개면이 끊기면 운영에서 문구를 바꿔도 즉시 반영되지 않아.'),
        })
      }

      if (!config.coupangPartners.affiliateReady) {
        const detail = !config.coupangPartners.accessKeyConfigured || !config.coupangPartners.secretKeyConfigured
          ? t('admin.overview.ops.coupangMissingKeysBody', '쿠팡 키가 아직 없어 live affiliate redirect는 아직 못 써.')
          : t('admin.overview.ops.coupangNotEnabledBody', '키는 있어도 runtime enabled나 affiliate readiness가 아직 완전히 안 올라왔어.')
        alerts.push({
          tone: 'warn',
          title: t('admin.overview.ops.coupangNotReadyTitle', 'Coupang live redirect가 아직 준비 전이야'),
          detail,
        })
      }
    }

    if (!smokeLoading) {
      if (!smoke.ok) {
        const failedResults = smoke.results.filter((result) => !result.ok)
        const lead = failedResults[0]
        alerts.push({
          tone: 'critical',
          title: t('admin.overview.ops.smokeFailTitle', 'operator smoke에 실패한 항목이 있어'),
          detail: lead
            ? `${lead.label} · ${lead.status ?? 'ERR'}${lead.error ? ` · ${lead.error}` : ''}${failedResults.length > 1 ? ` (+${failedResults.length - 1})` : ''}`
            : t('admin.overview.ops.smokeFailBody', '공개면, API, admin 진입점 중 최소 한 곳은 다시 확인이 필요해.'),
        })
      } else if (smokeMessage) {
        alerts.push({
          tone: 'info',
          title: t('admin.overview.ops.smokeFallbackTitle', 'smoke 결과를 최신으로 못 가져왔어'),
          detail: smokeMessage,
        })
      }
    }

    if (recentSmokeFailureStreak > 0) {
      alerts.push({
        tone: recentSmokeFailureStreak >= 2 ? 'critical' : 'warn',
        title: t('admin.overview.ops.smokeFailureStreakTitle', '최근 smoke 실패 streak이 이어지고 있어'),
        detail: `${recentSmokeFailureStreak}회 연속 실패 · ${t('admin.overview.ops.smokeLastFailureLabel', '마지막 실패')} ${lastSmokeFailure ? formatDate(lastSmokeFailure.checkedAt) : '-'}`,
      })
    }

    if (!publicSiteLoading && hiddenSections.length >= 2) {
      alerts.push({
        tone: 'warn',
        title: t('admin.overview.ops.hiddenSectionsTitle', '공개 랜딩에서 숨긴 섹션이 많은 편이야'),
        detail: `${hiddenSections.length}/${landingSectionIds.length} hidden · ${hiddenSections.map((sectionId) => landingSectionLabels[sectionId]).join(', ')}`,
      })
    } else if (!publicSiteLoading && publicSiteMessage) {
      alerts.push({
        tone: 'info',
        title: t('admin.overview.ops.publicSiteConfigFallbackTitle', '공개 랜딩 section config를 live로 못 읽었어'),
        detail: publicSiteMessage,
      })
    }

    return alerts
  }, [
    config,
    configRes.loading,
    hiddenSections,
    periodUsingFallback,
    publicSiteLoading,
    publicSiteMessage,
    res.usingFallback,
    lastSmokeFailure,
    recentSmokeFailureStreak,
    smoke,
    smokeLoading,
    smokeMessage,
    t,
  ])

  const criticalAlertCount = opsAlerts.filter((alert) => alert.tone === 'critical').length
  const warnAlertCount = opsAlerts.filter((alert) => alert.tone === 'warn').length
  const infoAlertCount = opsAlerts.filter((alert) => alert.tone === 'info').length

  const snapshotSummaryGroups = [
    {
      title: t('admin.overview.snapshot.data', 'Data'),
      items: [
        {
          label: 'DAU',
          value: formatNumber(data.dau),
          comparisons: [
            {
              period: 'day' as const,
              ...buildComparisonSummary(data.dau, summaryComparisons?.dau?.day),
            },
          ],
        },
        {
          label: 'WAU',
          value: formatNumber(data.wau),
          comparisons: [
            {
              period: 'week' as const,
              ...buildComparisonSummary(data.wau, summaryComparisons?.wau?.week),
            },
          ],
        },
        {
          label: t('admin.overview.snapshot.mau', 'MAU'),
          value: formatNumber(data.mau),
          comparisons: [
            {
              period: 'month' as const,
              ...buildComparisonSummary(data.mau, summaryComparisons?.mau?.month),
            },
          ],
        },
      ],
    },
    {
      title: t('admin.overview.snapshot.scan', 'Scan'),
      items: [
        { label: t('admin.overview.snapshot.totalScans', 'Total Scans'), value: formatNumber(data.totalScans) },
        { label: t('admin.overview.snapshot.scanSuccess', 'Scan Success'), value: formatPercent(data.scanSuccessRate) },
        { label: t('admin.overview.snapshot.cartSaveRate', 'Cart Save Rate'), value: formatPercent(data.cartSaveRate) },
      ],
    },
    {
      title: t('admin.overview.snapshot.members', 'Members'),
      items: [
        { label: t('admin.overview.snapshot.activeMembers', 'Active Members'), value: formatNumber(data.lifecycle.activeMembers) },
        { label: t('admin.overview.snapshot.guestProfiles', 'Guest Profiles'), value: formatNumber(data.lifecycle.guestProfiles) },
        {
          label: t('admin.overview.snapshot.guestToMemberConversion', 'Guest to Member'),
          value: formatPercent(data.lifecycle.guestToMemberConversionRate),
        },
      ],
    },
    {
      title: t('admin.overview.snapshot.ad', 'Ad'),
      items: [
        { label: t('admin.overview.snapshot.adImpressions', 'Ad Impressions'), value: formatNumber(data.adImpressions) },
        { label: t('admin.overview.snapshot.adClicks', 'Ad Clicks'), value: formatNumber(data.adClicks) },
        { label: t('admin.overview.snapshot.adCtr', 'Ad CTR'), value: formatPercent(data.adCtr) },
      ],
    },
  ] as const

  const cumulativeSummaryGroups = [
    {
      title: t('admin.overview.cumulative.users', 'Users'),
      columns: 2,
      items: [
        [t('admin.overview.cumulative.activeUsers', 'Active Users'), formatNumber(periodData.activeUsers)],
        [t('admin.overview.cumulative.newUsers', 'New Users'), formatNumber(periodData.newUsers)],
      ],
    },
    {
      title: t('admin.overview.cumulative.scan', 'Scan'),
      columns: 3,
      items: [
        [t('admin.overview.cumulative.scans', 'Scans'), formatNumber(periodData.totalScans)],
        [t('admin.overview.cumulative.successful', 'Successful'), formatNumber(periodData.successfulScans)],
        [t('admin.overview.cumulative.cartSaves', 'Cart Saves'), formatNumber(periodData.cartSaves)],
      ],
    },
  ] as const

  const cumulativeAdRows = (periodData.adSlots ?? []).map((slot) => ({
    name: slot.slotKey,
    impressions: formatNumber(slot.impressions ?? 0),
    clicks: formatNumber(slot.clicks ?? 0),
    ctr: formatPercent(slot.ctr ?? 0),
  }))

  return (
    <div>
      <PageHeader
        badge={overviewUsingFallback ? t('admin.common.badge.fallback', 'Fallback data') : overviewLoading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.overview.title', 'Overview')}
        description={t('admin.overview.desc', '핵심 지표 요약')}
        onRefresh={() => void onRefreshOverview()}
        refreshing={refreshingSnapshot || configRes.loading || smokeLoading || publicSiteLoading}
        actionLabel={t('admin.common.refresh', '데이터 불러오기')}
        inlineRefresh
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {configRes.error ? <div className="loginError" style={{ marginBottom: 16 }}>{configRes.error}</div> : null}
      {refreshMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{refreshMessage}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.overview.warning.fallbackTitle', 'Live summary unavailable.')}</strong>{' '}
          {t('admin.overview.warning.fallbackBody', '지금 보이는 값은 fallback/mock data일 수 있어서 운영 판단 기준으로 쓰면 안 돼요.')}
          {res.fallbackMessage ? ` (${res.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="card" style={{ marginBottom: 16, borderColor: opsAlerts.length > 0 ? '#ffd6dc' : '#d9f4e3', background: opsAlerts.length > 0 ? 'linear-gradient(180deg, #fff, #fff7f8)' : 'linear-gradient(180deg, #fff, #f8fffb)' }}>
        <div className="sectionHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.overview.ops.title', 'Operator warnings')}</h2>
            <p className="pageDesc" style={{ marginTop: 0, marginBottom: 0 }}>{t('admin.overview.ops.desc', 'overview 첫 화면에서 지금 바로 봐야 할 운영 신호만 모아둔 카드야.')}</p>
          </div>
          <div className="metaRow" style={{ marginTop: 0, justifyContent: 'flex-end' }}>
            <span className="metaPill">critical {criticalAlertCount}</span>
            <span className="metaPill">warn {warnAlertCount}</span>
            <span className="metaPill">info {infoAlertCount}</span>
            <span className="metaPill">smoke {smokeLoading ? 'loading' : smoke.ok ? 'ok' : 'check'}</span>
            <span className="metaPill">streak {recentSmokeFailureStreak}</span>
            <span className="metaPill">last fail {lastSmokeFailure ? formatDate(lastSmokeFailure.checkedAt) : '-'}</span>
          </div>
        </div>

        <div className="metaRow" style={{ marginTop: 0, marginBottom: 12 }}>
          <span className="metaPill">hot spots</span>
          {smokeHotSpotTargets.length === 0 ? (
            <span className="metaPill">none</span>
          ) : (
            smokeHotSpotTargets.map((target) => (
              <span key={target.key} className="metaPill">{target.key} {target.failCount}회</span>
            ))
          )}
        </div>

        {opsAlerts.length === 0 ? (
          <div style={{ padding: '12px 14px', borderRadius: 14, border: '1px solid rgba(34,197,94,0.18)', background: 'rgba(240,253,244,0.75)', color: '#166534', fontWeight: 700 }}>
            {t('admin.overview.ops.empty', '지금은 눈에 띄는 운영 경고가 없어. smoke, storage, Coupang runtime, public landing section 상태가 모두 안정적이야.')}
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 10 }}>
            {opsAlerts.map((alert, index) => {
              const toneStyles =
                alert.tone === 'critical'
                  ? {
                      border: '1px solid rgba(225,29,72,0.22)',
                      background: 'rgba(255,241,242,0.82)',
                      badgeBackground: '#fee2e2',
                      badgeColor: '#be123c',
                      textColor: '#881337',
                    }
                  : alert.tone === 'warn'
                    ? {
                        border: '1px solid rgba(245,158,11,0.24)',
                        background: 'rgba(255,247,237,0.92)',
                        badgeBackground: '#ffedd5',
                        badgeColor: '#b45309',
                        textColor: '#9a3412',
                      }
                    : {
                        border: '1px solid rgba(59,130,246,0.18)',
                        background: 'rgba(239,246,255,0.85)',
                        badgeBackground: '#dbeafe',
                        badgeColor: '#1d4ed8',
                        textColor: '#1e3a8a',
                      }
              return (
                <div key={`${alert.title}-${index}`} style={{ display: 'grid', gridTemplateColumns: 'auto 1fr', gap: 12, alignItems: 'flex-start', padding: '12px 14px', borderRadius: 14, border: toneStyles.border, background: toneStyles.background }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', minWidth: 74, padding: '7px 10px', borderRadius: 999, background: toneStyles.badgeBackground, color: toneStyles.badgeColor, fontSize: 12, fontWeight: 800, textTransform: 'uppercase' }}>
                    {alert.tone}
                  </span>
                  <div>
                    <div style={{ fontWeight: 800, color: toneStyles.textColor, marginBottom: 4 }}>{alert.title}</div>
                    <div style={{ color: '#444', fontSize: 13, fontWeight: 600, lineHeight: 1.55 }}>{alert.detail}</div>
                  </div>
                </div>
              )
            })}
          </div>
        )}

        <div style={{ display: 'grid', gap: 10, marginTop: 16 }}>
          <div style={{ fontSize: 12, fontWeight: 800, color: '#64748b', letterSpacing: '0.04em', textTransform: 'uppercase' }}>
            Recent smoke history
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 10 }}>
            {recentSmokeHistory.map((entry, index) => {
              const failedResults = entry.results.filter((result) => !result.ok)
              const lead = failedResults[0]
              return (
                <div
                  key={`${entry.checkedAt}-${index}`}
                  style={{
                    padding: '12px 14px',
                    borderRadius: 14,
                    border: `1px solid ${entry.ok ? 'rgba(34,197,94,0.18)' : 'rgba(245,158,11,0.24)'}`,
                    background: entry.ok ? 'rgba(255,255,255,0.96)' : 'rgba(255,247,237,0.9)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
                    <span className="metaPill">{entry.ok ? 'ok' : 'check'}</span>
                    <span className="metaPill">fail {entry.failureCount}</span>
                  </div>
                  <div style={{ fontWeight: 800, color: '#0f172a', marginBottom: 6 }}>{formatDate(entry.checkedAt)}</div>
                  <div style={{ fontSize: 13, color: '#475569', fontWeight: 600, lineHeight: 1.5 }}>
                    {lead
                      ? `${lead.label} · ${lead.status ?? 'ERR'}${lead.error ? ` · ${lead.error}` : ''}`
                      : '모든 점검 대상 정상'}
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        <div style={{ display: 'grid', gap: 10, marginTop: 16 }}>
          <div style={{ fontSize: 12, fontWeight: 800, color: '#64748b', letterSpacing: '0.04em', textTransform: 'uppercase' }}>
            Frequent failing targets
          </div>
          {failingSmokeTargets.length === 0 ? (
            <div style={{ padding: '12px 14px', borderRadius: 14, border: '1px solid rgba(34,197,94,0.18)', background: 'rgba(255,255,255,0.96)', color: '#166534', fontWeight: 700 }}>
              아직 누적된 smoke target 실패가 없어.
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 10 }}>
              {failingSmokeTargets.slice(0, 5).map((target) => (
                <div
                  key={target.key}
                  style={{
                    padding: '12px 14px',
                    borderRadius: 14,
                    border: '1px solid rgba(245,158,11,0.24)',
                    background: 'rgba(255,247,237,0.9)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
                    <span className="metaPill">fail {target.failCount}</span>
                    <span className="metaPill">checks {target.totalChecks}</span>
                  </div>
                  <div style={{ fontWeight: 800, color: '#0f172a', marginBottom: 6 }}>{target.label}</div>
                  <div style={{ fontSize: 13, color: '#475569', fontWeight: 600, lineHeight: 1.5 }}>
                    {target.lastFailureAt ? `마지막 실패 ${formatDate(target.lastFailureAt)}` : '마지막 실패 기록 없음'}
                    {target.lastStatus != null ? ` · 최근 status ${target.lastStatus}` : ''}
                    {target.lastError ? ` · ${target.lastError}` : ''}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="metaRow" style={{ marginBottom: 16 }}>
        <div className="metaPill">{t('admin.overview.meta.snapshotDate', '기준일')} {data.snapshotDate ?? '-'}</div>
        <div className="metaPill">{t('admin.overview.meta.generatedAt', '생성시각')} {formatDate(data.snapshotGeneratedAt)}</div>
        <div className="metaPill">{t('admin.overview.meta.source', '소스')} {data.snapshotSource ?? '-'}</div>
        <div className="metaPill">{t('admin.overview.meta.mode', '모드')} {data.dataMode ?? '-'}</div>
        <div className="metaPill">{t('admin.overview.meta.period', 'period')} {period}</div>
        <div className="metaPill">{t('admin.overview.meta.periodState', 'period state')} {periodLoading ? t('admin.common.badge.loading', 'Loading...') : periodUsingFallback ? t('admin.common.badge.fallback', 'Fallback data') : t('admin.common.badge.live', 'Live data')}</div>
        <div className="metaPill">landing {enabledSections.length}/{landingSectionIds.length}</div>
        <div className="metaPill">smoke checked {formatDate(smoke.checkedAt)}</div>
        <div className="metaPill">smoke streak {recentSmokeFailureStreak}</div>
        <div className="metaPill">last smoke fail {lastSmokeFailure ? formatDate(lastSmokeFailure.checkedAt) : '-'}</div>
      </div>

      <div className="summaryClusterGrid">
        {snapshotSummaryGroups.map((group) => (
          <div key={group.title} className="card summaryClusterCard">
            <div className="kpiLabel summaryClusterTitle">{group.title}</div>
            <div className="summaryClusterInner">
              {group.items.map((item) => (
                <div key={item.label} className="summaryMiniCard">
                  <div>
                    <div className="kpiLabel summaryMiniLabel">{item.label}</div>
                    <div className="kpiValue summaryMiniValue">{item.value}</div>
                  </div>
                  {item.comparisons ? (
                    <div className="summaryComparisonList">
                      {item.comparisons.map((comparison) => (
                        <div key={comparison.period} className="summaryComparisonRow">
                          <span className="summaryComparisonPeriod">{comparisonPeriodLabels[comparison.period]}</span>
                          <span className="summaryComparisonValue">{comparison.previousText}</span>
                          <span className={`summaryComparisonDelta ${comparison.tone}`}>{comparison.deltaText}</span>
                        </div>
                      ))}
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="section">
        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.overview.period.title', '누적 보기')}</h2>
              <p className="pageDesc">{t('admin.overview.period.desc', '선택한 기간 안에서 집계된 누적 값')}</p>
            </div>
            <div className="segmentedControl">
              {periodOptions.map((option) => (
                <button
                  key={option.key}
                  type="button"
                  className={`segmentedBtn ${period === option.key ? 'active' : ''}`}
                  onClick={() => setPeriod(option.key)}
                >
                  {option.label}
                </button>
              ))}
            </div>
          </div>

          {periodError ? (
            <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
              <strong>{t('admin.overview.warning.periodFallbackTitle', 'Period summary fallback active.')}</strong>{' '}
              {t('admin.overview.warning.periodFallbackBody', '기간 집계도 live 응답이 아니라 fallback/mock data일 수 있어요.')}
              {` (${periodError})`}
            </div>
          ) : null}

          <div className="metaRow" style={{ marginBottom: 16 }}>
            <div className="metaPill">{t('admin.overview.period.range', '기간')} {periodData.rangeStart} ~ {periodData.rangeEnd}</div>
            <div className="metaPill">{t('admin.overview.period.state', '상태')} {periodLoading ? t('admin.common.badge.loading', 'Loading...') : periodUsingFallback ? t('admin.common.badge.fallback', 'Fallback data') : t('admin.common.badge.live', 'Live data')}</div>
            <div className="metaPill">{t('admin.overview.period.deviceReady', 'device 준비')} {periodData.deviceBreakdownReady ? t('admin.common.ready', '완료') : t('admin.common.notReady', '미완료')}</div>
          </div>

          <div className="cumulativeClusterGrid">
            {cumulativeSummaryGroups.map((group) => (
              <div key={group.title} className="card cumulativeClusterCard">
                <div className="kpiLabel summaryClusterTitle">{group.title}</div>
                <div className={`cumulativeClusterInner ${group.columns === 2 ? 'cols2' : 'cols3'}`}>
                  {group.items.map(([label, value]) => (
                    <div key={label} className="summaryMiniCard">
                      <div className="kpiLabel summaryMiniLabel">{label}</div>
                      <div className="kpiValue summaryMiniValue">{value}</div>
                    </div>
                  ))}
                </div>
              </div>
            ))}

            <div className="card cumulativeClusterCard">
              <div className="kpiLabel summaryClusterTitle">{t('admin.overview.cumulative.ad', 'Ad')}</div>
              <div className="cumulativeClusterInner cols3">
                <div className="summaryMiniCard">
                  <div className="kpiLabel summaryMiniLabel">{t('admin.overview.cumulative.adImpressions', 'Ad Impressions')}</div>
                  <div className="kpiValue summaryMiniValue">{formatNumber(periodData.adImpressions)}</div>
                </div>
                <div className="summaryMiniCard">
                  <div className="kpiLabel summaryMiniLabel">{t('admin.overview.cumulative.adClicks', 'Ad Clicks')}</div>
                  <div className="kpiValue summaryMiniValue">{formatNumber(periodData.adClicks)}</div>
                </div>
                <div className="summaryMiniCard">
                  <div className="kpiLabel summaryMiniLabel">{t('admin.overview.cumulative.adCtr', 'Ad CTR')}</div>
                  <div className="kpiValue summaryMiniValue">{formatPercent(periodData.adCtr)}</div>
                </div>
              </div>

              <div className="cumulativeAdRows">
                <div className="cumulativeAdRow cumulativeAdRowHead" aria-hidden="true">
                  <div className="cumulativeAdName">{t('admin.overview.cumulative.slot', 'Slot')}</div>
                  <div className="cumulativeAdValue">{t('admin.overview.cumulative.impressions', 'Impressions')}</div>
                  <div className="cumulativeAdValue">{t('admin.overview.cumulative.clicks', 'Clicks')}</div>
                  <div className="cumulativeAdValue">{t('admin.overview.cumulative.ctr', 'CTR')}</div>
                </div>
                {cumulativeAdRows.map((row) => (
                  <div key={row.name} className="cumulativeAdRow">
                    <div className="cumulativeAdName">{row.name}</div>
                    <div className="cumulativeAdValue">{row.impressions}</div>
                    <div className="cumulativeAdValue">{row.clicks}</div>
                    <div className="cumulativeAdValue">{row.ctr}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>

        </div>
      </div>
    </div>
  )
}
