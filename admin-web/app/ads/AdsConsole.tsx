'use client'

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'

import { CampaignRow, fallbackSlots, SlotHistory, SlotRow } from '../../components/ads'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import PageHeader from '../../components/PageHeader'
import { fetchJsonSafe, isUnauthorizedError, postFormData, postJson, putJson } from '../../lib/api'
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

type CampaignSheetDraft = {
  slotKey: string
  startAt: string
  endAt: string
  title: string
  message: string
  ctaLabel: string
  targetUrl: string
  imageUrl: string
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

function campaignStatusLabel(value: string) {
  switch (value) {
    case 'live':
      return '현재 노출'
    case 'scheduled':
      return '다음 예약'
    case 'ended':
      return '종료됨'
    case 'cancelled':
      return '취소됨'
    default:
      return value || '-'
  }
}

function emptyCampaignDraft(slotKey = ''): CampaignSheetDraft {
  return {
    slotKey,
    startAt: '',
    endAt: '',
    title: '',
    message: '',
    ctaLabel: '',
    targetUrl: '',
    imageUrl: '',
  }
}

function draftFromCampaign(campaign: CampaignRow): CampaignSheetDraft {
  return {
    slotKey: campaign.slotKey,
    startAt: campaign.startAt?.slice(0, 16) ?? '',
    endAt: campaign.endAt?.slice(0, 16) ?? '',
    title: campaign.title ?? '',
    message: campaign.message ?? '',
    ctaLabel: campaign.ctaLabel ?? '',
    targetUrl: campaign.targetUrl ?? '',
    imageUrl: campaign.imageUrl ?? '',
  }
}

export type AdsView = 'status' | 'setup' | 'efficiency'

export default function AdsConsole({ view }: { view: AdsView }) {
  const router = useRouter()
  const { t } = useAdminCopy()
  const [slots, setSlots] = useState<SlotRow[]>(fallbackSlots)
  const [performance, setPerformance] = useState<AdsPerformanceData>(buildFallbackSummary(fallbackSlots))
  const [workspace, setWorkspace] = useState<AdsWorkspaceData | null>(null)
  const [campaigns, setCampaigns] = useState<CampaignRow[]>([])
  const [campaignDrafts, setCampaignDrafts] = useState<Record<string, CampaignSheetDraft>>({})
  const [appendDraft, setAppendDraft] = useState<CampaignSheetDraft>(emptyCampaignDraft(fallbackSlots[0]?.slotKey ?? ''))
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

  async function loadCampaigns() {
    const params = new URLSearchParams()
    params.set('limit', '500')
    if (historyQuery.trim()) params.set('query', historyQuery.trim())
    if (historyVariantFilter !== 'all') params.set('variant', historyVariantFilter)
    if (historyStatusFilter !== 'all') params.set('status', historyStatusFilter)
    if (historyPeriodFrom) params.set('periodFrom', historyPeriodFrom)
    if (historyPeriodTo) params.set('periodTo', historyPeriodTo)
    const res = await fetchJsonSafe<{ ok: boolean; data: { campaigns: CampaignRow[] } }>(
      `/admin/ads/campaigns?${params.toString()}`,
      { ok: true, data: { campaigns: [] } },
    )
    setCampaigns(res.data.data.campaigns)
    setCampaignDrafts(Object.fromEntries(res.data.data.campaigns.map((campaign) => [campaign.id, draftFromCampaign(campaign)])))
    return res.data.data.campaigns
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
      const [, summary] = await Promise.all([loadSlots(), loadPerformanceSummary(), loadCampaigns()])
      const firstSlotKey = summary.slotRows[0]?.slotKey ?? null
      setSelectedSlotKey((prev) => prev && summary.slotRows.some((row) => row.slotKey === prev) ? prev : firstSlotKey)
      setAppendDraft((prev) => ({ ...prev, slotKey: prev.slotKey || firstSlotKey || fallbackSlots[0]?.slotKey || '' }))
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
    void Promise.all([loadPerformanceSummary(), loadCampaigns()]).catch((err) => {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : '광고 데이터를 다시 불러오지 못했어')
    })
  }, [slotQuery, slotStatusFilter, historyVariantFilter, historyStatusFilter, historyPeriodFrom, historyPeriodTo, historyQuery])

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

  function updateCampaignDraft(id: string, patch: Partial<CampaignSheetDraft>) {
    setCampaignDrafts((prev) => ({
      ...prev,
      [id]: {
        ...(prev[id] ?? emptyCampaignDraft()),
        ...patch,
      },
    }))
  }

  function updateAppendDraft(patch: Partial<CampaignSheetDraft>) {
    setAppendDraft((prev) => ({ ...prev, ...patch }))
  }

  function showActionError(next: string) {
    setError(next)
    if (typeof window !== 'undefined') {
      window.alert(next)
    }
  }

  async function uploadAssetFile(file: File, uploadId: string) {
    setUploadingKey(uploadId)
    setMessage(null)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const res = await postFormData<UploadResponse>('/admin/ads/assets', formData)
      if (!res.ok || !res.data) {
        throw new Error(res.error?.message ?? '배너 업로드 실패')
      }
      setMessage('배너 업로드 완료')
      return res.data.url
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return null
      }
      showActionError(err instanceof Error ? err.message : '배너 업로드 실패')
      return null
    } finally {
      setUploadingKey(null)
    }
  }

  async function createCampaign() {
    setSavingKey('append')
    setMessage(null)
    try {
      await postJson<{ ok: boolean; data: CampaignRow }>('/admin/ads/campaigns', {
        slotKey: appendDraft.slotKey,
        startAt: appendDraft.startAt,
        endAt: appendDraft.endAt,
        title: appendDraft.title,
        message: appendDraft.message,
        ctaLabel: appendDraft.ctaLabel || null,
        targetUrl: appendDraft.targetUrl || null,
        imageUrl: appendDraft.imageUrl || null,
      })
      setAppendDraft(emptyCampaignDraft(appendDraft.slotKey))
      await refreshAll()
      setMessage('campaign row 추가 완료')
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      showActionError(err instanceof Error ? err.message : 'campaign row 추가 실패')
    } finally {
      setSavingKey(null)
    }
  }

  async function saveCampaign(campaignId: string) {
    const draft = campaignDrafts[campaignId]
    if (!draft) return
    setSavingKey(campaignId)
    setMessage(null)
    try {
      await putJson<{ ok: boolean; data: CampaignRow }>(`/admin/ads/campaigns/${campaignId}`, {
        slotKey: draft.slotKey,
        startAt: draft.startAt,
        endAt: draft.endAt,
        title: draft.title,
        message: draft.message,
        ctaLabel: draft.ctaLabel || null,
        targetUrl: draft.targetUrl || null,
        imageUrl: draft.imageUrl || null,
      })
      await refreshAll()
      setMessage('campaign row 저장 완료')
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      showActionError(err instanceof Error ? err.message : 'campaign row 저장 실패')
    } finally {
      setSavingKey(null)
    }
  }

  async function cancelCampaign(campaignId: string) {
    setSavingKey(`cancel:${campaignId}`)
    setMessage(null)
    try {
      await postJson<{ ok: boolean; data: CampaignRow }>(`/admin/ads/campaigns/${campaignId}/cancel`)
      await refreshAll()
      setMessage('campaign row 취소 완료')
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      showActionError(err instanceof Error ? err.message : 'campaign row 취소 실패')
    } finally {
      setSavingKey(null)
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
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>공통 필터</h2>
            <p className="pageDesc" style={{ margin: 0 }}>현황, 세팅, 효율을 같은 조건으로 바로 넘겨보는 압축 필터야.</p>
          </div>
        </div>
        <div className="exploreSheetFilterGrid compactFilterGrid adsCompactFilterGrid adsCompactFilterGridInline">
          <label className="field compactInlineField" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">검색</div>
            <input className="textInput exploreSheetInput compactInlineInput" value={slotQuery} onChange={(e) => setSlotQuery(e.target.value)} placeholder="slot / screen / position / placement" />
          </label>
          <label className="field compactInlineField" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">슬롯</div>
            <select className="textInput exploreSheetInput compactInlineSelect" value={slotStatusFilter} onChange={(e) => setSlotStatusFilter(e.target.value as 'all' | 'active' | 'inactive')}>
              <option value="all">전체</option>
              <option value="active">active</option>
              <option value="inactive">inactive</option>
            </select>
          </label>
          <label className="field compactInlineField" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">구분</div>
            <select className="textInput exploreSheetInput compactInlineSelect" value={historyVariantFilter} onChange={(e) => setHistoryVariantFilter(e.target.value as 'all' | 'live' | 'reserved')}>
              <option value="all">전체</option>
              <option value="live">live</option>
              <option value="reserved">reserved</option>
            </select>
          </label>
          <label className="field compactInlineField" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">상태</div>
            <select className="textInput exploreSheetInput compactInlineSelect" value={historyStatusFilter} onChange={(e) => setHistoryStatusFilter(e.target.value as 'all' | 'ended' | 'cancelled' | 'scheduled' | 'live')}>
              <option value="all">전체</option>
              <option value="ended">ended</option>
              <option value="cancelled">cancelled</option>
              <option value="scheduled">scheduled</option>
              <option value="live">live</option>
            </select>
          </label>
          <label className="field compactInlineField adsCompactDateField" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">기간</div>
            <div className="adsCompactDateRange">
              <input className="textInput exploreSheetInput compactInlineInput" type="date" value={historyPeriodFrom} onChange={(e) => setHistoryPeriodFrom(e.target.value)} />
              <span className="adsCompactDateDivider">~</span>
              <input className="textInput exploreSheetInput compactInlineInput" type="date" value={historyPeriodTo} onChange={(e) => setHistoryPeriodTo(e.target.value)} />
            </div>
          </label>
          <label className="field compactInlineField" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">지난 광고</div>
            <input className="textInput exploreSheetInput compactInlineInput" value={historyQuery} onChange={(e) => setHistoryQuery(e.target.value)} placeholder="광고 제목, 문구, CTA" />
          </label>
          <div className="compactFilterActionCell">
            <a className="ghostBtn ghostBtnSmall" href={bulkExportHref}>Excel</a>
          </div>
        </div>
      </form>

      {view === 'status' ? (
        <div className="card exploreDenseCard exploreSheetCard" style={{ marginTop: 12, marginBottom: 16 }}>
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
      ) : null}

      {view === 'setup' ? (
        <div className="card exploreDenseCard exploreSheetCard" id="ads-quick-setup" style={{ marginTop: 12, marginBottom: 16 }}>
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>세팅 시트</h2>
              <p className="pageDesc" style={{ marginBottom: 6 }}>맨 윗줄에서 row를 추가하고, 아래 row는 바로 수정해. 현재 / 다음 / 종료는 시간창에서 자동으로 판정해.</p>
            </div>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">append row 1</div>
              <div className="metaPill">campaign rows {campaigns.length}</div>
            </div>
          </div>

          <div className="exploreSheetViewport adsSetupSheetViewport">
            <table className="exploreSimpleSheet adsSetupSheet adsSetupUnifiedSheet" style={{ width: 2640, minWidth: 2640 }}>
              <thead>
                <tr>
                  <th>구분</th>
                  <th>슬롯</th>
                  <th>상태</th>
                  <th>시작</th>
                  <th>종료</th>
                  <th>제목</th>
                  <th>문구</th>
                  <th>CTA</th>
                  <th>링크</th>
                  <th>배너</th>
                  <th>업로드</th>
                  <th>저장</th>
                  <th>취소</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><strong>append</strong></td>
                  <td>
                    <select className="textInput exploreSheetInput" style={{ minWidth: 200, width: 200 }} value={appendDraft.slotKey} disabled={usingFallback} onChange={(e) => updateAppendDraft({ slotKey: e.target.value })}>
                      {slots.map((slot) => (
                        <option key={`append-slot-${slot.slotKey}`} value={slot.slotKey}>{slot.config.slotLabel || slot.slotKey}</option>
                      ))}
                    </select>
                  </td>
                  <td><span className="adsSetupCellSub">추가 예정</span></td>
                  <td><input type="datetime-local" className="textInput exploreSheetInput" style={{ minWidth: 176, width: 176 }} value={appendDraft.startAt} disabled={usingFallback} onChange={(e) => updateAppendDraft({ startAt: e.target.value })} /></td>
                  <td><input type="datetime-local" className="textInput exploreSheetInput" style={{ minWidth: 176, width: 176 }} value={appendDraft.endAt} disabled={usingFallback} onChange={(e) => updateAppendDraft({ endAt: e.target.value })} /></td>
                  <td><input className="textInput exploreSheetInput exploreSpreadsheetInput" value={appendDraft.title} disabled={usingFallback} onChange={(e) => updateAppendDraft({ title: e.target.value })} /></td>
                  <td><input className="textInput exploreSheetInput exploreSpreadsheetInput" value={appendDraft.message} disabled={usingFallback} onChange={(e) => updateAppendDraft({ message: e.target.value })} /></td>
                  <td><input className="textInput exploreSheetInput" style={{ minWidth: 110, width: 110 }} value={appendDraft.ctaLabel} disabled={usingFallback} onChange={(e) => updateAppendDraft({ ctaLabel: e.target.value })} /></td>
                  <td><input className="textInput exploreSheetInput exploreSpreadsheetInput" value={appendDraft.targetUrl} disabled={usingFallback} placeholder="https://..." onChange={(e) => updateAppendDraft({ targetUrl: e.target.value })} /></td>
                  <td>
                    {appendDraft.imageUrl ? (
                      <a href={appendDraft.imageUrl} target="_blank" rel="noreferrer" className="exploreMiniThumbLink">
                        <img src={appendDraft.imageUrl} alt="append row" className="exploreMiniThumb adsSetupMiniThumb" />
                      </a>
                    ) : (
                      <span className="adsSetupCellSub">없음</span>
                    )}
                  </td>
                  <td>
                    <label className={`ghostBtn ghostBtnSmall adsUploadBtn${usingFallback ? ' disabled' : ''}`}>
                      {uploadingKey === 'append' ? '업로드중' : '파일'}
                      <input
                        type="file"
                        accept=".png,.jpg,.jpeg,.webp,.svg,image/png,image/jpeg,image/webp,image/svg+xml"
                        className="hiddenInput"
                        disabled={usingFallback}
                        onChange={(e) => {
                          const file = e.target.files?.[0]
                          if (!file) return
                          void uploadAssetFile(file, 'append').then((url) => {
                            if (url) updateAppendDraft({ imageUrl: url })
                          })
                        }}
                      />
                    </label>
                  </td>
                  <td>
                    <button className="primaryBtn ghostBtnSmall adsSetupSaveBtn" type="button" disabled={savingKey === 'append' || usingFallback} onClick={() => void createCampaign()}>
                      {savingKey === 'append' ? '추가중' : '추가'}
                    </button>
                  </td>
                  <td><span className="adsSetupCellSub">-</span></td>
                </tr>
                {campaigns.map((campaign) => {
                  const draft = campaignDrafts[campaign.id] ?? draftFromCampaign(campaign)
                  const slot = slotsByKey[draft.slotKey] ?? slotsByKey[campaign.slotKey] ?? fallbackSlots[0]
                  return (
                    <tr key={`campaign-row-${campaign.id}`}>
                      <td><strong>{campaign.id.slice(0, 8)}</strong></td>
                      <td>
                        <div className="adsSetupCellStack">
                          <select className="textInput exploreSheetInput" style={{ minWidth: 220, width: 220 }} value={draft.slotKey} disabled={usingFallback || campaign.status === 'cancelled'} onChange={(e) => updateCampaignDraft(campaign.id, { slotKey: e.target.value })}>
                            {slots.map((item) => (
                              <option key={`campaign-slot-${campaign.id}-${item.slotKey}`} value={item.slotKey}>{item.config.slotLabel || item.slotKey}</option>
                            ))}
                          </select>
                          <span className="adsSetupCellSub">{slot?.config?.slotLabel || campaign.slotKey} · {slot?.placementType || '-'}</span>
                        </div>
                      </td>
                      <td><span className="adsSetupCellSub">{campaignStatusLabel(campaign.status)}</span></td>
                      <td><input type="datetime-local" className="textInput exploreSheetInput" style={{ minWidth: 176, width: 176 }} value={draft.startAt} disabled={usingFallback || campaign.status === 'cancelled'} onChange={(e) => updateCampaignDraft(campaign.id, { startAt: e.target.value })} /></td>
                      <td><input type="datetime-local" className="textInput exploreSheetInput" style={{ minWidth: 176, width: 176 }} value={draft.endAt} disabled={usingFallback || campaign.status === 'cancelled'} onChange={(e) => updateCampaignDraft(campaign.id, { endAt: e.target.value })} /></td>
                      <td><input className="textInput exploreSheetInput exploreSpreadsheetInput" value={draft.title} disabled={usingFallback || campaign.status === 'cancelled'} onChange={(e) => updateCampaignDraft(campaign.id, { title: e.target.value })} /></td>
                      <td><input className="textInput exploreSheetInput exploreSpreadsheetInput" value={draft.message} disabled={usingFallback || campaign.status === 'cancelled'} onChange={(e) => updateCampaignDraft(campaign.id, { message: e.target.value })} /></td>
                      <td><input className="textInput exploreSheetInput" style={{ minWidth: 110, width: 110 }} value={draft.ctaLabel} disabled={usingFallback || campaign.status === 'cancelled'} onChange={(e) => updateCampaignDraft(campaign.id, { ctaLabel: e.target.value })} /></td>
                      <td><input className="textInput exploreSheetInput exploreSpreadsheetInput" value={draft.targetUrl} disabled={usingFallback || campaign.status === 'cancelled'} placeholder="https://..." onChange={(e) => updateCampaignDraft(campaign.id, { targetUrl: e.target.value })} /></td>
                      <td>
                        {draft.imageUrl ? (
                          <a href={draft.imageUrl} target="_blank" rel="noreferrer" className="exploreMiniThumbLink">
                            <img src={draft.imageUrl} alt={campaign.id} className="exploreMiniThumb adsSetupMiniThumb" />
                          </a>
                        ) : (
                          <span className="adsSetupCellSub">없음</span>
                        )}
                      </td>
                      <td>
                        <label className={`ghostBtn ghostBtnSmall adsUploadBtn${usingFallback || campaign.status === 'cancelled' ? ' disabled' : ''}`}>
                          {uploadingKey === campaign.id ? '업로드중' : '파일'}
                          <input
                            type="file"
                            accept=".png,.jpg,.jpeg,.webp,.svg,image/png,image/jpeg,image/webp,image/svg+xml"
                            className="hiddenInput"
                            disabled={usingFallback || campaign.status === 'cancelled'}
                            onChange={(e) => {
                              const file = e.target.files?.[0]
                              if (!file) return
                              void uploadAssetFile(file, campaign.id).then((url) => {
                                if (url) updateCampaignDraft(campaign.id, { imageUrl: url })
                              })
                            }}
                          />
                        </label>
                      </td>
                      <td>
                        <button className="primaryBtn ghostBtnSmall adsSetupSaveBtn" type="button" disabled={savingKey === campaign.id || usingFallback || campaign.status === 'cancelled'} onClick={() => void saveCampaign(campaign.id)}>
                          {savingKey === campaign.id ? '저장중' : '저장'}
                        </button>
                      </td>
                      <td>
                        <button className="primaryBtn ghostBtnSmall" type="button" disabled={savingKey === `cancel:${campaign.id}` || usingFallback || campaign.status === 'cancelled'} onClick={() => void cancelCampaign(campaign.id)}>
                          {campaign.status === 'cancelled' ? '취소됨' : savingKey === `cancel:${campaign.id}` ? '처리중' : '취소'}
                        </button>
                      </td>
                    </tr>
                  )
                })}
                {campaigns.length === 0 ? (
                  <tr>
                    <td colSpan={13} style={{ textAlign: 'center', color: '#64748b' }}>조건에 맞는 campaign row가 없어.</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      ) : null}

      {view === 'efficiency' ? (
      <div className="card exploreDenseCard exploreSheetCard" style={{ marginTop: 16, marginBottom: 24 }}>
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
      ) : null}
    </div>
  )
}
