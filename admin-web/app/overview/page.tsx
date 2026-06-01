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
  hero: '메인',
  flow: '이용 흐름',
  status: '지원 범위',
  partnerReview: '파트너 검토',
  linkPlacement: '링크 위치',
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
      setRefreshMessage(t('admin.overview.refresh.blockedFallback', '대체 데이터 상태에서는 스냅샷 갱신을 막아둘게'))
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
      recentFailureSummary: string
      reasonCounts: Map<string, number>
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
          recentFailureSummary: '',
          reasonCounts: new Map<string, number>(),
        }

        current.totalChecks += 1
        if (!current.lastCheckedAt) {
          current.lastCheckedAt = entry.checkedAt
          current.lastStatus = result.status
        }
        if (!result.ok) {
          const failureSummary = `${result.status ?? 'ERR'}${result.error ? ` · ${result.error}` : ''}`
          current.failCount += 1
          current.reasonCounts.set(failureSummary, (current.reasonCounts.get(failureSummary) ?? 0) + 1)
          if (!current.lastFailureAt) {
            current.lastFailureAt = entry.checkedAt
            current.lastError = result.error ?? ''
            current.recentFailureSummary = failureSummary
          }
        }

        stats.set(result.key, current)
      }
    }

    return Array.from(stats.values())
      .map((item) => {
        const topReasonEntry = Array.from(item.reasonCounts.entries()).sort((a, b) => b[1] - a[1])[0]
        return {
          key: item.key,
          label: item.label,
          failCount: item.failCount,
          totalChecks: item.totalChecks,
          lastStatus: item.lastStatus,
          lastCheckedAt: item.lastCheckedAt,
          lastFailureAt: item.lastFailureAt,
          lastError: item.lastError,
          recentFailureSummary: item.recentFailureSummary,
          topFailureReason: topReasonEntry?.[0] ?? '',
          topFailureReasonCount: topReasonEntry?.[1] ?? 0,
        }
      })
      .sort((a, b) => {
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
        title: t('admin.overview.ops.summaryFallbackTitle', '요약 지표 대체 데이터'),
        detail: t('admin.overview.ops.summaryFallbackBody', '실데이터 재확인 필요'),
      })
    }

    if (!configRes.loading) {
      if (!config.storageWritable) {
        alerts.push({
          tone: 'critical',
          title: t('admin.overview.ops.storageBlockedTitle', '저장 경로 쓰기 차단'),
          detail: config.storageErrors.length > 0
            ? `${t('admin.overview.ops.storageBlockedBody', '오류 사유')}: ${config.storageErrors.join(' | ')}`
            : t('admin.overview.ops.storageBlockedBodyNoDetail', '저장 경로 확인 필요'),
        })
      } else if (config.storageErrors.length > 0) {
        alerts.push({
          tone: 'warn',
          title: t('admin.overview.ops.storageErrorsTitle', '저장 경로 경고'),
          detail: config.storageErrors.join(' | '),
        })
      }

      if (!config.publicSite.dynamicLandingEnabled) {
        alerts.push({
          tone: 'warn',
          title: t('admin.overview.ops.publicSiteStaticTitle', '랜딩 실노출 분리'),
          detail: t('admin.overview.ops.publicSiteStaticBody', '랜딩 연동 확인 필요'),
        })
      }

      if (!config.coupangPartners.affiliateReady) {
        const detail = !config.coupangPartners.accessKeyConfigured || !config.coupangPartners.secretKeyConfigured
          ? t('admin.overview.ops.coupangMissingKeysBody', '쿠팡 키 미설정')
          : t('admin.overview.ops.coupangNotEnabledBody', '쿠팡 연동 준비 미완료')
        alerts.push({
          tone: 'warn',
          title: t('admin.overview.ops.coupangNotReadyTitle', '쿠팡 연동 준비 전'),
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
          title: t('admin.overview.ops.smokeFailTitle', '점검 실패 항목'),
          detail: lead
            ? `${lead.label} · ${lead.status ?? 'ERR'}${lead.error ? ` · ${lead.error}` : ''}${failedResults.length > 1 ? ` (+${failedResults.length - 1})` : ''}`
            : t('admin.overview.ops.smokeFailBody', '공개면/API/어드민 재확인 필요'),
        })
      } else if (smokeMessage) {
        alerts.push({
          tone: 'info',
          title: t('admin.overview.ops.smokeFallbackTitle', '점검 결과 불러오기 실패'),
          detail: smokeMessage,
        })
      }
    }

    if (recentSmokeFailureStreak > 0) {
      alerts.push({
        tone: recentSmokeFailureStreak >= 2 ? 'critical' : 'warn',
        title: t('admin.overview.ops.smokeFailureStreakTitle', '점검 연속 실패'),
        detail: `${recentSmokeFailureStreak}회 연속 · ${t('admin.overview.ops.smokeLastFailureLabel', '최근 실패')} ${lastSmokeFailure ? formatDate(lastSmokeFailure.checkedAt) : '-'}`,
      })
    }

    if (!publicSiteLoading && hiddenSections.length >= 2) {
      alerts.push({
        tone: 'warn',
        title: t('admin.overview.ops.hiddenSectionsTitle', '랜딩 숨김 섹션 다수'),
        detail: `${hiddenSections.length}/${landingSectionIds.length} 숨김 · ${hiddenSections.map((sectionId) => landingSectionLabels[sectionId]).join(', ')}`,
      })
    } else if (!publicSiteLoading && publicSiteMessage) {
      alerts.push({
        tone: 'info',
        title: t('admin.overview.ops.publicSiteConfigFallbackTitle', '랜딩 설정 불러오기 실패'),
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
      title: t('admin.overview.snapshot.data', '이용'),
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
      title: t('admin.overview.snapshot.scan', '스캔'),
      items: [
        { label: t('admin.overview.snapshot.totalScans', '총 스캔'), value: formatNumber(data.totalScans) },
        { label: t('admin.overview.snapshot.scanSuccess', '스캔 성공률'), value: formatPercent(data.scanSuccessRate) },
        { label: t('admin.overview.snapshot.cartSaveRate', '카트 저장률'), value: formatPercent(data.cartSaveRate) },
      ],
    },
    {
      title: t('admin.overview.snapshot.members', '회원'),
      items: [
        { label: t('admin.overview.snapshot.activeMembers', '활성 회원'), value: formatNumber(data.lifecycle.activeMembers) },
        { label: t('admin.overview.snapshot.guestProfiles', '게스트'), value: formatNumber(data.lifecycle.guestProfiles) },
        {
          label: t('admin.overview.snapshot.guestToMemberConversion', '게스트 전환률'),
          value: formatPercent(data.lifecycle.guestToMemberConversionRate),
        },
      ],
    },
    {
      title: t('admin.overview.snapshot.ad', '광고'),
      items: [
        { label: t('admin.overview.snapshot.adImpressions', '노출 수'), value: formatNumber(data.adImpressions) },
        { label: t('admin.overview.snapshot.adClicks', '클릭 수'), value: formatNumber(data.adClicks) },
        { label: t('admin.overview.snapshot.adCtr', '클릭률'), value: formatPercent(data.adCtr) },
      ],
    },
  ] as const

  const cumulativeSummaryGroups = [
    {
      title: t('admin.overview.cumulative.users', '이용자'),
      columns: 2,
      items: [
        [t('admin.overview.cumulative.activeUsers', '활성 이용자'), formatNumber(periodData.activeUsers)],
        [t('admin.overview.cumulative.newUsers', '신규 이용자'), formatNumber(periodData.newUsers)],
      ],
    },
    {
      title: t('admin.overview.cumulative.scan', 'Scan'),
      columns: 3,
      items: [
        [t('admin.overview.cumulative.scans', '스캔 수'), formatNumber(periodData.totalScans)],
        [t('admin.overview.cumulative.successful', '성공 수'), formatNumber(periodData.successfulScans)],
        [t('admin.overview.cumulative.cartSaves', '저장 수'), formatNumber(periodData.cartSaves)],
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
    <div className="exploreCompactPage">
      <PageHeader
        badge={overviewUsingFallback ? '대체 데이터' : overviewLoading ? '불러오는 중' : '실데이터'}
        title={'대시보드'}
        description={'핵심 지표'}
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
          <strong>실데이터 불러오기 실패</strong>{' '}
          현재 값은 대체 데이터일 수 있어. 운영 판단 기준 사용 금지.
          {res.fallbackMessage ? ` (${res.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">DAU</div>
          <div className="exploreSummaryValue">{formatNumber(data.dau)}</div>
          <div className="exploreSummaryNote">전일 비교 {summaryComparisons?.dau?.day != null ? formatSignedNumber(data.dau - summaryComparisons.dau.day) : '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">WAU</div>
          <div className="exploreSummaryValue">{formatNumber(data.wau)}</div>
          <div className="exploreSummaryNote">전주 비교 {summaryComparisons?.wau?.week != null ? formatSignedNumber(data.wau - summaryComparisons.wau.week) : '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">MAU</div>
          <div className="exploreSummaryValue">{formatNumber(data.mau)}</div>
          <div className="exploreSummaryNote">전월 비교 {summaryComparisons?.mau?.month != null ? formatSignedNumber(data.mau - summaryComparisons.mau.month) : '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">스캔 성공률</div>
          <div className="exploreSummaryValue">{formatPercent(data.scanSuccessRate)}</div>
          <div className="exploreSummaryNote">총 스캔 {formatNumber(data.totalScans)}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">점검 상태</div>
          <div className="exploreSummaryValue">{smokeLoading ? '점검중' : smoke.ok ? '정상' : '확인'}</div>
          <div className="exploreSummaryNote">실패 연속 {recentSmokeFailureStreak} · 알림 {opsAlerts.length}</div>
        </div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard overviewOpsCard" style={{ marginBottom: 12, borderColor: opsAlerts.length > 0 ? '#ffd6dc' : '#d9f4e3', background: opsAlerts.length > 0 ? 'linear-gradient(180deg, #fff, #fff7f8)' : 'linear-gradient(180deg, #fff, #f8fffb)' }}>
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>운영 알림</h2>
            <p className="pageDesc" style={{ marginTop: 0, marginBottom: 0 }}>즉시 확인 신호</p>
          </div>
          <div className="metaRow" style={{ marginTop: 0, justifyContent: 'flex-end' }}>
            <span className="metaPill">긴급 {criticalAlertCount}</span>
            <span className="metaPill">주의 {warnAlertCount}</span>
            <span className="metaPill">안내 {infoAlertCount}</span>
            <span className="metaPill">점검 {smokeLoading ? '불러오는 중' : smoke.ok ? '정상' : '확인'}</span>
            <span className="metaPill">실패 연속 {recentSmokeFailureStreak}</span>
            <span className="metaPill">최근 실패 {lastSmokeFailure ? formatDate(lastSmokeFailure.checkedAt) : '-'}</span>
          </div>
        </div>

        <div className="opsSignalGrid">
          {smokeHotSpotTargets.length === 0 ? (
            <div className="opsSignalCard" style={{ borderColor: 'rgba(34,197,94,0.18)', background: 'rgba(240,253,244,0.7)' }}>
              <div className="opsSignalLabel">반복 오류</div>
              <div className="opsSignalValue">반복 실패 없음</div>
              <div className="opsSignalHint">누적 반복 실패 없음</div>
            </div>
          ) : (
            smokeHotSpotTargets.map((target) => (
              <div key={target.key} className="opsSignalCard" style={{ borderColor: 'rgba(245,158,11,0.24)', background: 'rgba(255,247,237,0.9)' }}>
                <div className="opsSignalLabel">반복 오류</div>
                <div className="opsSignalValue">{target.label}</div>
                <div className="opsSignalHint">
                  {target.failCount}회 실패 / {target.totalChecks}회 점검
                  {target.topFailureReason ? ` · 대표 원인 ${target.topFailureReason}` : ''}
                </div>
              </div>
            ))
          )}
        </div>

        {opsAlerts.length === 0 ? (
          <div style={{ padding: '12px 14px', borderRadius: 14, border: '1px solid rgba(34,197,94,0.18)', background: 'rgba(240,253,244,0.75)', color: '#166534', fontWeight: 700 }}>
            {t('admin.overview.ops.empty', '운영 경고 없음')}
          </div>
        ) : (
          <div className="overviewAlertGrid">
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
                <div key={`${alert.title}-${index}`} className="overviewAlertRow" style={{ border: toneStyles.border, background: toneStyles.background }}>
                  <span className="overviewAlertBadge" style={{ background: toneStyles.badgeBackground, color: toneStyles.badgeColor }}>
                    {alert.tone === 'critical' ? '긴급' : alert.tone === 'warn' ? '주의' : '안내'}
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

        <div className="overviewSubsection">
          <div className="overviewSubsectionTitle">
            최근 점검
          </div>
          <div className="overviewMiniLogGrid">
            {recentSmokeHistory.map((entry, index) => {
              const failedResults = entry.results.filter((result) => !result.ok)
              const lead = failedResults[0]
              return (
                <div
                  key={`${entry.checkedAt}-${index}`}
                  className="overviewMiniLogCard"
                  style={{
                    border: `1px solid ${entry.ok ? 'rgba(34,197,94,0.18)' : 'rgba(245,158,11,0.24)'}`,
                    background: entry.ok ? 'rgba(255,255,255,0.96)' : 'rgba(255,247,237,0.9)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
                    <span className="metaPill">{entry.ok ? '정상' : '확인'}</span>
                    <span className="metaPill">실패 {entry.failureCount}</span>
                  </div>
                  <div style={{ fontWeight: 800, color: '#0f172a', marginBottom: 6 }}>{formatDate(entry.checkedAt)}</div>
                  <div style={{ fontSize: 13, color: '#475569', fontWeight: 600, lineHeight: 1.5 }}>
                    {lead
                      ? `${lead.label} · ${lead.status ?? 'ERR'}${lead.error ? ` · ${lead.error}` : ''}`
                      : '전체 정상'}
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        <div className="overviewSubsection">
          <div className="overviewSubsectionTitle">
            반복 오류 대상
          </div>
          {failingSmokeTargets.length === 0 ? (
            <div style={{ padding: '12px 14px', borderRadius: 14, border: '1px solid rgba(34,197,94,0.18)', background: 'rgba(255,255,255,0.96)', color: '#166534', fontWeight: 700 }}>
              누적 점검 실패 없음
            </div>
          ) : (
            <div className="overviewMiniLogGrid">
              {failingSmokeTargets.slice(0, 5).map((target) => (
                <div
                  key={target.key}
                  className="overviewMiniLogCard"
                  style={{
                    border: '1px solid rgba(245,158,11,0.24)',
                    background: 'rgba(255,247,237,0.9)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
                    <span className="metaPill">실패 {target.failCount}</span>
                    <span className="metaPill">점검 {target.totalChecks}</span>
                  </div>
                  <div style={{ fontWeight: 800, color: '#0f172a', marginBottom: 6 }}>{target.label}</div>
                  <div style={{ fontSize: 13, color: '#475569', fontWeight: 600, lineHeight: 1.5 }}>
                    {target.lastFailureAt ? `마지막 실패 ${formatDate(target.lastFailureAt)}` : '마지막 실패 기록 없음'}
                    {target.lastStatus != null ? ` · 최근 상태 ${target.lastStatus}` : ''}
                    {target.topFailureReason ? ` · 대표 원인 ${target.topFailureReason}${target.topFailureReasonCount > 1 ? ` (${target.topFailureReasonCount}회)` : ''}` : ''}
                    {target.recentFailureSummary && target.recentFailureSummary !== target.topFailureReason ? ` · 최근 실패 ${target.recentFailureSummary}` : ''}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="metaRow section" style={{ marginTop: 8, marginBottom: 12 }}>
        <div className="metaPill">{t('admin.overview.meta.snapshotDate', '기준일')} {data.snapshotDate ?? '-'}</div>
        <div className="metaPill">{t('admin.overview.meta.generatedAt', '생성시각')} {formatDate(data.snapshotGeneratedAt)}</div>
        <div className="metaPill">{t('admin.overview.meta.source', '소스')} {data.snapshotSource ?? '-'}</div>
        <div className="metaPill">{t('admin.overview.meta.mode', '모드')} {data.dataMode ?? '-'}</div>
        <div className="metaPill">기간 {period}</div>
        <div className="metaPill">기간 상태 {periodLoading ? '불러오는 중' : periodUsingFallback ? '대체 데이터' : '실데이터'}</div>
        <div className="metaPill">랜딩 {enabledSections.length}/{landingSectionIds.length}</div>
        <div className="metaPill">점검 시각 {formatDate(smoke.checkedAt)}</div>
        <div className="metaPill">실패 연속 {recentSmokeFailureStreak}</div>
        <div className="metaPill">최근 실패 {lastSmokeFailure ? formatDate(lastSmokeFailure.checkedAt) : '-'}</div>
      </div>

      <div className="summaryClusterGrid overviewSummaryClusterGrid">
        {snapshotSummaryGroups.map((group) => (
          <div key={group.title} className="card summaryClusterCard overviewSummaryClusterCard">
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
        <div className="card exploreDenseCard exploreSheetCard overviewPeriodCard">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>누적 집계</h2>
              <p className="pageDesc">선택 기간 누적값</p>
            </div>
            <div className="segmentedControl overviewSegmentedControl">
              {periodOptions.map((option) => (
                <button
                  key={option.key}
                  type="button"
                  className={`segmentedBtn overviewSegmentedBtn ${period === option.key ? 'active' : ''}`}
                  onClick={() => setPeriod(option.key)}
                >
                  {option.label}
                </button>
              ))}
            </div>
          </div>

          {periodError ? (
            <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
              <strong>기간 집계 대체 데이터</strong>{' '}
              기간 집계도 대체 데이터일 수 있어.
              {` (${periodError})`}
            </div>
          ) : null}

          <div className="metaRow section" style={{ marginTop: 8, marginBottom: 12 }}>
            <div className="metaPill">{t('admin.overview.period.range', '기간')} {periodData.rangeStart} ~ {periodData.rangeEnd}</div>
            <div className="metaPill">{t('admin.overview.period.state', '상태')} {periodLoading ? '불러오는 중' : periodUsingFallback ? '대체 데이터' : '실데이터'}</div>
            <div className="metaPill">{t('admin.overview.period.deviceReady', '기기 준비')} {periodData.deviceBreakdownReady ? '완료' : '미완료'}</div>
          </div>

          <div className="cumulativeClusterGrid overviewCumulativeClusterGrid">
            {cumulativeSummaryGroups.map((group) => (
              <div key={group.title} className="card cumulativeClusterCard overviewSummaryClusterCard">
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

            <div className="card cumulativeClusterCard overviewSummaryClusterCard">
              <div className="kpiLabel summaryClusterTitle">{t('admin.overview.cumulative.ad', '광고')}</div>
              <div className="cumulativeClusterInner cols3">
                <div className="summaryMiniCard">
                  <div className="kpiLabel summaryMiniLabel">{t('admin.overview.cumulative.adImpressions', '노출 수')}</div>
                  <div className="kpiValue summaryMiniValue">{formatNumber(periodData.adImpressions)}</div>
                </div>
                <div className="summaryMiniCard">
                  <div className="kpiLabel summaryMiniLabel">{t('admin.overview.cumulative.adClicks', '클릭 수')}</div>
                  <div className="kpiValue summaryMiniValue">{formatNumber(periodData.adClicks)}</div>
                </div>
                <div className="summaryMiniCard">
                  <div className="kpiLabel summaryMiniLabel">{t('admin.overview.cumulative.adCtr', '클릭률')}</div>
                  <div className="kpiValue summaryMiniValue">{formatPercent(periodData.adCtr)}</div>
                </div>
              </div>

              <div className="cumulativeAdRows">
                <div className="cumulativeAdRow cumulativeAdRowHead" aria-hidden="true">
                  <div className="cumulativeAdName">{t('admin.overview.cumulative.slot', '광고 위치')}</div>
                  <div className="cumulativeAdValue">{t('admin.overview.cumulative.impressions', '노출')}</div>
                  <div className="cumulativeAdValue">{t('admin.overview.cumulative.clicks', '클릭')}</div>
                  <div className="cumulativeAdValue">{t('admin.overview.cumulative.ctr', '클릭률')}</div>
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
