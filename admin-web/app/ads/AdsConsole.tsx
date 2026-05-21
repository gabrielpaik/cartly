'use client'

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'

import { CampaignRow, fallbackSlots, SlotHistory, SlotRow } from '../../components/ads'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import PageHeader from '../../components/PageHeader'
import { deleteJson, fetchJsonSafe, isUnauthorizedError, postFormData, postJson, putJson } from '../../lib/api'
import { formatDate, formatNumber, formatPercent } from '../../lib/format'
import { KOREA_CITIES, KOREA_DISTRICTS_BY_CITY, KOREA_REGION_LOOKUP, RegionLevel, buildRegionKey, parseRegionTokens, regionKeysFromTokens, regionOptionsForLevel, regionSummaryFromKeys } from '../../lib/koreaRegions'

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
  sortOrder: string
  audienceType: string
  targetRegionLevel: string
  targetCity: string
  targetDistrict: string
  targetNeighborhood: string
  targetRegionKeys: string[]
  startDate: string
  endDate: string
  title: string
  message: string
  ctaLabel: string
  targetUrl: string
  landingCode: string
  imageUrl: string
}

type NewCampaignRow = {
  id: string
  draft: CampaignSheetDraft
}

type SetupSearchField = 'all' | 'title' | 'message' | 'cta' | 'url' | 'landing' | 'slot'

type LandingPreset = {
  value: string
  label: string
  landingType: string
  landingKey: string
  landingParams?: Record<string, string | number | boolean>
}

type BannerSizePreset = {
  id: string
  label: string
  note: string
}

type BannerUploadModalState = {
  rowId: string
  isNew: boolean
  slotKey: string
  presetId: string
  file: File | null
}

type RegionPickerModalState = {
  rowId: string
  isNew: boolean
  level: RegionLevel
  city: string
  district: string
  workingKeys: string[]
}

const AUDIENCE_OPTIONS = [
  { value: 'all', label: '전체' },
  { value: 'member', label: '회원' },
  { value: 'guest', label: '게스트' },
] as const

const REGION_LEVEL_OPTIONS = [
  { value: 'all', label: '전체' },
  { value: 'city', label: '시' },
  { value: 'district', label: '구' },
  { value: 'neighborhood', label: '동' },
] as const

const LANDING_PRESETS: LandingPreset[] = [
  { value: '', label: '없음', landingType: '', landingKey: '' },
  { value: 'explore.recommended_products', label: 'Explore 추천상품', landingType: 'explore_section', landingKey: 'recommended_products' },
  { value: 'saved.recent_saved', label: '지난 카트 최근 저장본', landingType: 'saved_flow', landingKey: 'recent_saved' },
  { value: 'saved.all_saved', label: '지난 카트 전체보기', landingType: 'saved_flow', landingKey: 'all_saved' },
  { value: 'my.benefits', label: 'My 혜택', landingType: 'my_section', landingKey: 'benefits' },
  { value: 'auth.signup', label: '회원가입', landingType: 'auth_flow', landingKey: 'signup' },
  { value: 'home.cart', label: '홈 현재 카트', landingType: 'home_tab', landingKey: 'cart' },
]

const BANNER_SIZE_PRESETS: Record<string, BannerSizePreset[]> = {
  save_complete_sheet_1: [
    { id: 'save-default', label: '기본 1200×176', note: '저장 완료 바텀시트용 기본 권장' },
    { id: 'save-retina', label: '고해상도 2400×352', note: '@2x 업로드용' },
  ],
  saved_inline_1: [
    { id: 'saved1-default', label: '기본 1200×208', note: '지난 카트 inline 1 권장' },
    { id: 'saved1-retina', label: '고해상도 2400×416', note: '@2x 업로드용' },
  ],
  saved_inline_2: [
    { id: 'saved2-default', label: '기본 1200×208', note: '지난 카트 inline 2 권장' },
    { id: 'saved2-retina', label: '고해상도 2400×416', note: '@2x 업로드용' },
  ],
  my_perks_inline_1: [
    { id: 'my-default', label: '기본 1200×192', note: 'My 혜택 배너 권장' },
    { id: 'my-retina', label: '고해상도 2400×384', note: '@2x 업로드용' },
  ],
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

function normalizeSheetDate(value: string | null | undefined) {
  const raw = (value ?? '').trim()
  if (!raw) return ''
  const normalized = raw.replace('T', ' ').replace(/\./g, '-').replace(/\/+?/g, '-').replace(/\s+/g, ' ')
  const match = normalized.match(/^(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}))?/) 
  if (!match) return raw
  const day = match[1]
  const time = match[2] ?? '00:00'
  return `${day} ${time}`
}

function landingCodeFromCampaign(campaign: CampaignRow) {
  const landingType = (campaign.landingType ?? '').trim()
  const landingKey = (campaign.landingKey ?? '').trim()
  if (!landingType || !landingKey) return ''
  const matched = LANDING_PRESETS.find((preset) => preset.landingType === landingType && preset.landingKey === landingKey)
  return matched?.value ?? `${landingType}:${landingKey}`
}

function landingPayloadFromCode(code: string) {
  const trimmed = code.trim()
  const matched = LANDING_PRESETS.find((preset) => preset.value === trimmed)
  if (!matched || !matched.landingType || !matched.landingKey) {
    return { landingType: null, landingKey: null, landingParams: null }
  }
  return {
    landingType: matched.landingType,
    landingKey: matched.landingKey,
    landingParams: matched.landingParams ?? null,
  }
}

function forceFullBannerLandingPayload(
  _slotKey: string,
  landing: ReturnType<typeof landingPayloadFromCode>,
) {
  return {
    ...landing,
    landingParams: {
      ...(landing.landingParams ?? {}),
      renderStyle: 'full_banner',
    },
  }
}

function landingLabelFromCode(code: string) {
  const trimmed = code.trim()
  if (!trimmed) return '-'
  const matched = LANDING_PRESETS.find((preset) => preset.value === trimmed)
  if (matched) return matched.label
  return trimmed
}

function composeTargetUrl(draft: CampaignSheetDraft) {
  const targetUrl = draft.targetUrl.trim()
  return targetUrl || null
}

function normalizeAudienceType(value: string) {
  const trimmed = value.trim().toLowerCase()
  if (trimmed === 'member' || trimmed === '회원') return 'member'
  if (trimmed === 'guest' || trimmed === '게스트') return 'guest'
  return 'all'
}

function normalizeTargetRegionLevel(value: string) {
  const trimmed = value.trim().toLowerCase()
  if (trimmed === 'city' || trimmed === '시') return 'city'
  if (trimmed === 'district' || trimmed === '구') return 'district'
  if (trimmed === 'neighborhood' || trimmed === '동') return 'neighborhood'
  return 'all'
}

function legacyRegionKeysFromDraft(draft: Pick<CampaignSheetDraft, 'targetRegionLevel' | 'targetCity' | 'targetDistrict' | 'targetNeighborhood'>) {
  const level = normalizeTargetRegionLevel(draft.targetRegionLevel)
  const city = draft.targetCity.trim()
  const district = draft.targetDistrict.trim()
  const neighborhood = draft.targetNeighborhood.trim()
  if (level === 'city' && city) return [buildRegionKey('city', city)]
  if (level === 'district' && city && district) return [buildRegionKey('district', city, district)]
  if (level === 'neighborhood' && city && neighborhood) return [buildRegionKey('neighborhood', city, district || null, neighborhood)]
  return []
}

function normalizeRegionKeysForDraft(draft: Pick<CampaignSheetDraft, 'targetRegionKeys' | 'targetRegionLevel' | 'targetCity' | 'targetDistrict' | 'targetNeighborhood'>) {
  const explicitKeys = Array.isArray(draft.targetRegionKeys) ? draft.targetRegionKeys.filter((key) => Boolean(KOREA_REGION_LOOKUP[key])) : []
  return explicitKeys.length > 0 ? explicitKeys : legacyRegionKeysFromDraft(draft)
}

function summarizeRegionSelection(draft: Pick<CampaignSheetDraft, 'targetRegionLevel' | 'targetRegionKeys' | 'targetCity' | 'targetDistrict' | 'targetNeighborhood'>) {
  const level = normalizeTargetRegionLevel(draft.targetRegionLevel)
  if (level === 'all') return '전체지역'
  const keys = normalizeRegionKeysForDraft(draft)
  return keys.length > 0 ? regionSummaryFromKeys(keys) : '선택 필요'
}

function regionTargetSummary(draft: CampaignSheetDraft) {
  const audienceLabel = AUDIENCE_OPTIONS.find((option) => option.value === draft.audienceType)?.label ?? '전체'
  const regionLabel = REGION_LEVEL_OPTIONS.find((option) => option.value === draft.targetRegionLevel)?.label ?? '전체'
  return [audienceLabel, regionLabel, summarizeRegionSelection(draft)].filter(Boolean).join(' ')
}

function firstRegionParts(keys: string[]) {
  const first = keys.find((key) => Boolean(KOREA_REGION_LOOKUP[key]))
  if (!first) return { city: '', district: '', neighborhood: '' }
  const option = KOREA_REGION_LOOKUP[first]
  return {
    city: option.cityName ?? '',
    district: option.districtName ?? '',
    neighborhood: option.neighborhoodName ?? '',
  }
}

function landingSelectOptions(code: string) {
  if (!code.trim()) return LANDING_PRESETS
  const exists = LANDING_PRESETS.some((preset) => preset.value === code)
  if (exists) return LANDING_PRESETS
  return [...LANDING_PRESETS, { value: code, label: `custom · ${code}`, landingType: '', landingKey: '' }]
}

function bannerPresetsForSlot(slotKey: string) {
  return BANNER_SIZE_PRESETS[slotKey] ?? [
    { id: 'generic-default', label: '기본 1200×192', note: '공통 inline 권장' },
    { id: 'generic-retina', label: '고해상도 2400×384', note: '@2x 업로드용' },
  ]
}

function composeDateTime(value: string) {
  const trimmed = value.trim()
  if (!trimmed) return ''
  const normalized = trimmed.replace('T', ' ').replace(/\./g, '-').replace(/\/+?/g, '-').replace(/\s+/g, ' ')
  const match = normalized.match(/^(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}):(\d{2}))?$/)
  if (!match) return trimmed
  const day = match[1]
  const hour = match[2] ?? '00'
  const minute = match[3] ?? '00'
  return `${day}T${hour}:${minute}:00`
}

function emptyCampaignDraft(slotKey = ''): CampaignSheetDraft {
  return {
    slotKey,
    sortOrder: '1',
    audienceType: 'all',
    targetRegionLevel: 'all',
    targetCity: '',
    targetDistrict: '',
    targetNeighborhood: '',
    targetRegionKeys: [],
    startDate: '',
    endDate: '',
    title: '',
    message: '',
    ctaLabel: '',
    targetUrl: '',
    landingCode: '',
    imageUrl: '',
  }
}

function draftFromCampaign(campaign: CampaignRow): CampaignSheetDraft {
  return {
    slotKey: campaign.slotKey,
    sortOrder: String(campaign.sortOrder ?? 1),
    audienceType: normalizeAudienceType(campaign.audienceType ?? 'all'),
    targetRegionLevel: normalizeTargetRegionLevel(campaign.targetRegionLevel ?? 'all'),
    targetCity: campaign.targetCity ?? '',
    targetDistrict: campaign.targetDistrict ?? '',
    targetNeighborhood: campaign.targetNeighborhood ?? '',
    targetRegionKeys: Array.isArray(campaign.targetRegionKeys) ? campaign.targetRegionKeys.filter((key) => Boolean(KOREA_REGION_LOOKUP[key])) : legacyRegionKeysFromDraft({
      targetRegionLevel: normalizeTargetRegionLevel(campaign.targetRegionLevel ?? 'all'),
      targetCity: campaign.targetCity ?? '',
      targetDistrict: campaign.targetDistrict ?? '',
      targetNeighborhood: campaign.targetNeighborhood ?? '',
    }),
    startDate: normalizeSheetDate(campaign.startAt),
    endDate: normalizeSheetDate(campaign.endAt),
    title: campaign.title ?? '',
    message: campaign.message ?? '',
    ctaLabel: campaign.ctaLabel ?? '',
    targetUrl: campaign.targetUrl ?? '',
    landingCode: landingCodeFromCampaign(campaign),
    imageUrl: campaign.imageUrl ?? '',
  }
}

function sameDraft(left: CampaignSheetDraft, right: CampaignSheetDraft) {
  return JSON.stringify(left) === JSON.stringify(right)
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
  const [newRows, setNewRows] = useState<NewCampaignRow[]>([])
  const [selectedRowIds, setSelectedRowIds] = useState<string[]>([])
  const [slotStatusDrafts, setSlotStatusDrafts] = useState<Record<string, 'active' | 'inactive'>>({})
  const [setupPeriodFrom, setSetupPeriodFrom] = useState('')
  const [setupPeriodTo, setSetupPeriodTo] = useState('')
  const [setupSearchField, setSetupSearchField] = useState<SetupSearchField>('title')
  const [setupSearchQuery, setSetupSearchQuery] = useState('')
  const [usingFallback, setUsingFallback] = useState(true)
  const [loading, setLoading] = useState(true)
  const [workspaceLoading, setWorkspaceLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [savingKey, setSavingKey] = useState<string | null>(null)
  const [uploadingKey, setUploadingKey] = useState<string | null>(null)
  const [setupUploadModalOpen, setSetupUploadModalOpen] = useState(false)
  const [setupUploadFile, setSetupUploadFile] = useState<File | null>(null)
  const [bannerUploadModal, setBannerUploadModal] = useState<BannerUploadModalState | null>(null)
  const [regionPickerModal, setRegionPickerModal] = useState<RegionPickerModalState | null>(null)
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
  const dirtyExistingIds = useMemo(
    () => campaigns.filter((campaign) => !sameDraft(campaignDrafts[campaign.id] ?? draftFromCampaign(campaign), draftFromCampaign(campaign))).map((campaign) => campaign.id),
    [campaignDrafts, campaigns],
  )
  const dirtySlotKeys = useMemo(
    () => slots.filter((slot) => (slotStatusDrafts[slot.slotKey] ?? slot.status) !== slot.status).map((slot) => slot.slotKey),
    [slotStatusDrafts, slots],
  )
  const visibleSetupRows = useMemo(() => {
    const q = setupSearchQuery.trim().toLowerCase()
    const periodFrom = setupPeriodFrom.trim()
    const periodTo = setupPeriodTo.trim()
    const matchesPeriod = (draft: CampaignSheetDraft) => {
      const start = draft.startDate.trim().slice(0, 10)
      const end = draft.endDate.trim().slice(0, 10)
      if (periodFrom && end && end < periodFrom) return false
      if (periodTo && start && start > periodTo) return false
      return true
    }
    const matchesSearch = (draft: CampaignSheetDraft) => {
      if (!q) return true
      const slotLabel = slotsByKey[draft.slotKey]?.config.slotLabel ?? draft.slotKey
      const landingLabel = landingLabelFromCode(draft.landingCode)
      const values: Record<SetupSearchField, string> = {
        all: [slotLabel, draft.title, draft.message, draft.ctaLabel, draft.targetUrl, landingLabel, regionTargetSummary(draft)].join(' ').toLowerCase(),
        title: draft.title.toLowerCase(),
        message: draft.message.toLowerCase(),
        cta: draft.ctaLabel.toLowerCase(),
        url: draft.targetUrl.toLowerCase(),
        landing: landingLabel.toLowerCase(),
        slot: slotLabel.toLowerCase(),
      }
      return values[setupSearchField].includes(q)
    }
    const sortRows = (left: {id: string; draft: CampaignSheetDraft}, right: {id: string; draft: CampaignSheetDraft}) => {
      const leftSort = Number.parseInt(left.draft.sortOrder || '1', 10) || 1
      const rightSort = Number.parseInt(right.draft.sortOrder || '1', 10) || 1
      const leftRank = leftSort === 999 ? 999999 : leftSort
      const rightRank = rightSort === 999 ? 999999 : rightSort
      return `${left.draft.startDate}|${leftRank.toString().padStart(6, '0')}|${left.id}`.localeCompare(`${right.draft.startDate}|${rightRank.toString().padStart(6, '0')}|${right.id}`)
    }
    const existing = campaigns
      .map((campaign) => ({ id: campaign.id, isNew: false as const, draft: campaignDrafts[campaign.id] ?? draftFromCampaign(campaign), campaign }))
      .filter((row) => matchesPeriod(row.draft) && matchesSearch(row.draft))
      .sort(sortRows)
    const drafts = newRows
      .map((row) => ({ id: row.id, isNew: true as const, draft: row.draft, campaign: null }))
      .filter((row) => matchesPeriod(row.draft) && matchesSearch(row.draft))
      .sort(sortRows)
    return [...drafts, ...existing]
  }, [campaignDrafts, campaigns, newRows, setupPeriodFrom, setupPeriodTo, setupSearchField, setupSearchQuery, slotsByKey])

  async function loadSlots() {
    const res = await fetchJsonSafe<{ ok: boolean; data: { slots: SlotRow[] } }>('/admin/ads/slots', { ok: true, data: { slots: fallbackSlots } })
    setSlots(res.data.data.slots)
    setSlotStatusDrafts(Object.fromEntries(res.data.data.slots.map((slot) => [slot.slotKey, slot.status as 'active' | 'inactive'])))
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
    if (view !== 'setup') {
      if (historyQuery.trim()) params.set('query', historyQuery.trim())
      if (historyVariantFilter !== 'all') params.set('variant', historyVariantFilter)
      if (historyStatusFilter !== 'all') params.set('status', historyStatusFilter)
      if (historyPeriodFrom) params.set('periodFrom', historyPeriodFrom)
      if (historyPeriodTo) params.set('periodTo', historyPeriodTo)
    }
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

  function updateNewRow(id: string, patch: Partial<CampaignSheetDraft>) {
    setNewRows((prev) => prev.map((row) => (row.id === id ? { ...row, draft: { ...row.draft, ...patch } } : row)))
  }

  function patchRowDraft(rowId: string, isNew: boolean, patch: Partial<CampaignSheetDraft>) {
    if (isNew) updateNewRow(rowId, patch)
    else updateCampaignDraft(rowId, patch)
  }

  function openRegionPicker(rowId: string, isNew: boolean, draft: CampaignSheetDraft) {
    const level = normalizeTargetRegionLevel(draft.targetRegionLevel) as RegionLevel
    const normalizedKeys = normalizeRegionKeysForDraft(draft)
    const firstParts = firstRegionParts(normalizedKeys)
    setRegionPickerModal({
      rowId,
      isNew,
      level,
      city: firstParts.city || KOREA_CITIES[0]?.cityName || '',
      district: firstParts.district || '',
      workingKeys: normalizedKeys,
    })
  }

  function toggleRegionPickerKey(key: string) {
    setRegionPickerModal((prev) => {
      if (!prev) return prev
      const exists = prev.workingKeys.includes(key)
      return {
        ...prev,
        workingKeys: exists ? prev.workingKeys.filter((item) => item !== key) : [...prev.workingKeys, key],
      }
    })
  }

  function applyRegionPickerSelection() {
    if (!regionPickerModal) return
    const nextKeys = Array.from(new Set(regionPickerModal.workingKeys.filter((key) => Boolean(KOREA_REGION_LOOKUP[key])))).sort()
    const primary = firstRegionParts(nextKeys)
    patchRowDraft(regionPickerModal.rowId, regionPickerModal.isNew, {
      targetRegionLevel: regionPickerModal.level,
      targetRegionKeys: nextKeys,
      targetCity: primary.city,
      targetDistrict: primary.district,
      targetNeighborhood: primary.neighborhood,
    })
    setRegionPickerModal(null)
  }

  function updateSlotStatus(slotKey: string, next: 'active' | 'inactive') {
    setSlotStatusDrafts((prev) => ({ ...prev, [slotKey]: next }))
  }

  function toggleRowSelection(id: string, checked: boolean) {
    setSelectedRowIds((prev) => (checked ? [...prev.filter((item) => item !== id), id] : prev.filter((item) => item !== id)))
  }

  function toggleAllVisibleRows(checked: boolean) {
    setSelectedRowIds(checked ? visibleSetupRows.map((row) => row.id) : [])
  }

  function addNewRow() {
    const nextId = `draft-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
    const defaultSlotKey = slots[0]?.slotKey ?? fallbackSlots[0]?.slotKey ?? ''
    const nextDraft = emptyCampaignDraft(defaultSlotKey)
    if (setupPeriodFrom) nextDraft.startDate = setupPeriodFrom
    if (setupPeriodTo) nextDraft.endDate = setupPeriodTo
    setNewRows((prev) => [{ id: nextId, draft: nextDraft }, ...prev])
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

  async function downloadSetupTemplate() {
    const XLSX = await import('xlsx')
    const workbook = XLSX.utils.book_new()
    const availableSlots = slots.length > 0 ? slots : fallbackSlots
    const templateSheet = XLSX.utils.json_to_sheet([
      {
        정렬: '1',
        슬롯종류: availableSlots[0]?.slotKey ?? '',
        연결상태: 'active',
        고객구분: 'all',
        지역단위: 'all',
        지역선택: '',
        시작일: '',
        종료일: '',
        제목: '',
        문구: '',
        CTA: '',
        링크URL: '',
        랜딩페이지: '',
        배너: '',
      },
    ])
    const slotGuideSheet = XLSX.utils.json_to_sheet(
      availableSlots.map((slot) => ({
        슬롯종류: slot.slotKey,
        슬롯이름: slot.config.slotLabel?.trim() || slot.slotKey,
        위치: slot.config.placementNote?.trim() || '-',
        화면: slot.config.screen ?? '',
        포지션: slot.config.position ?? '',
        날짜입력예시: 'YYYY-MM-DD 00:00',
      })),
    )
    XLSX.utils.book_append_sheet(workbook, templateSheet, 'AdsSetupTemplate')
    XLSX.utils.book_append_sheet(workbook, slotGuideSheet, 'SlotGuide')
    XLSX.writeFile(workbook, 'cartly-ads-setup-template.xlsx')
  }

  function openBannerUploadModal(rowId: string, isNew: boolean, slotKey: string) {
    const presets = bannerPresetsForSlot(slotKey)
    setBannerUploadModal({ rowId, isNew, slotKey, presetId: presets[0]?.id ?? 'generic-default', file: null })
  }

  async function confirmBannerUpload() {
    if (!bannerUploadModal?.file) {
      showActionError('업로드할 배너 파일을 먼저 골라줘')
      return
    }
    const rowId = bannerUploadModal.rowId
    const url = await uploadAssetFile(bannerUploadModal.file, rowId)
    if (!url) return
    if (bannerUploadModal.isNew) updateNewRow(rowId, { imageUrl: url })
    else updateCampaignDraft(rowId, { imageUrl: url })
    setBannerUploadModal(null)
  }

  async function confirmSetupUpload() {
    if (!setupUploadFile) {
      showActionError('업로드할 시트 파일을 먼저 골라줘')
      return
    }
    await uploadSetupSheet(setupUploadFile)
    setSetupUploadFile(null)
    setSetupUploadModalOpen(false)
  }

  async function deleteSelectedRows() {
    if (selectedRowIds.length === 0) return
    setSavingKey('bulk-delete')
    setMessage(null)
    try {
      const draftIds = selectedRowIds.filter((id) => id.startsWith('draft-'))
      const campaignIds = selectedRowIds.filter((id) => !id.startsWith('draft-'))
      if (campaignIds.length > 0) {
        for (const campaignId of campaignIds) {
          await deleteJson<{ ok: boolean; data: { id: string } }>(`/admin/ads/campaigns/${campaignId}`)
        }
      }
      if (draftIds.length > 0) {
        setNewRows((prev) => prev.filter((row) => !draftIds.includes(row.id)))
      }
      setSelectedRowIds([])
      await refreshAll()
      setMessage('선택 행 삭제 완료')
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      showActionError(err instanceof Error ? err.message : '선택 행 삭제 실패')
    } finally {
      setSavingKey(null)
    }
  }

  async function saveAllRows() {
    setSavingKey('bulk-save')
    setMessage(null)
    try {
      for (const row of newRows) {
        const draft = row.draft
        const landing = forceFullBannerLandingPayload(
          draft.slotKey,
          landingPayloadFromCode(draft.landingCode),
        )
        await postJson<{ ok: boolean; data: CampaignRow }>('/admin/ads/campaigns', {
          slotKey: draft.slotKey,
          sortOrder: Number.parseInt(draft.sortOrder || '1', 10) || 1,
          audienceType: draft.audienceType,
          targetRegionLevel: draft.targetRegionLevel,
          targetRegionKeys: normalizeRegionKeysForDraft(draft),
          targetCity: draft.targetCity.trim() || null,
          targetDistrict: draft.targetDistrict.trim() || null,
          targetNeighborhood: draft.targetNeighborhood.trim() || null,
          startAt: composeDateTime(draft.startDate),
          endAt: composeDateTime(draft.endDate),
          title: draft.title,
          message: draft.message,
          ctaLabel: draft.ctaLabel || null,
          targetUrl: composeTargetUrl(draft),
          landingType: landing.landingType,
          landingKey: landing.landingKey,
          landingParams: landing.landingParams,
          imageUrl: draft.imageUrl || null,
        })
      }
      for (const campaignId of dirtyExistingIds) {
        const draft = campaignDrafts[campaignId]
        if (!draft) continue
        const landing = forceFullBannerLandingPayload(
          draft.slotKey,
          landingPayloadFromCode(draft.landingCode),
        )
        await putJson<{ ok: boolean; data: CampaignRow }>(`/admin/ads/campaigns/${campaignId}`, {
          slotKey: draft.slotKey,
          sortOrder: Number.parseInt(draft.sortOrder || '1', 10) || 1,
          audienceType: draft.audienceType,
          targetRegionLevel: draft.targetRegionLevel,
          targetRegionKeys: normalizeRegionKeysForDraft(draft),
          targetCity: draft.targetCity.trim() || null,
          targetDistrict: draft.targetDistrict.trim() || null,
          targetNeighborhood: draft.targetNeighborhood.trim() || null,
          startAt: composeDateTime(draft.startDate),
          endAt: composeDateTime(draft.endDate),
          title: draft.title,
          message: draft.message,
          ctaLabel: draft.ctaLabel || null,
          targetUrl: composeTargetUrl(draft),
          landingType: landing.landingType,
          landingKey: landing.landingKey,
          landingParams: landing.landingParams,
          imageUrl: draft.imageUrl || null,
        })
      }
      for (const slotKey of dirtySlotKeys) {
        await putJson<{ ok: boolean; data: SlotRow }>(`/admin/ads/slots/${slotKey}`, {
          status: slotStatusDrafts[slotKey],
        })
      }
      setNewRows([])
      setSelectedRowIds([])
      await refreshAll()
      setMessage('세팅 시트 저장 완료')
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      showActionError(err instanceof Error ? err.message : '세팅 시트 저장 실패')
    } finally {
      setSavingKey(null)
    }
  }

  async function downloadSetupSheet() {
    const XLSX = await import('xlsx')
    const rows = visibleSetupRows.map((row) => ({
      정렬: row.draft.sortOrder,
      슬롯종류: row.draft.slotKey,
      연결상태: slotStatusDrafts[row.draft.slotKey] ?? slotsByKey[row.draft.slotKey]?.status ?? 'active',
      고객구분: row.draft.audienceType,
      지역단위: row.draft.targetRegionLevel,
      지역선택: normalizeRegionKeysForDraft(row.draft).join(', '),
      지역요약: summarizeRegionSelection(row.draft),
      시작일: row.draft.startDate,
      종료일: row.draft.endDate,
      제목: row.draft.title,
      문구: row.draft.message,
      CTA: row.draft.ctaLabel,
      링크URL: row.draft.targetUrl,
      랜딩페이지: row.draft.landingCode,
      배너: row.draft.imageUrl,
    }))
    const workbook = XLSX.utils.book_new()
    const sheet = XLSX.utils.json_to_sheet(rows)
    XLSX.utils.book_append_sheet(workbook, sheet, 'AdsSetup')
    XLSX.writeFile(workbook, 'cartly-ads-setup-sheet.xlsx')
  }

  async function uploadSetupSheet(file: File | null) {
    if (!file) return
    try {
      const XLSX = await import('xlsx')
      const workbook = XLSX.read(await file.arrayBuffer(), { type: 'array' })
      const firstSheetName = workbook.SheetNames[0]
      const worksheet = workbook.Sheets[firstSheetName]
      const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(worksheet, { defval: '' })
      const nextSlotStatuses: Record<string, 'active' | 'inactive'> = {}
      const imported: NewCampaignRow[] = rows
        .map((row, index) => {
          const slotKey = String(row['슬롯종류'] || row['slotKey'] || '').trim()
          if (!slotKey) return null
          const rawStatus = String(row['연결상태'] || row['slotStatus'] || '').trim().toLowerCase()
          if (rawStatus === 'inactive' || rawStatus === '중지') nextSlotStatuses[slotKey] = 'inactive'
          else if (rawStatus === 'active' || rawStatus === '연결') nextSlotStatuses[slotKey] = 'active'
          const audienceType = normalizeAudienceType(String(row['고객구분'] || row['audienceType'] || 'all'))
          const targetRegionLevel = normalizeTargetRegionLevel(String(row['지역단위'] || row['targetRegionLevel'] || 'all'))
          const rawRegionSelection = String(row['지역선택'] || row['targetRegionKeys'] || '').trim()
          let targetRegionKeys = regionKeysFromTokens(parseRegionTokens(rawRegionSelection))
          const targetCity = String(row['시'] || row['targetCity'] || '').trim()
          const targetDistrict = String(row['구'] || row['targetDistrict'] || '').trim()
          const targetNeighborhood = String(row['동'] || row['targetNeighborhood'] || '').trim()
          if (targetRegionKeys.length === 0) {
            targetRegionKeys = legacyRegionKeysFromDraft({ targetRegionLevel, targetCity, targetDistrict, targetNeighborhood })
          }
          const primary = firstRegionParts(targetRegionKeys)
          const startDate = normalizeSheetDate(String(row['시작일'] || row['startDate'] || ''))
          const endDate = normalizeSheetDate(String(row['종료일'] || row['endDate'] || ''))
          const title = String(row['제목'] || row['title'] || '').trim()
          const message = String(row['문구'] || row['message'] || '').trim()
          const ctaLabel = String(row['CTA'] || row['ctaLabel'] || '').trim()
          const targetUrl = String(row['링크URL'] || row['targetUrl'] || '').trim()
          const landingCode = String(row['랜딩페이지'] || row['landingPage'] || '').trim()
          const imageUrl = String(row['배너'] || row['imageUrl'] || '').trim()
          if (!startDate && !endDate && !title && !message && !ctaLabel && !targetUrl && !landingCode && !imageUrl && targetRegionKeys.length === 0 && audienceType === 'all' && targetRegionLevel === 'all') {
            return null
          }
          return {
            id: `draft-import-${Date.now()}-${index}`,
            draft: {
              slotKey,
              sortOrder: String(row['정렬'] || row['sortOrder'] || '1').trim() || '1',
              audienceType,
              targetRegionLevel,
              targetCity: primary.city || targetCity,
              targetDistrict: primary.district || targetDistrict,
              targetNeighborhood: primary.neighborhood || targetNeighborhood,
              targetRegionKeys,
              startDate,
              endDate,
              title,
              message,
              ctaLabel,
              targetUrl,
              landingCode,
              imageUrl,
            },
          }
        })
        .filter((row): row is NewCampaignRow => row !== null)
      if (Object.keys(nextSlotStatuses).length > 0) {
        setSlotStatusDrafts((prev) => ({ ...prev, ...nextSlotStatuses }))
      }
      setNewRows((prev) => [...imported, ...prev])
      setMessage(`${imported.length}개 row 업로드 완료`)
    } catch (err) {
      showActionError(err instanceof Error ? err.message : '세팅 시트 업로드 실패')
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

      {view !== 'setup' ? (
      <>
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
      </>
      ) : null}

      {view !== 'setup' ? (
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
      ) : null}

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
              <p className="pageDesc" style={{ marginBottom: 6 }}>진열기간 조회, 조건검색, 일괄 추가/삭제/저장으로 바로 운영하는 타이트한 광고 시트야.</p>
            </div>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">visible rows {visibleSetupRows.length}</div>
              <div className="metaPill">selected {selectedRowIds.length}</div>
              <div className="metaPill">dirty {newRows.length + dirtyExistingIds.length + dirtySlotKeys.length}</div>
            </div>
          </div>

          <div className="adsSetupToolbar">
            <div className="adsSetupToolbarLeft">
              <label className="field compactInlineField adsSetupToolbarField" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">진열기간</div>
                <div className="adsCompactDateRange">
                  <input className="textInput exploreSheetInput compactInlineInput" type="date" value={setupPeriodFrom} onChange={(e) => setSetupPeriodFrom(e.target.value)} />
                  <span className="adsCompactDateDivider">~</span>
                  <input className="textInput exploreSheetInput compactInlineInput" type="date" value={setupPeriodTo} onChange={(e) => setSetupPeriodTo(e.target.value)} />
                </div>
              </label>
              <label className="field compactInlineField adsSetupToolbarField" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">조건검색</div>
                <div className="adsSetupSearchRow">
                  <select className="textInput exploreSheetInput compactInlineSelect" value={setupSearchField} onChange={(e) => setSetupSearchField(e.target.value as SetupSearchField)}>
                    <option value="title">제목</option>
                    <option value="message">문구</option>
                    <option value="cta">CTA</option>
                    <option value="url">링크URL</option>
                    <option value="landing">랜딩페이지</option>
                    <option value="slot">슬롯종류</option>
                    <option value="all">전체</option>
                  </select>
                  <input className="textInput exploreSheetInput compactInlineInput" value={setupSearchQuery} onChange={(e) => setSetupSearchQuery(e.target.value)} placeholder="검색어 입력" />
                </div>
              </label>
            </div>
            <div className="adsSetupToolbarActions">
              <button className="ghostBtn ghostBtnSmall adsSetupActionBtn" type="button" onClick={() => void downloadSetupSheet()}>다운로드</button>
              <button className="ghostBtn ghostBtnSmall adsSetupActionBtn" type="button" disabled={usingFallback} onClick={() => setSetupUploadModalOpen(true)}>업로드</button>
              <button className="ghostBtn ghostBtnSmall adsSetupActionBtn" type="button" onClick={() => void downloadSetupTemplate()}>양식</button>
              <button className="ghostBtn ghostBtnSmall adsSetupActionBtn" type="button" disabled={usingFallback} onClick={addNewRow}>추가</button>
              <button className="ghostBtn ghostBtnSmall adsSetupActionBtn" type="button" disabled={selectedRowIds.length === 0 || usingFallback || savingKey === 'bulk-delete'} onClick={() => void deleteSelectedRows()}>
                {savingKey === 'bulk-delete' ? '삭제중' : '삭제'}
              </button>
              <button className="primaryBtn ghostBtnSmall adsSetupActionBtn adsSetupSaveActionBtn" type="button" disabled={usingFallback || savingKey === 'bulk-save'} onClick={() => void saveAllRows()}>
                {savingKey === 'bulk-save' ? '저장중' : '저장'}
              </button>
            </div>
          </div>

          <div className="exploreSheetViewport adsSetupSheetViewport">
            <table className="exploreSimpleSheet adsSetupSheet adsSetupUnifiedSheet adsTightSetupSheet" style={{ width: 3360, minWidth: 3360 }}>
              <thead>
                <tr>
                  <th>
                    <input
                      type="checkbox"
                      checked={visibleSetupRows.length > 0 && selectedRowIds.length === visibleSetupRows.length}
                      onChange={(e) => toggleAllVisibleRows(e.target.checked)}
                    />
                  </th>
                  <th></th>
                  <th>정렬</th>
                  <th>슬롯종류</th>
                  <th>연결상태</th>
                  <th>고객구분</th>
                  <th>지역단위</th>
                  <th>지역선택</th>
                  <th>시작일</th>
                  <th>종료일</th>
                  <th>제목</th>
                  <th>문구</th>
                  <th>CTA</th>
                  <th>링크URL</th>
                  <th>랜딩페이지</th>
                  <th>배너</th>
                </tr>
              </thead>
              <tbody>
                {visibleSetupRows.map((row, index) => {
                  const slot = slotsByKey[row.draft.slotKey] ?? fallbackSlots[0]
                  const slotStatus = slotStatusDrafts[row.draft.slotKey] ?? slot?.status ?? 'active'
                  return (
                    <tr key={row.id} className={row.isNew ? 'adsSetupDraftRow' : undefined}>
                      <td>
                        <input type="checkbox" checked={selectedRowIds.includes(row.id)} onChange={(e) => toggleRowSelection(row.id, e.target.checked)} />
                      </td>
                      <td>
                        <span className={`adsSetupCue${row.isNew ? ' isDraft' : ''}`}>{row.isNew ? '+' : ''}</span>
                      </td>
                      <td>
                        <input
                          type="number"
                          min="1"
                          className="textInput exploreSheetInput adsSheetOrderInput"
                          value={row.draft.sortOrder}
                          disabled={usingFallback}
                          onChange={(e) => {
                            const next = { sortOrder: e.target.value }
                            if (row.isNew) updateNewRow(row.id, next)
                            else updateCampaignDraft(row.id, next)
                          }}
                        />
                      </td>
                      <td>
                        <select
                          className="textInput exploreSheetInput adsSheetSelect"
                          value={row.draft.slotKey}
                          disabled={usingFallback}
                          onChange={(e) => {
                            const next = { slotKey: e.target.value }
                            if (row.isNew) updateNewRow(row.id, next)
                            else updateCampaignDraft(row.id, next)
                          }}
                        >
                          {slots.map((item) => (
                            <option key={`${row.id}-${item.slotKey}`} value={item.slotKey}>{item.config.slotLabel || item.slotKey}</option>
                          ))}
                        </select>
                      </td>
                      <td>
                        <select className="textInput exploreSheetInput adsSheetSmallSelect" value={slotStatus} disabled={usingFallback} onChange={(e) => updateSlotStatus(row.draft.slotKey, e.target.value as 'active' | 'inactive')}>
                          <option value="active">연결</option>
                          <option value="inactive">중지</option>
                        </select>
                      </td>
                      <td>
                        <select className="textInput exploreSheetInput adsSheetSmallSelect" value={row.draft.audienceType} disabled={usingFallback} onChange={(e) => row.isNew ? updateNewRow(row.id, { audienceType: e.target.value }) : updateCampaignDraft(row.id, { audienceType: e.target.value })}>
                          {AUDIENCE_OPTIONS.map((option) => (
                            <option key={`${row.id}-audience-${option.value}`} value={option.value}>{option.label}</option>
                          ))}
                        </select>
                      </td>
                      <td>
                        <select className="textInput exploreSheetInput adsSheetSmallSelect" value={row.draft.targetRegionLevel} disabled={usingFallback} onChange={(e) => patchRowDraft(row.id, row.isNew, {
                          targetRegionLevel: e.target.value,
                          targetRegionKeys: [],
                          targetCity: '',
                          targetDistrict: '',
                          targetNeighborhood: '',
                        })}>
                          {REGION_LEVEL_OPTIONS.map((option) => (
                            <option key={`${row.id}-region-${option.value}`} value={option.value}>{option.label}</option>
                          ))}
                        </select>
                      </td>
                      <td>
                        <button
                          type="button"
                          className="ghostBtn ghostBtnSmall adsRegionPickerBtn"
                          disabled={usingFallback || row.draft.targetRegionLevel === 'all'}
                          onClick={() => openRegionPicker(row.id, row.isNew, row.draft)}
                        >
                          <span className="adsRegionPickerBtnLabel">{summarizeRegionSelection(row.draft)}</span>
                          <span className="adsRegionPickerBtnMeta">선택</span>
                        </button>
                      </td>
                      <td>
                        <input className="textInput exploreSheetInput adsSheetDateInput" value={row.draft.startDate} disabled={usingFallback} placeholder="YYYY-MM-DD 00:00" onChange={(e) => row.isNew ? updateNewRow(row.id, { startDate: e.target.value }) : updateCampaignDraft(row.id, { startDate: e.target.value })} />
                      </td>
                      <td>
                        <input className="textInput exploreSheetInput adsSheetDateInput" value={row.draft.endDate} disabled={usingFallback} placeholder="YYYY-MM-DD 00:00" onChange={(e) => row.isNew ? updateNewRow(row.id, { endDate: e.target.value }) : updateCampaignDraft(row.id, { endDate: e.target.value })} />
                      </td>
                      <td><input className="textInput exploreSheetInput adsSheetTextInput" value={row.draft.title} disabled={usingFallback} onChange={(e) => row.isNew ? updateNewRow(row.id, { title: e.target.value }) : updateCampaignDraft(row.id, { title: e.target.value })} /></td>
                      <td><input className="textInput exploreSheetInput adsSheetTextInput" value={row.draft.message} disabled={usingFallback} onChange={(e) => row.isNew ? updateNewRow(row.id, { message: e.target.value }) : updateCampaignDraft(row.id, { message: e.target.value })} /></td>
                      <td><input className="textInput exploreSheetInput adsSheetCtaInput" value={row.draft.ctaLabel} disabled={usingFallback} onChange={(e) => row.isNew ? updateNewRow(row.id, { ctaLabel: e.target.value }) : updateCampaignDraft(row.id, { ctaLabel: e.target.value })} /></td>
                      <td><input className="textInput exploreSheetInput adsSheetUrlInput" value={row.draft.targetUrl} disabled={usingFallback} placeholder="https://..." onChange={(e) => {
                        const patch = { targetUrl: e.target.value, landingCode: e.target.value.trim() ? '' : row.draft.landingCode }
                        if (row.isNew) updateNewRow(row.id, patch)
                        else updateCampaignDraft(row.id, patch)
                      }} /></td>
                      <td>
                        <select
                          className="textInput exploreSheetInput adsSheetLandingInput"
                          value={row.draft.landingCode}
                          disabled={usingFallback}
                          onChange={(e) => {
                            const patch = { landingCode: e.target.value, targetUrl: e.target.value ? '' : row.draft.targetUrl }
                            if (row.isNew) updateNewRow(row.id, patch)
                            else updateCampaignDraft(row.id, patch)
                          }}
                        >
                          {landingSelectOptions(row.draft.landingCode).map((option) => (
                            <option key={`${row.id}-${option.value || 'empty'}`} value={option.value}>{option.label}</option>
                          ))}
                        </select>
                      </td>
                      <td>
                        <div className="adsBannerCell">
                          <div className="adsBannerCellPreview">
                            {row.draft.imageUrl ? (
                              <a href={row.draft.imageUrl} target="_blank" rel="noreferrer" className="exploreMiniThumbLink">
                                <img src={row.draft.imageUrl} alt={row.id} className="exploreMiniThumb adsSetupMiniThumb" />
                              </a>
                            ) : (
                              <span className="adsSetupCellSub">-</span>
                            )}
                          </div>
                          <button className={`adsUploadIconBtn${usingFallback ? ' disabled' : ''}`} type="button" title="배너 업로드" disabled={usingFallback} onClick={() => openBannerUploadModal(row.id, row.isNew, row.draft.slotKey)}>
                            {uploadingKey === row.id ? '…' : '⤴'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
                {visibleSetupRows.length === 0 ? (
                  <tr>
                    <td colSpan={16} style={{ textAlign: 'center', color: '#64748b' }}>조건에 맞는 campaign row가 없어.</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      ) : null}

      {setupUploadModalOpen ? (
        <div className="adsModalBackdrop" onClick={() => { setSetupUploadModalOpen(false); setSetupUploadFile(null) }}>
          <div className="adsModalCard" onClick={(event) => event.stopPropagation()}>
            <div className="adsModalHeader">
              <div>
                <h3 className="panelTitle" style={{ marginBottom: 6 }}>세팅 시트 업로드</h3>
                <p className="pageDesc" style={{ margin: 0 }}>파일을 바로 집어넣지 말고, 양식 확인 후 일괄 반입하는 팝업이야.</p>
              </div>
              <button className="ghostBtn ghostBtnSmall adsModalCloseBtn" type="button" onClick={() => { setSetupUploadModalOpen(false); setSetupUploadFile(null) }}>닫기</button>
            </div>
            <div className="adsModalBody">
              <div className="adsModalInfoCard">
                <strong>권장 순서</strong>
                <span>1) 양식 받기 → 2) Excel/CSV 작성 → 3) 여기서 파일 선택 → 4) 시트 넣기</span>
              </div>
              <div className="adsModalActionRow">
                <button className="ghostBtn ghostBtnSmall" type="button" onClick={() => void downloadSetupTemplate()}>양식 받기</button>
                <label className="ghostBtn ghostBtnSmall adsModalFileBtn">
                  파일 선택
                  <input
                    type="file"
                    accept=".xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv"
                    className="hiddenInput"
                    onChange={(e) => setSetupUploadFile(e.target.files?.[0] ?? null)}
                  />
                </label>
                <span className="adsModalFileName">{setupUploadFile?.name ?? '선택된 파일 없음'}</span>
              </div>
            </div>
            <div className="adsModalFooter">
              <button className="ghostBtn ghostBtnSmall" type="button" onClick={() => { setSetupUploadModalOpen(false); setSetupUploadFile(null) }}>취소</button>
              <button className="primaryBtn ghostBtnSmall" type="button" onClick={() => void confirmSetupUpload()}>시트 넣기</button>
            </div>
          </div>
        </div>
      ) : null}

      {regionPickerModal ? (
        <div className="adsModalBackdrop" onClick={() => setRegionPickerModal(null)}>
          <div className="adsModalCard adsRegionPickerModal" onClick={(event) => event.stopPropagation()}>
            <div className="adsModalHeader">
              <div>
                <h3 className="panelTitle" style={{ marginBottom: 6 }}>지역 선택</h3>
                <p className="pageDesc" style={{ margin: 0 }}>공식 행정구역 기준으로 좁혀서 여러 개를 선택해. 저장은 같은 row 안에서 유지돼.</p>
              </div>
              <button className="ghostBtn ghostBtnSmall adsModalCloseBtn" type="button" onClick={() => setRegionPickerModal(null)}>닫기</button>
            </div>
            <div className="adsModalBody">
              <div className="adsRegionPickerFilters">
                <div className="adsModalInfoCard">
                  <strong>지역단위</strong>
                  <span>{REGION_LEVEL_OPTIONS.find((option) => option.value === regionPickerModal.level)?.label ?? regionPickerModal.level}</span>
                </div>
                {(regionPickerModal.level === 'district' || regionPickerModal.level === 'neighborhood') ? (
                  <label className="field" style={{ margin: 0 }}>
                    <span className="fieldLabel">시</span>
                    <select
                      className="textInput"
                      value={regionPickerModal.city}
                      onChange={(e) => setRegionPickerModal((prev) => prev ? { ...prev, city: e.target.value, district: '' } : prev)}
                    >
                      {KOREA_CITIES.map((option) => (
                        <option key={option.key} value={option.cityName}>{option.label}</option>
                      ))}
                    </select>
                  </label>
                ) : null}
                {regionPickerModal.level === 'neighborhood' ? (
                  <label className="field" style={{ margin: 0 }}>
                    <span className="fieldLabel">구</span>
                    <select
                      className="textInput"
                      value={regionPickerModal.district}
                      onChange={(e) => setRegionPickerModal((prev) => prev ? { ...prev, district: e.target.value } : prev)}
                    >
                      <option value="">전체 구/직속동</option>
                      {(KOREA_DISTRICTS_BY_CITY[regionPickerModal.city] ?? []).map((option) => (
                        <option key={option.key} value={option.districtName ?? ''}>{option.label}</option>
                      ))}
                    </select>
                  </label>
                ) : null}
              </div>
              <div className="adsRegionPickerSelectionRow">
                <div className="adsModalInfoCard">
                  <strong>선택요약</strong>
                  <span>{regionPickerModal.workingKeys.length > 0 ? regionSummaryFromKeys(regionPickerModal.workingKeys) : '선택된 지역 없음'}</span>
                </div>
                <button className="ghostBtn ghostBtnSmall" type="button" onClick={() => setRegionPickerModal((prev) => prev ? { ...prev, workingKeys: [] } : prev)}>선택 비우기</button>
              </div>
              <div className="adsRegionPickerList">
                {regionOptionsForLevel(regionPickerModal.level, regionPickerModal.city, regionPickerModal.district).map((option) => (
                  <label key={option.key} className="adsRegionPickerOption">
                    <input
                      type="checkbox"
                      checked={regionPickerModal.workingKeys.includes(option.key)}
                      onChange={() => toggleRegionPickerKey(option.key)}
                    />
                    <span>{option.label}</span>
                    <small>{option.fullLabel}</small>
                  </label>
                ))}
                {regionOptionsForLevel(regionPickerModal.level, regionPickerModal.city, regionPickerModal.district).length === 0 ? (
                  <div className="adsRegionPickerEmpty">선택 가능한 지역이 아직 없어. 시/구 필터를 먼저 골라줘.</div>
                ) : null}
              </div>
              {regionPickerModal.workingKeys.length > 0 ? (
                <div className="adsRegionPickerChips">
                  {regionPickerModal.workingKeys.map((key) => (
                    <button key={key} type="button" className="adsRegionChip" onClick={() => toggleRegionPickerKey(key)}>
                      {KOREA_REGION_LOOKUP[key]?.fullLabel ?? key} ×
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
            <div className="adsModalFooter">
              <button className="ghostBtn ghostBtnSmall" type="button" onClick={() => setRegionPickerModal(null)}>취소</button>
              <button className="primaryBtn ghostBtnSmall" type="button" onClick={applyRegionPickerSelection}>적용</button>
            </div>
          </div>
        </div>
      ) : null}

      {bannerUploadModal ? (
        <div className="adsModalBackdrop" onClick={() => setBannerUploadModal(null)}>
          <div className="adsModalCard" onClick={(event) => event.stopPropagation()}>
            <div className="adsModalHeader">
              <div>
                <h3 className="panelTitle" style={{ marginBottom: 6 }}>배너 업로드</h3>
                <p className="pageDesc" style={{ margin: 0 }}>{slotsByKey[bannerUploadModal.slotKey]?.config.slotLabel ?? bannerUploadModal.slotKey} 슬롯에 맞는 권장 사이즈를 보고 올리는 팝업이야.</p>
              </div>
              <button className="ghostBtn ghostBtnSmall adsModalCloseBtn" type="button" onClick={() => setBannerUploadModal(null)}>닫기</button>
            </div>
            <div className="adsModalBody">
              <div className="adsModalGrid">
                <div className="adsModalInfoCard">
                  <strong>슬롯종류</strong>
                  <span>{bannerUploadModal.slotKey}</span>
                </div>
                <label className="field" style={{ margin: 0 }}>
                  <div className="exploreSheetFieldLabel">권장 사이즈</div>
                  <select
                    className="textInput exploreSheetInput"
                    value={bannerUploadModal.presetId}
                    onChange={(e) => setBannerUploadModal((prev) => prev ? { ...prev, presetId: e.target.value } : prev)}
                  >
                    {bannerPresetsForSlot(bannerUploadModal.slotKey).map((preset) => (
                      <option key={preset.id} value={preset.id}>{preset.label}</option>
                    ))}
                  </select>
                </label>
              </div>
              <div className="adsModalInfoCard">
                <strong>업로드 가이드</strong>
                <span>{bannerPresetsForSlot(bannerUploadModal.slotKey).find((preset) => preset.id === bannerUploadModal.presetId)?.note ?? '권장 사이즈를 확인하고 업로드해줘'}</span>
              </div>
              <div className="adsModalActionRow">
                <label className="ghostBtn ghostBtnSmall adsModalFileBtn">
                  파일 선택
                  <input
                    type="file"
                    accept=".png,.jpg,.jpeg,.webp,.svg,image/png,image/jpeg,image/webp,image/svg+xml"
                    className="hiddenInput"
                    onChange={(e) => setBannerUploadModal((prev) => prev ? { ...prev, file: e.target.files?.[0] ?? null } : prev)}
                  />
                </label>
                <span className="adsModalFileName">{bannerUploadModal.file?.name ?? '선택된 파일 없음'}</span>
              </div>
            </div>
            <div className="adsModalFooter">
              <button className="ghostBtn ghostBtnSmall" type="button" onClick={() => setBannerUploadModal(null)}>취소</button>
              <button className="primaryBtn ghostBtnSmall" type="button" onClick={() => void confirmBannerUpload()}>{uploadingKey === bannerUploadModal.rowId ? '업로드중' : '업로드 적용'}</button>
            </div>
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
