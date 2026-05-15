'use client'

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'

import { CampaignRow, fallbackSlots, SlotConfig, SlotEditorPanel, SlotHistory, SlotPreview, SlotRow } from '../../components/ads'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import PageHeader from '../../components/PageHeader'
import { fetchJsonSafe, isUnauthorizedError, postFormData, putJson } from '../../lib/api'
import { formatDate, formatNumber, formatPercent } from '../../lib/format'

type UploadResponse = {
  ok: boolean
  data?: {
    fileName: string
    url: string
    contentType: string
    size: number
  }
  error?: {
    code: string
    message: string
  }
}

type ReviewFlag = 'ok' | 'low_ctr' | 'no_data' | 'inactive_gap' | 'reserved_mismatch'

type SlotPeriod = {
  startAt: string | null
  endAt: string | null
}

type SlotPerformanceRow = {
  slotKey: string
  surfaceLabel: string
  placementLabel: string
  slotStatus: string
  effectiveRuntimeState: string
  liveCreativeTitle: string
  livePeriod: SlotPeriod
  reservedCreativeTitle: string
  reservedPeriod: SlotPeriod
  updatedAt: string | null
  impressions: number
  clicks: number
  ctr: number
  downstreamActions: number | null
  reviewFlag: ReviewFlag
  lastImpressionAt: string | null
}

type CreativePerformanceRow = {
  creativeKey: string
  title: string
  slotCount: number
  slotKey: string | null
  variant: 'live' | 'reserved'
  status: string
  impressions: number
  clicks: number
  ctr: number
  downstreamActions: number | null
  firstSeenAt: string | null
  lastSeenAt: string | null
}

type AdsPerformanceData = {
  summary: {
    liveSlots: number
    reservedPending: number
    activeCreatives: number
    lowCtrSlots: number
    noDataSlots: number
  }
  slotRows: SlotPerformanceRow[]
  creativeRows: CreativePerformanceRow[]
  reviewQueues: {
    noData: SlotPerformanceRow[]
    lowCtr: SlotPerformanceRow[]
    inactiveGap: SlotPerformanceRow[]
    reservedMismatch: SlotPerformanceRow[]
    clickNoDownstream: SlotPerformanceRow[]
  }
}

type AdsWorkspaceData = {
  slot: SlotRow
  liveCampaign: CampaignRow | null
  reservedCampaign: CampaignRow | null
  history: CampaignRow[]
  performance: SlotPerformanceRow | null
}

function buildFallbackSummary(slots: SlotRow[]): AdsPerformanceData {
  const slotRows: SlotPerformanceRow[] = slots.map((slot) => {
    const hasLive = Boolean(slot.config.title?.trim())
    const hasReserved = Boolean(slot.config.reservedTitle?.trim())
    const runtimeState = slot.status !== 'active'
      ? 'inactive'
      : hasLive
        ? 'live_now'
        : hasReserved
          ? 'reserved_pending'
          : 'inactive_gap'
    const reviewFlag: ReviewFlag = slot.status !== 'active'
      ? 'ok'
      : hasLive || hasReserved
        ? 'no_data'
        : 'inactive_gap'
    return {
      slotKey: slot.slotKey,
      surfaceLabel: [slot.config.screen, slot.config.position].filter(Boolean).join(' · ') || slot.slotKey,
      placementLabel: slot.config.placementNote || slot.placementType,
      slotStatus: slot.status,
      effectiveRuntimeState: runtimeState,
      liveCreativeTitle: slot.config.title?.trim() || '-',
      livePeriod: {
        startAt: slot.config.exposureStartAt ?? null,
        endAt: slot.config.exposureEndAt ?? null,
      },
      reservedCreativeTitle: slot.config.reservedTitle?.trim() || '-',
      reservedPeriod: {
        startAt: slot.config.reservationStartAt ?? null,
        endAt: slot.config.reservationEndAt ?? null,
      },
      updatedAt: slot.updatedAt ?? slot.createdAt,
      impressions: 0,
      clicks: 0,
      ctr: 0,
      downstreamActions: null,
      reviewFlag,
      lastImpressionAt: null,
    }
  })
  return {
    summary: {
      liveSlots: slotRows.filter((row) => row.effectiveRuntimeState === 'live_now').length,
      reservedPending: slotRows.filter((row) => row.effectiveRuntimeState === 'reserved_pending').length,
      activeCreatives: slotRows.filter((row) => row.liveCreativeTitle !== '-').length,
      lowCtrSlots: 0,
      noDataSlots: slotRows.filter((row) => row.reviewFlag === 'no_data').length,
    },
    slotRows,
    creativeRows: [],
    reviewQueues: {
      noData: slotRows.filter((row) => row.reviewFlag === 'no_data'),
      lowCtr: [],
      inactiveGap: slotRows.filter((row) => row.reviewFlag === 'inactive_gap'),
      reservedMismatch: [],
      clickNoDownstream: [],
    },
  }
}

function buildFallbackWorkspace(slot: SlotRow): AdsWorkspaceData {
  return {
    slot,
    liveCampaign: null,
    reservedCampaign: null,
    history: [],
    performance: buildFallbackSummary([slot]).slotRows[0] ?? null,
  }
}

function formatPeriod(period: SlotPeriod | null | undefined) {
  if (!period) return '-'
  return `${formatDate(period.startAt)} → ${formatDate(period.endAt)}`
}

function reviewFlagLabel(flag: ReviewFlag) {
  switch (flag) {
    case 'low_ctr':
      return 'low CTR'
    case 'no_data':
      return 'no data'
    case 'inactive_gap':
      return 'inactive gap'
    case 'reserved_mismatch':
      return 'reserved mismatch'
    default:
      return 'ok'
  }
}

function runtimeStateLabel(value: string) {
  switch (value) {
    case 'live_now':
      return 'live now'
    case 'reserved_pending':
      return 'reserved pending'
    case 'inactive_gap':
      return 'inactive gap'
    case 'reserved_mismatch':
      return 'reserved mismatch'
    case 'inactive':
      return 'inactive'
    case 'expired':
      return 'expired'
    default:
      return value || '-'
  }
}

export default function AdsPage() {
  const router = useRouter()
  const { t } = useAdminCopy()
  const [slots, setSlots] = useState<SlotRow[]>(fallbackSlots)
  const [performance, setPerformance] = useState<AdsPerformanceData>(buildFallbackSummary(fallbackSlots))
  const [workspace, setWorkspace] = useState<AdsWorkspaceData | null>(null)
  const [usingFallback, setUsingFallback] = useState(true)
  const [loading, setLoading] = useState(true)
  const [workspaceLoading, setWorkspaceLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [savingKey, setSavingKey] = useState<string | null>(null)
  const [uploadingKey, setUploadingKey] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [historyVariantFilter, setHistoryVariantFilter] = useState<'all' | 'live' | 'reserved'>('all')
  const [historyStatusFilter, setHistoryStatusFilter] = useState<'all' | 'ended' | 'cancelled' | 'scheduled' | 'live'>('all')
  const [historyQuery, setHistoryQuery] = useState('')
  const [historyPeriodFrom, setHistoryPeriodFrom] = useState('')
  const [historyPeriodTo, setHistoryPeriodTo] = useState('')
  const [slotQuery, setSlotQuery] = useState('')
  const [slotStatusFilter, setSlotStatusFilter] = useState<'all' | 'active' | 'inactive'>('all')
  const [selectedSlotKey, setSelectedSlotKey] = useState<string | null>(null)

  const slotsByKey = useMemo(() => Object.fromEntries(slots.map((slot) => [slot.slotKey, slot])), [slots])
  const selectedSlot = useMemo(() => {
    if (!selectedSlotKey) return null
    return slotsByKey[selectedSlotKey] ?? null
  }, [selectedSlotKey, slotsByKey])
  const selectedPerformance = workspace?.performance ?? null
  const selectedSlotHistory = useMemo(() => {
    if (!selectedSlot) return []
    return (workspace?.history ?? []).filter((campaign) => campaign.id !== selectedSlot.config.liveCampaignId && campaign.id !== selectedSlot.config.reservedCampaignId)
  }, [selectedSlot, workspace])

  async function loadSlots() {
    const res = await fetchJsonSafe<{ ok: boolean; data: { slots: SlotRow[] } }>('/admin/ads/slots', { ok: true, data: { slots: fallbackSlots } })
    setSlots(res.data.data.slots)
    setUsingFallback(res.usingFallback)
    return res.data.data.slots
  }

  async function loadPerformanceSummary() {
    const params = new URLSearchParams()
    if (slotQuery.trim()) params.set('surface', slotQuery.trim())
    if (slotStatusFilter !== 'all') params.set('status', slotStatusFilter)
    if (historyVariantFilter !== 'all') params.set('variant', historyVariantFilter)
    if (historyPeriodFrom) params.set('periodFrom', historyPeriodFrom)
    if (historyPeriodTo) params.set('periodTo', historyPeriodTo)
    const res = await fetchJsonSafe<{ ok: boolean; data: AdsPerformanceData }>(
      `/admin/ads/performance/summary${params.toString() ? `?${params.toString()}` : ''}`,
      { ok: true, data: buildFallbackSummary(fallbackSlots) },
    )
    setPerformance(res.data.data)
    return res.data.data
  }

  async function loadWorkspace(slotKey: string) {
    setWorkspaceLoading(true)
    try {
      const params = new URLSearchParams()
      if (historyPeriodFrom) params.set('periodFrom', historyPeriodFrom)
      if (historyPeriodTo) params.set('periodTo', historyPeriodTo)
      const fallbackSlot = slotsByKey[slotKey] ?? fallbackSlots.find((slot) => slot.slotKey === slotKey) ?? fallbackSlots[0]
      const res = await fetchJsonSafe<{ ok: boolean; data: AdsWorkspaceData }>(
        `/admin/ads/slots/${slotKey}/workspace${params.toString() ? `?${params.toString()}` : ''}`,
        { ok: true, data: buildFallbackWorkspace(fallbackSlot) },
      )
      setWorkspace(res.data.data)
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : '선택한 슬롯 작업공간을 불러오지 못했어')
    } finally {
      setWorkspaceLoading(false)
    }
  }

  async function refreshAll() {
    setLoading(true)
    setError(null)
    try {
      const [, summary] = await Promise.all([loadSlots(), loadPerformanceSummary()])
      const firstSlotKey = summary.slotRows[0]?.slotKey ?? null
      setSelectedSlotKey((prev) => prev && summary.slotRows.some((row) => row.slotKey === prev) ? prev : firstSlotKey)
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : '광고 데이터를 불러오지 못했어')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void refreshAll()
  }, [])

  useEffect(() => {
    if (loading) return
    void loadPerformanceSummary().catch((err) => {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : '광고 성과 요약을 불러오지 못했어')
    })
  }, [slotQuery, slotStatusFilter, historyVariantFilter, historyPeriodFrom, historyPeriodTo])

  useEffect(() => {
    const availableKeys = performance.slotRows.map((row) => row.slotKey)
    if (availableKeys.length === 0) {
      if (selectedSlotKey !== null) setSelectedSlotKey(null)
      return
    }
    if (!selectedSlotKey || !availableKeys.includes(selectedSlotKey)) {
      setSelectedSlotKey(availableKeys[0])
    }
  }, [performance.slotRows, selectedSlotKey])

  useEffect(() => {
    if (!selectedSlotKey) {
      setWorkspace(null)
      return
    }
    void loadWorkspace(selectedSlotKey)
  }, [selectedSlotKey, historyPeriodFrom, historyPeriodTo, slotsByKey])

  function updateSlot(slotKey: string, patch: Partial<SlotRow>) {
    setSlots((prev) => prev.map((slot) => (slot.slotKey === slotKey ? { ...slot, ...patch } : slot)))
  }

  function updateConfig(slotKey: string, patch: Partial<SlotConfig>) {
    setSlots((prev) => prev.map((slot) => (slot.slotKey === slotKey ? { ...slot, config: { ...slot.config, ...patch } } : slot)))
  }

  async function saveSlot(slot: SlotRow, variant: 'live' | 'reserved') {
    const saveId = `${slot.slotKey}:${variant}`
    setSavingKey(saveId)
    setMessage(null)
    try {
      const payload = variant === 'live'
        ? {
            status: slot.status,
            slotLabel: slot.config.slotLabel,
            slotDescription: slot.config.slotDescription,
            placementNote: slot.config.placementNote,
            title: slot.config.title,
            message: slot.config.message,
            ctaLabel: slot.config.ctaLabel,
            targetUrl: slot.config.targetUrl,
            imageUrl: slot.config.imageUrl,
            exposureStartAt: slot.config.exposureStartAt,
            exposureEndAt: slot.config.exposureEndAt,
          }
        : {
            reservedTitle: slot.config.reservedTitle,
            reservedMessage: slot.config.reservedMessage,
            reservedCtaLabel: slot.config.reservedCtaLabel,
            reservedTargetUrl: slot.config.reservedTargetUrl,
            reservedImageUrl: slot.config.reservedImageUrl,
            reservationStartAt: slot.config.reservationStartAt,
            reservationEndAt: slot.config.reservationEndAt,
          }
      const res = await putJson<{ ok: boolean; data: SlotRow }>(`/admin/ads/slots/${slot.slotKey}`, payload)
      updateSlot(slot.slotKey, res.data)
      await Promise.all([loadPerformanceSummary(), loadWorkspace(slot.slotKey)])
      setMessage(`${slot.slotKey} ${variant === 'live' ? 'live' : 'reserved'} 저장 완료`)
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : t('admin.ads.saveFailed', '광고 슬롯 저장 실패'))
    } finally {
      setSavingKey(null)
    }
  }

  async function uploadAsset(slotKey: string, file: File, field: 'imageUrl' | 'reservedImageUrl') {
    const uploadId = `${slotKey}:${field}`
    setUploadingKey(uploadId)
    setMessage(null)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const res = await postFormData<UploadResponse>('/admin/ads/assets', formData)
      if (!res.ok || !res.data) {
        setError(res.error?.message ?? '배너 업로드 실패')
      } else {
        updateConfig(slotKey, { [field]: res.data.url } as Partial<SlotConfig>)
        setMessage(`${slotKey} 배너 업로드 완료`)
      }
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : '배너 업로드 실패')
    } finally {
      setUploadingKey(null)
    }
  }

  const bulkExportParams = new URLSearchParams()
  if (historyQuery.trim()) bulkExportParams.set('query', historyQuery.trim())
  if (historyVariantFilter !== 'all') bulkExportParams.set('variant', historyVariantFilter)
  if (historyStatusFilter !== 'all') bulkExportParams.set('status', historyStatusFilter)
  if (historyPeriodFrom) bulkExportParams.set('periodFrom', historyPeriodFrom)
  if (historyPeriodTo) bulkExportParams.set('periodTo', historyPeriodTo)
  const bulkExportHref = `/api/cartly-admin/admin/ads/campaigns/export.xlsx${bulkExportParams.toString() ? `?${bulkExportParams.toString()}` : ''}`

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={usingFallback ? 'Fallback data' : loading ? 'Loading...' : 'Live data'}
        title={t('admin.ads.title', 'Ads')}
        description={t('admin.ads.desc', '무엇이 어디에 live인지, 어떻게 반응하는지, 무엇을 stop/keep할지 바로 판단하는 광고 운영 콘솔')}
        onRefresh={() => void refreshAll()}
        refreshing={loading || workspaceLoading}
      />

      {error ? <div className="loginError" style={{ marginBottom: 16 }}>{error}</div> : null}
      {message ? <div className="saveMessage" style={{ marginBottom: 16 }}>{message}</div> : null}
      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>Live ads data unavailable.</strong> 지금 화면은 fallback/mock data일 수 있어서 저장과 배너 업로드는 잠깐 막아둘게.
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Live slots</div>
          <div className="exploreSummaryValue">{performance.summary.liveSlots}</div>
          <div className="exploreSummaryNote">runtime state = live_now</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Reserved pending</div>
          <div className="exploreSummaryValue">{performance.summary.reservedPending}</div>
          <div className="exploreSummaryNote">next queued creatives</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Active creatives</div>
          <div className="exploreSummaryValue">{performance.summary.activeCreatives}</div>
          <div className="exploreSummaryNote">live creative attached</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Low CTR</div>
          <div className="exploreSummaryValue">{performance.summary.lowCtrSlots}</div>
          <div className="exploreSummaryNote">review queue</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">No data</div>
          <div className="exploreSummaryValue">{performance.summary.noDataSlots}</div>
          <div className="exploreSummaryNote">period signal empty</div>
        </div>
      </div>

      <div className="metaRow section" style={{ marginTop: 8 }}>
        <div className="metaPill">surface {slotQuery.trim() || '-'}</div>
        <div className="metaPill">slot status {slotStatusFilter}</div>
        <div className="metaPill">variant {historyVariantFilter}</div>
        <div className="metaPill">period {historyPeriodFrom || '-'} → {historyPeriodTo || '-'}</div>
        <div className="metaPill">campaign status {historyStatusFilter}</div>
      </div>

      <form className="card exploreDenseCard exploreSheetCard" style={{ marginTop: 16, marginBottom: 16 }} onSubmit={(e) => e.preventDefault()}>
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>공통 필터</h2>
            <p className="pageDesc" style={{ margin: 0 }}>좌측 sidebar의 `현황 / 세팅 / 효율` 흐름과 같은 범위로 바로 이어서 보게 맞춘 필터 바야.</p>
          </div>
        </div>
        <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(220px, 2fr) repeat(5, minmax(140px, 1fr))' }}>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">surface / slot 검색</div>
            <input className="textInput exploreSheetInput" value={slotQuery} onChange={(e) => setSlotQuery(e.target.value)} placeholder="slot / screen / position / placement" />
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">slot status</div>
            <select className="textInput exploreSheetInput" value={slotStatusFilter} onChange={(e) => setSlotStatusFilter(e.target.value as 'all' | 'active' | 'inactive')}>
              <option value="all">all</option>
              <option value="active">active</option>
              <option value="inactive">inactive</option>
            </select>
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">variant</div>
            <select className="textInput exploreSheetInput" value={historyVariantFilter} onChange={(e) => setHistoryVariantFilter(e.target.value as 'all' | 'live' | 'reserved')}>
              <option value="all">all</option>
              <option value="live">live</option>
              <option value="reserved">reserved</option>
            </select>
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">campaign status</div>
            <select className="textInput exploreSheetInput" value={historyStatusFilter} onChange={(e) => setHistoryStatusFilter(e.target.value as 'all' | 'ended' | 'cancelled' | 'scheduled' | 'live')}>
              <option value="all">all</option>
              <option value="ended">ended</option>
              <option value="cancelled">cancelled</option>
              <option value="scheduled">scheduled</option>
              <option value="live">live</option>
            </select>
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">period from</div>
            <input className="textInput exploreSheetInput" type="date" value={historyPeriodFrom} onChange={(e) => setHistoryPeriodFrom(e.target.value)} />
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">period to</div>
            <input className="textInput exploreSheetInput" type="date" value={historyPeriodTo} onChange={(e) => setHistoryPeriodTo(e.target.value)} />
          </label>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <label className="field" style={{ margin: 0, minWidth: 240 }}>
            <div className="exploreSheetFieldLabel">history query</div>
            <input className="textInput exploreSheetInput" value={historyQuery} onChange={(e) => setHistoryQuery(e.target.value)} placeholder="광고 제목, 문구, CTA" />
          </label>
          <a className="ghostBtn pageActionBtn" href={bulkExportHref}>기간내 지난광고 Excel 일괄 다운로드</a>
        </div>
      </form>

      <div className="card exploreDenseCard exploreSheetCard" id="ads-runtime-health" style={{ marginTop: 12, marginBottom: 16 }}>
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>현황</h2>
            <p className="pageDesc" style={{ margin: 0 }}>지금 무엇이 어느 surface에 live인지, review가 필요한 slot이 무엇인지 먼저 보는 truth table이야.</p>
          </div>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <div className="metaPill">rows {performance.slotRows.length}</div>
            <div className="metaPill">low ctr {performance.reviewQueues.lowCtr.length}</div>
            <div className="metaPill">no data {performance.reviewQueues.noData.length}</div>
          </div>
        </div>
        {performance.slotRows.length === 0 ? (
          <div className="emptyState">조건에 맞는 slot이 없어.</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable">
              <thead>
                <tr>
                  <th>Slot</th>
                  <th>Surface / Placement</th>
                  <th>Runtime</th>
                  <th>Live creative</th>
                  <th>Reserved creative</th>
                  <th>Metrics</th>
                  <th>Review</th>
                  <th>Updated</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {performance.slotRows.map((row) => {
                  const slot = slotsByKey[row.slotKey]
                  const isSelected = selectedSlotKey === row.slotKey
                  return (
                    <tr key={row.slotKey} onClick={() => setSelectedSlotKey(row.slotKey)} style={{ cursor: 'pointer', background: isSelected ? 'rgba(227, 24, 55, 0.06)' : undefined }}>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 190 }}>
                          <strong>{slot?.config.slotLabel || row.slotKey}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{row.slotKey}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                          <span className="metaPill">{row.surfaceLabel}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{row.placementLabel}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">{row.slotStatus}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{runtimeStateLabel(row.effectiveRuntimeState)}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                          <strong>{row.liveCreativeTitle}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{formatPeriod(row.livePeriod)}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                          <strong>{row.reservedCreativeTitle}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{formatPeriod(row.reservedPeriod)}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span>{formatNumber(row.impressions)} imp</span>
                          <span>{formatNumber(row.clicks)} click · {formatPercent(row.ctr)}</span>
                        </div>
                      </td>
                      <td>
                        <span className="metaPill">{reviewFlagLabel(row.reviewFlag)}</span>
                      </td>
                      <td>{formatDate(row.updatedAt)}</td>
                      <td>
                        <button className="ghostBtn ghostBtnSmall" type="button" onClick={(event) => { event.stopPropagation(); setSelectedSlotKey(row.slotKey) }}>
                          {isSelected ? 'selected' : 'open'}
                        </button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
        <div className="section" style={{ marginTop: 16 }}>
          <h3 className="panelTitle" style={{ marginBottom: 10 }}>주의 필요</h3>
          <div className="exploreSummaryGrid" style={{ marginTop: 0 }}>
            <div className="exploreSummaryCell">
              <div className="exploreSummaryLabel">No data</div>
              <div className="exploreSummaryValue">{performance.reviewQueues.noData.length}</div>
              <div className="exploreSummaryNote">live but signal empty</div>
            </div>
            <div className="exploreSummaryCell">
              <div className="exploreSummaryLabel">Low CTR</div>
              <div className="exploreSummaryValue">{performance.reviewQueues.lowCtr.length}</div>
              <div className="exploreSummaryNote">below threshold</div>
            </div>
            <div className="exploreSummaryCell">
              <div className="exploreSummaryLabel">Inactive gap</div>
              <div className="exploreSummaryValue">{performance.reviewQueues.inactiveGap.length}</div>
              <div className="exploreSummaryNote">active slot without live creative</div>
            </div>
            <div className="exploreSummaryCell">
              <div className="exploreSummaryLabel">Reserved mismatch</div>
              <div className="exploreSummaryValue">{performance.reviewQueues.reservedMismatch.length}</div>
              <div className="exploreSummaryNote">reserved creative without valid schedule</div>
            </div>
          </div>
          <div className="tableWrap" style={{ marginTop: 12 }}>
            <table className="dataTable">
              <thead>
                <tr>
                  <th>Slot</th>
                  <th>Surface</th>
                  <th>Issue</th>
                  <th>Live</th>
                  <th>Reserved</th>
                </tr>
              </thead>
              <tbody>
                {[
                  ...performance.reviewQueues.noData,
                  ...performance.reviewQueues.lowCtr,
                  ...performance.reviewQueues.inactiveGap,
                  ...performance.reviewQueues.reservedMismatch,
                ].map((row) => (
                  <tr key={`review-${row.slotKey}-${row.reviewFlag}`}>
                    <td>{row.slotKey}</td>
                    <td>{row.surfaceLabel}</td>
                    <td>{reviewFlagLabel(row.reviewFlag)}</td>
                    <td>{row.liveCreativeTitle}</td>
                    <td>{row.reservedCreativeTitle}</td>
                  </tr>
                ))}
                {performance.reviewQueues.noData.length + performance.reviewQueues.lowCtr.length + performance.reviewQueues.inactiveGap.length + performance.reviewQueues.reservedMismatch.length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ textAlign: 'center', color: '#64748b' }}>review queue 비어 있음</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {selectedSlot ? (
        <div className="card exploreDenseCard exploreSheetCard" id="ads-quick-setup">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>세팅 · {selectedSlot.config.slotLabel || selectedSlot.slotKey}</h2>
              <p className="pageDesc" style={{ marginBottom: 8 }}>{selectedSlot.config.slotDescription || '슬롯 설명 없음'}</p>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <div className="metaPill">{selectedSlot.slotKey}</div>
                <div className="metaPill">{selectedSlot.placementType}</div>
                <div className="metaPill">{selectedSlot.config.screen}</div>
                <div className="metaPill">{selectedSlot.config.position}</div>
                <div className="metaPill">{selectedSlot.config.placementNote || '-'}</div>
              </div>
            </div>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">{selectedPerformance ? runtimeStateLabel(selectedPerformance.effectiveRuntimeState) : 'loading'}</div>
              <div className="metaPill">imp {formatNumber(selectedPerformance?.impressions ?? 0)}</div>
              <div className="metaPill">click {formatNumber(selectedPerformance?.clicks ?? 0)}</div>
              <div className="metaPill">ctr {formatPercent(selectedPerformance?.ctr ?? 0)}</div>
              <div className="metaPill">{selectedPerformance ? reviewFlagLabel(selectedPerformance.reviewFlag) : '-'}</div>
            </div>
          </div>

          <div className="slotEditorLayout adsSelectedSlotLayout">
            <SlotEditorPanel
              title={t('admin.ads.livePanel.title', '현재 노출 광고')}
              description={t('admin.ads.livePanel.desc', '현재 앱에 노출 중인 광고 설정')}
              slot={selectedSlot}
              variant="live"
              uploading={uploadingKey === `${selectedSlot.slotKey}:imageUrl`}
              saving={savingKey === `${selectedSlot.slotKey}:live`}
              readOnly={usingFallback}
              onSlotChange={(patch) => updateSlot(selectedSlot.slotKey, patch)}
              onConfigChange={(patch) => updateConfig(selectedSlot.slotKey, patch)}
              onUpload={(file) => void uploadAsset(selectedSlot.slotKey, file, 'imageUrl')}
              onSave={() => void saveSlot(selectedSlot, 'live')}
            />
            <SlotEditorPanel
              title={t('admin.ads.reservedPanel.title', '예약 광고 세팅')}
              description={t('admin.ads.reservedPanel.desc', '다음 노출 순서를 미리 준비하는 예약 광고 설정')}
              slot={selectedSlot}
              variant="reserved"
              uploading={uploadingKey === `${selectedSlot.slotKey}:reservedImageUrl`}
              saving={savingKey === `${selectedSlot.slotKey}:reserved`}
              readOnly={usingFallback}
              onSlotChange={(patch) => updateSlot(selectedSlot.slotKey, patch)}
              onConfigChange={(patch) => updateConfig(selectedSlot.slotKey, patch)}
              onUpload={(file) => void uploadAsset(selectedSlot.slotKey, file, 'reservedImageUrl')}
              onSave={() => void saveSlot(selectedSlot, 'reserved')}
            />
            <div style={{ display: 'grid', gap: 12 }}>
              <SlotPreview slot={selectedSlot} />
              <div className="card exploreDenseCard" style={{ padding: 14 }}>
                <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 8 }}>
                  <div>
                    <h3 className="panelTitle" style={{ marginBottom: 6 }}>선택 슬롯 요약</h3>
                    <p className="pageDesc" style={{ margin: 0 }}>현재 선택한 slot의 filtered-period 성과 요약이야.</p>
                  </div>
                </div>
                <div className="metaRow" style={{ marginTop: 0 }}>
                  <div className="metaPill">live {workspace?.liveCampaign?.title || '-'}</div>
                  <div className="metaPill">reserved {workspace?.reservedCampaign?.title || '-'}</div>
                </div>
                <div style={{ display: 'grid', gap: 8, marginTop: 10 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}><span>Impressions</span><strong>{formatNumber(selectedPerformance?.impressions ?? 0)}</strong></div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}><span>Clicks</span><strong>{formatNumber(selectedPerformance?.clicks ?? 0)}</strong></div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}><span>CTR</span><strong>{formatPercent(selectedPerformance?.ctr ?? 0)}</strong></div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}><span>Last impression</span><strong>{formatDate(selectedPerformance?.lastImpressionAt ?? null)}</strong></div>
                </div>
              </div>
            </div>
          </div>

        </div>
      ) : (
        <div className="emptyState">선택된 slot이 없어.</div>
      )}

      <div className="card exploreDenseCard exploreSheetCard" id="ads-efficiency-review" style={{ marginTop: 16, marginBottom: 24 }}>
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>효율</h2>
            <p className="pageDesc" style={{ margin: 0 }}>기간 기준 성과와 creative 비교를 한 번에 보는 구간이야.</p>
          </div>
        </div>

        <div className="section" style={{ marginTop: 0 }}>
          <h3 className="panelTitle" style={{ marginBottom: 10 }}>슬롯별 성과</h3>
          <div className="tableWrap">
            <table className="dataTable">
              <thead>
                <tr>
                  <th>Slot</th>
                  <th>Surface</th>
                  <th>Live creative</th>
                  <th>Impressions</th>
                  <th>Clicks</th>
                  <th>CTR</th>
                  <th>Review</th>
                  <th>Last impression</th>
                </tr>
              </thead>
              <tbody>
                {performance.slotRows.map((row) => (
                  <tr key={`perf-${row.slotKey}`}>
                    <td>{row.slotKey}</td>
                    <td>{row.surfaceLabel}</td>
                    <td>{row.liveCreativeTitle}</td>
                    <td>{formatNumber(row.impressions)}</td>
                    <td>{formatNumber(row.clicks)}</td>
                    <td>{formatPercent(row.ctr)}</td>
                    <td>{reviewFlagLabel(row.reviewFlag)}</td>
                    <td>{formatDate(row.lastImpressionAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="section" style={{ marginTop: 16 }}>
          <h3 className="panelTitle" style={{ marginBottom: 10 }}>소재별 성과</h3>
          {performance.creativeRows.length === 0 ? (
            <div className="emptyState">현재 조건에서는 creative-level row가 없어.</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>Creative</th>
                    <th>Slot</th>
                    <th>Variant</th>
                    <th>Status</th>
                    <th>Impressions</th>
                    <th>Clicks</th>
                    <th>CTR</th>
                    <th>Seen</th>
                  </tr>
                </thead>
                <tbody>
                  {performance.creativeRows.map((row) => (
                    <tr key={row.creativeKey}>
                      <td>{row.title}</td>
                      <td>{row.slotKey || '-'}</td>
                      <td>{row.variant}</td>
                      <td>{row.status}</td>
                      <td>{formatNumber(row.impressions)}</td>
                      <td>{formatNumber(row.clicks)}</td>
                      <td>{formatPercent(row.ctr)}</td>
                      <td>{formatDate(row.firstSeenAt)} → {formatDate(row.lastSeenAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="section" style={{ marginTop: 16 }}>
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
            <div>
              <h3 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.ads.history.title', '지난 광고 데이터')}</h3>
              <p className="pageDesc">현재 history table의 imp/click/ctr는 campaign lifetime 기준이야. 기간 기준 판단은 위 표와 creative 비교를 같이 보면 돼.</p>
            </div>
          </div>
          <SlotHistory
            campaigns={selectedSlotHistory}
            variantFilter={historyVariantFilter}
            statusFilter={historyStatusFilter}
            query={historyQuery}
            periodFrom={historyPeriodFrom}
            periodTo={historyPeriodTo}
          />
        </div>
      </div>
    </div>
  )
}
