'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { fetchJsonSafe, isUnauthorizedError, postJson } from '../../lib/api'
import { formatDate, formatNumber, formatPercent } from '../../lib/format'
import { mockPeriodSummary, mockSummary } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type PeriodKey = 'week' | 'month' | 'quarter' | 'year'
type ComparisonPeriodKey = 'day' | 'week' | 'month'
type SummaryComparisonMap = Partial<Record<'dau' | 'wau' | 'mau', Partial<Record<ComparisonPeriodKey, number>>>>

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
  const data = res.data.data

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

  async function onRefreshSnapshot() {
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

  const summaryComparisons =
    typeof (data as { comparisons?: unknown }).comparisons === 'object' && (data as { comparisons?: unknown }).comparisons
      ? ((data as { comparisons?: SummaryComparisonMap }).comparisons ?? {})
      : undefined

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
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.overview.title', 'Overview')}
        description={t('admin.overview.desc', '핵심 지표 요약')}
        onRefresh={() => void onRefreshSnapshot()}
        refreshing={refreshingSnapshot}
        actionLabel={t('admin.common.refresh', '데이터 불러오기')}
        inlineRefresh
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {refreshMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{refreshMessage}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.overview.warning.fallbackTitle', 'Live summary unavailable.')}</strong>{' '}
          {t('admin.overview.warning.fallbackBody', '지금 보이는 값은 fallback/mock data일 수 있어서 운영 판단 기준으로 쓰면 안 돼요.')}
          {res.fallbackMessage ? ` (${res.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="metaRow" style={{ marginBottom: 16 }}>
        <div className="metaPill">{t('admin.overview.meta.snapshotDate', '기준일')} {data.snapshotDate ?? '-'}</div>
        <div className="metaPill">{t('admin.overview.meta.generatedAt', '생성시각')} {formatDate(data.snapshotGeneratedAt)}</div>
        <div className="metaPill">{t('admin.overview.meta.source', '소스')} {data.snapshotSource ?? '-'}</div>
        <div className="metaPill">{t('admin.overview.meta.mode', '모드')} {data.dataMode ?? '-'}</div>
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
