'use client'

import { useEffect, useMemo, useRef, useState, type WheelEvent } from 'react'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson, putJson } from '../../lib/api'
import { csvTextFromObjects, downloadCsv, readCsvObjects } from '../../lib/csv'
import { mockExploreSettings } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type ExploreStateId = 'activeShopping' | 'postSave' | 'idlePlanning' | 'storeContext'

type StoreContextPromoPreview = {
  id: string
  title: string
  body: string
  badgeLabel: string
  storeName: string
  ctaLabel: string
  placementLabel: string
  intentHint: string
  source: string
  sourceType: string
  priority: number
  isSponsored: boolean
  sponsorLabel: string
}

type EditorialRecommendationPreview = {
  id: string
  historyId?: string
  raw?: string
  title: string
  price?: number
  thumbnailUrl?: string
  url?: string
  deeplinkUrl?: string
  provider: string
  displaySlot?: number
  startsAt?: string
  endsAt?: string
  registeredAt?: string
  deletedAt?: string
  updatedAt?: string
}

type EditorialRecommendationHistoryEntry = EditorialRecommendationPreview & {
  historyId: string
}

type RecommendationDraftRow = {
  id: string
  raw: string
  parsed: EditorialRecommendationPreview | null
  displaySlot: number
  startsAt: string
  endsAt: string
}

type RecommendationSheetRecord = {
  '노출 순번': number
  'URL': string
  '등록일시': string
  '종료일시': string
  '상품명': string
  '가격': number | ''
  '썸네일 URL': string
  'Provider': string
}

type ExploreStateRuleSet = {
  revisitRecentScanLimit: number
  revisitCartItemLimit: number
  revisitMaxItems: number
  repeatMinCount: number
  repeatMaxItems: number
  offerMaxSlots: number
  storeContextMaxPromos: number
}

type ExplorePromoPolicySet = {
  allowSponsoredPromos: boolean
  maxSponsoredPromos: number
  organicFirst: boolean
}

type ExploreDecisionCopy = {
  recentScanPendingReasonLabel: string
  recentScanPendingBody: string
  recentScanInCartReasonLabel: string
  recentScanInCartBody: string
  currentCartHighImpactReasonLabel: string
  currentCartHighImpactBody: string
  currentCartDefaultReasonLabel: string
  currentCartDefaultBody: string
  offerReasonLabelActiveShopping: string
  offerReasonLabelPostSave: string
  offerReasonLabelIdlePlanning: string
  offerReasonLabelStoreContext: string
  offerBody: string
}

type ExploreDecisionPrioritySet = {
  offerPendingReview: number
  offerCurrentCart: number
  offerRepeatPurchase: number
  recentScanPending: number
  recentScanInCart: number
  currentCartHighImpact: number
  currentCartDefault: number
}

type ExploreDecisionMaxCountSet = {
  offerPendingReview: number
  offerCurrentCart: number
  offerRepeatPurchase: number
  recentScanPending: number
  recentScanInCart: number
  currentCartHighImpact: number
  currentCartDefault: number
}

type ExploreSettings = {
  enabledSections: string
  sectionOrder: string
  stateMode: 'auto' | ExploreStateId
  activeShoppingSectionOrder: string
  postSaveSectionOrder: string
  idlePlanningSectionOrder: string
  storeContextSectionOrder: string
  stateRules: Record<ExploreStateId, ExploreStateRuleSet>
  statePromoPolicies: Record<ExploreStateId, ExplorePromoPolicySet>
  decisionCopy: ExploreDecisionCopy
  stateDecisionPriorities: Record<ExploreStateId, ExploreDecisionPrioritySet>
  stateDecisionMaxCounts: Record<ExploreStateId, ExploreDecisionMaxCountSet>
  revisitRecentScanLimit: number
  revisitCartItemLimit: number
  revisitMaxItems: number
  repeatMinCount: number
  repeatMaxItems: number
  offerMaxSlots: number
  editorialRecommendationsEnabled: boolean
  naverShoppingResultsEnabled: boolean
  editorialRecommendationsTitle: string
  editorialRecommendationsSubtitle: string
  editorialRecommendationsCount: number
  editorialRecommendationsPoolRaw: string
  editorialRecommendationsDisclaimer: string
  editorialRecommendationsItems?: EditorialRecommendationPreview[]
  editorialRecommendationsHistory?: EditorialRecommendationHistoryEntry[]
  storeContextEnabled: boolean
  storeContextStoreName: string
  storeContextPromoTitle: string
  storeContextPromoBody: string
  storeContextPromoCtaLabel: string
  storeContextPromoSeedLabels: string
  storeContextPromoSourceType: 'storeSale' | 'sponsoredPlacement' | 'editorialCuration'
  storeContextPromoSponsored: boolean
  storeContextPromoSponsorLabel: string
  storeContextPromoPriorityStart: number
  storeContextMaxPromos: number
  storeContextPromos?: StoreContextPromoPreview[]
}

type AppConfigDto = {
  ok: boolean
  data: {
    copy?: {
      help?: {
        pageTitle?: string
        subtitle?: string
      }
    }
    explore?: Record<string, unknown>
    features?: {
      coupangPartnersEnabled?: boolean
      coupangPartnersAffiliateReady?: boolean
      exploreOfferBridgeEnabled?: boolean
    }
  }
}

type ExploreSectionOption = {
  id: string
  label: string
  description: string
}

type ExploreWorkspaceId = 'layout' | 'recommendations' | 'rules' | 'copy' | 'store'

type ExploreWorkspaceOption = {
  id: ExploreWorkspaceId
  label: string
  description: string
  statLabel: string
}

type ExploreStateOption = {
  id: ExploreStateId
  label: string
  description: string
}

const PREVIEW_SRC = '/app-preview/index.html?screen=help'
const DEFAULT_EDITORIAL_VISIBLE_COUNT = 5
const RECOMMENDATION_SEARCH_OPTIONS = [
  { id: 'registeredAt', label: '등록일', placeholder: 'YYYY-MM-DD' },
  { id: 'title', label: '상품명', placeholder: '상품명 검색' },
  { id: 'provider', label: '판매처', placeholder: '판매처 검색' },
] as const
const RECOMMENDATION_SHEET_COLUMNS: Array<keyof RecommendationSheetRecord> = [
  '노출 순번',
  'URL',
  '등록일시',
  '종료일시',
  '상품명',
  '가격',
  '썸네일 URL',
  'Provider',
]
const EXPLORE_STATE_OPTIONS: ExploreStateOption[] = [
  {
    id: 'activeShopping',
    label: '장보는 중',
    description: '현재 카트/최근 스캔이 있는 실행 중 상태',
  },
  {
    id: 'postSave',
    label: '방금 저장 후',
    description: '저장 직후 회고와 다음 의사결정으로 넘어가는 상태',
  },
  {
    id: 'idlePlanning',
    label: '평상시',
    description: '장보기 전 반복 구매와 지난 카트를 다시 보는 상태',
  },
  {
    id: 'storeContext',
    label: '마트 안',
    description: '특정 마트 문맥에서 행사/프로모션을 먼저 보여주는 상태',
  },
]

const EXPLORE_SECTION_OPTIONS: ExploreSectionOption[] = [
  {
    id: 'heroSummary',
    label: '맨 위 요약 카드',
    description: '현재 카트, 최근 스캔, 반복 후보를 한 번에 요약해 보여줘.',
  },
  {
    id: 'decisionInbox',
    label: '결정 인박스',
    description: '지금 다시 봐야 할 일과 홈으로 돌아가는 진입점을 보여줘.',
  },
  {
    id: 'revisitItems',
    label: '다시 볼 상품',
    description: '최근 스캔과 현재 카트 기준으로 재검토 후보를 보여줘.',
  },
  {
    id: 'repeatCandidates',
    label: '반복 구매 후보',
    description: '저장된 카트에서 자주 등장한 상품 후보를 보여줘.',
  },
  {
    id: 'editorialPicks',
    label: '운영자 추천 제품',
    description: '운영자가 넣은 쿠팡 파트너스 URL 풀에서 랜덤 추천을 보여줘.',
  },
  {
    id: 'offerSlots',
    label: '대체 상품 오퍼 슬롯',
    description: 'same-intent 대체안이나 파트너 오퍼가 붙을 자리를 보여줘.',
  },
  {
    id: 'savedContext',
    label: '지난 장보기 맥락',
    description: '최근 저장 카트와 히스토리 진입점을 아래에 붙여줘.',
  },
  {
    id: 'storeContextPromo',
    label: '마트 행사 / 오프라인 프로모션',
    description: '특정 마트 문맥이 잡혔을 때 세일과 오프라인 광고 슬롯을 보여줘.',
  },
]

const EXPLORE_WORKSPACE_OPTIONS: ExploreWorkspaceOption[] = [
  {
    id: 'layout',
    label: '섹션 배치',
    description: '상태별 섹션 노출과 순서를 다듬는 작업 레일',
    statLabel: '섹션',
  },
  {
    id: 'recommendations',
    label: '추천 풀',
    description: '운영자 추천 제품 풀과 HTML/URL 입력 결과를 관리',
    statLabel: '추천',
  },
  {
    id: 'rules',
    label: '노출 규칙',
    description: '상태별 limit, ranking, count cap을 조정',
    statLabel: '규칙',
  },
  {
    id: 'copy',
    label: '문구',
    description: '결정 인박스 라벨과 설명 문구를 관리',
    statLabel: '문구',
  },
  {
    id: 'store',
    label: '마트 문맥',
    description: '오프라인 매장 문맥과 행사/프로모션 골격',
    statLabel: '행사',
  },
]

const STATE_RULE_FIELDS: Array<{ key: keyof ExploreStateRuleSet; min: number; max: number }> = [
  { key: 'revisitRecentScanLimit', min: 0, max: 8 },
  { key: 'revisitCartItemLimit', min: 0, max: 8 },
  { key: 'revisitMaxItems', min: 0, max: 12 },
  { key: 'repeatMinCount', min: 1, max: 10 },
  { key: 'repeatMaxItems', min: 0, max: 12 },
  { key: 'offerMaxSlots', min: 0, max: 12 },
  { key: 'storeContextMaxPromos', min: 0, max: 12 },
]

const DECISION_FIELDS: Array<keyof ExploreDecisionPrioritySet> = [
  'offerPendingReview',
  'offerCurrentCart',
  'offerRepeatPurchase',
  'recentScanPending',
  'recentScanInCart',
  'currentCartHighImpact',
  'currentCartDefault',
]

const STATE_RULE_META: Record<keyof ExploreStateRuleSet, { label: string }> = {
  revisitRecentScanLimit: { label: '최근 스캔 재노출 개수' },
  revisitCartItemLimit: { label: '현재 카트 재노출 개수' },
  revisitMaxItems: { label: '다시 보기 최대 개수' },
  repeatMinCount: { label: '반복 구매 최소 빈도' },
  repeatMaxItems: { label: '반복 구매 최대 개수' },
  offerMaxSlots: { label: '대체 오퍼 최대 개수' },
  storeContextMaxPromos: { label: '마트 프로모션 최대 개수' },
}

const PROMO_POLICY_FIELDS: Array<{ key: keyof ExplorePromoPolicySet; label: string; range: string }> = [
  { key: 'allowSponsoredPromos', label: '스폰서드 프로모션 허용', range: 'bool' },
  { key: 'maxSponsoredPromos', label: '스폰서드 최대 개수', range: '0–12' },
  { key: 'organicFirst', label: '오가닉 우선 노출', range: 'bool' },
]

const DECISION_FIELD_META: Record<keyof ExploreDecisionPrioritySet, { label: string }> = {
  offerPendingReview: { label: '검토 필요 오퍼' },
  offerCurrentCart: { label: '현재 카트 연관 오퍼' },
  offerRepeatPurchase: { label: '반복 구매 연관 오퍼' },
  recentScanPending: { label: '최근 스캔 미결정' },
  recentScanInCart: { label: '최근 스캔 장바구니 포함' },
  currentCartHighImpact: { label: '현재 카트 핵심 영향 상품' },
  currentCartDefault: { label: '현재 카트 기본 제안' },
}

const DECISION_COPY_MESSAGE_FIELDS: Array<{
  id: string
  label: string
  reasonKey: keyof ExploreDecisionCopy
  bodyKey: keyof ExploreDecisionCopy
}> = [
  { id: 'recentScanPending', label: '최근 스캔 미결정', reasonKey: 'recentScanPendingReasonLabel', bodyKey: 'recentScanPendingBody' },
  { id: 'recentScanInCart', label: '최근 스캔 장바구니 포함', reasonKey: 'recentScanInCartReasonLabel', bodyKey: 'recentScanInCartBody' },
  { id: 'currentCartHighImpact', label: '현재 카트 핵심 영향', reasonKey: 'currentCartHighImpactReasonLabel', bodyKey: 'currentCartHighImpactBody' },
  { id: 'currentCartDefault', label: '현재 카트 기본 제안', reasonKey: 'currentCartDefaultReasonLabel', bodyKey: 'currentCartDefaultBody' },
]

const OFFER_REASON_LABEL_FIELDS: Record<ExploreStateId, keyof ExploreDecisionCopy> = {
  activeShopping: 'offerReasonLabelActiveShopping',
  postSave: 'offerReasonLabelPostSave',
  idlePlanning: 'offerReasonLabelIdlePlanning',
  storeContext: 'offerReasonLabelStoreContext',
}

function readExploreWorkspaceFromLocation(): ExploreWorkspaceId {
  if (typeof window === 'undefined') {
    return 'recommendations'
  }
  const value = new URLSearchParams(window.location.search).get('ws')
  return EXPLORE_WORKSPACE_OPTIONS.some((option) => option.id === value)
    ? (value as ExploreWorkspaceId)
    : 'recommendations'
}

function ensureLocationChangeEventPatched() {
  if (typeof window === 'undefined') return
  const historyState = window.history as History & {
    __cartlyLocationPatched?: boolean
    __cartlyPushState?: History['pushState']
    __cartlyReplaceState?: History['replaceState']
  }
  if (historyState.__cartlyLocationPatched) return
  historyState.__cartlyPushState = window.history.pushState.bind(window.history)
  historyState.__cartlyReplaceState = window.history.replaceState.bind(window.history)
  window.history.pushState = ((...args) => {
    const result = historyState.__cartlyPushState?.(...args)
    window.dispatchEvent(new Event('cartly:locationchange'))
    return result
  }) as History['pushState']
  window.history.replaceState = ((...args) => {
    const result = historyState.__cartlyReplaceState?.(...args)
    window.dispatchEvent(new Event('cartly:locationchange'))
    return result
  }) as History['replaceState']
  historyState.__cartlyLocationPatched = true
}

function parseSectionList(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
}

function stringifySectionList(items: string[]) {
  return items.join(',')
}

function providerLabelFromUrl(value?: string) {
  const host = (() => {
    try {
      return value ? new URL(value).hostname.toLowerCase() : ''
    } catch {
      return ''
    }
  })()

  if (!host) return '추천'
  if (host.includes('coupang') || host.includes('coupa.ng')) return '쿠팡'
  if (host.includes('11st')) return '11번가'
  if (host.includes('naver')) return '네이버'
  if (host.includes('gmarket')) return 'G마켓'
  if (host.includes('auction')) return '옥션'
  if (host.includes('ssg')) return 'SSG'
  if (host.includes('kurly')) return '컬리'
  if (host.includes('lotteon')) return '롯데온'
  if (host.includes('emart')) return '이마트'
  const parts = host.split('.')
  const label = parts.length >= 2 ? parts[parts.length - 2] ?? host : host
  return label.length <= 4 ? label.toUpperCase() : `${label.charAt(0).toUpperCase()}${label.slice(1)}`
}

function decisionReasonVocabulary(settings: ExploreSettings, state: ExploreStateId) {
  switch (state) {
    case 'activeShopping':
      return [
        settings.decisionCopy.offerReasonLabelActiveShopping,
        settings.decisionCopy.currentCartHighImpactReasonLabel,
        settings.decisionCopy.recentScanInCartReasonLabel,
      ]
    case 'postSave':
      return [
        settings.decisionCopy.offerReasonLabelPostSave,
        settings.decisionCopy.currentCartDefaultReasonLabel,
        settings.decisionCopy.recentScanInCartReasonLabel,
      ]
    case 'storeContext':
      return [
        settings.decisionCopy.offerReasonLabelStoreContext,
        settings.decisionCopy.currentCartDefaultReasonLabel,
        settings.decisionCopy.recentScanInCartReasonLabel,
      ]
    case 'idlePlanning':
    default:
      return [
        settings.decisionCopy.offerReasonLabelIdlePlanning,
        settings.decisionCopy.recentScanPendingReasonLabel,
        settings.decisionCopy.currentCartDefaultReasonLabel,
      ]
  }
}

function decisionTypeLabels(settings: ExploreSettings, state: ExploreStateId) {
  return {
    offerPendingReview: `${decisionReasonVocabulary(settings, state)[0] ?? '오퍼'} / 검토중`,
    offerCurrentCart: `${decisionReasonVocabulary(settings, state)[0] ?? '오퍼'} / 현재카트`,
    offerRepeatPurchase: `${decisionReasonVocabulary(settings, state)[0] ?? '오퍼'} / 반복구매`,
    recentScanPending: settings.decisionCopy.recentScanPendingReasonLabel,
    recentScanInCart: settings.decisionCopy.recentScanInCartReasonLabel,
    currentCartHighImpact: settings.decisionCopy.currentCartHighImpactReasonLabel,
    currentCartDefault: settings.decisionCopy.currentCartDefaultReasonLabel,
  }
}

function decisionPriorityPreview(settings: ExploreSettings, state: ExploreStateId) {
  const priorities = settings.stateDecisionPriorities[state]
  const labels = decisionTypeLabels(settings, state)
  return (Object.entries(priorities) as Array<[keyof ExploreDecisionPrioritySet, number]>)
    .sort((a, b) => b[1] - a[1])
    .map(([key, value]) => ({ key, value, label: labels[key] }))
}

function decisionMaxCountPreview(settings: ExploreSettings, state: ExploreStateId) {
  const maxCounts = settings.stateDecisionMaxCounts[state]
  const labels = decisionTypeLabels(settings, state)
  return (Object.entries(maxCounts) as Array<[keyof ExploreDecisionMaxCountSet, number]>)
    .map(([key, value]) => ({ key, value, label: labels[key] }))
}

function parseEditorialRecommendations(raw: string): EditorialRecommendationPreview[] {
  const results: EditorialRecommendationPreview[] = []
  const seen = new Set<string>()

  function parsePrice(value: string) {
    const digits = value.replace(/[^0-9]/g, '')
    if (!digits) return undefined
    const parsed = Number(digits)
    return Number.isFinite(parsed) ? parsed : undefined
  }

  function extractIframeSrc(value: string) {
    const matched = value.match(/<iframe[^>]+src=["']([^"']+)["']/i)
    return matched?.[1]?.trim() ?? ''
  }

  function extractAnchorImageMetadata(value: string) {
    const href = value.match(/<a[^>]+href=["']([^"']+)["']/i)?.[1]?.trim() ?? ''
    const src = value.match(/<img[^>]+src=["']([^"']+)["']/i)?.[1]?.trim() ?? ''
    const alt = value.match(/<img[^>]+alt=["']([^"']+)["']/i)?.[1]?.trim() ?? ''
    return { href, src, alt }
  }

  function metadataFromUrl(candidate: string) {
    try {
      const url = new URL(candidate)
      const title = url.searchParams.get('title')?.trim() || url.searchParams.get('productDescription')?.trim() || ''
      const thumbnailUrl = url.searchParams.get('productImage')?.trim() || url.searchParams.get('image')?.trim() || ''
      const deeplinkUrl =
        url.searchParams.get('link')?.trim() ||
        url.searchParams.get('linkUrl')?.trim() ||
        candidate
      return { title, thumbnailUrl, deeplinkUrl }
    } catch {
      return { title: '', thumbnailUrl: '', deeplinkUrl: candidate }
    }
  }

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue

    const iframeSrc = extractIframeSrc(trimmed)
    const anchorImage = extractAnchorImageMetadata(trimmed)
    const normalizedLine = iframeSrc || trimmed
    const parts = normalizedLine.split('|').map((item) => item.trim()).filter(Boolean)
    let title = anchorImage.alt || ''
    let url = ''
    let deeplinkUrl = /^https?:\/\//i.test(anchorImage.href) ? anchorImage.href : ''
    let thumbnailUrl = /^https?:\/\//i.test(anchorImage.src) ? anchorImage.src : ''
    let price: number | undefined

    if (deeplinkUrl) {
      url = deeplinkUrl
    } else if (parts.length === 1 && /^https?:\/\//i.test(normalizedLine)) {
      deeplinkUrl = normalizedLine
      url = normalizedLine
    } else {
      title = title || (parts[0] ?? '')
      const urlParts = parts.slice(1).filter((part) => /^https?:\/\//i.test(part))
      const nonUrlParts = parts.slice(1).filter((part) => !/^https?:\/\//i.test(part))
      for (const part of nonUrlParts) {
        if (price == null) {
          price = parsePrice(part)
        }
      }
      if (urlParts.length >= 2) {
        thumbnailUrl = urlParts[0] ?? ''
        deeplinkUrl = urlParts[urlParts.length - 1] ?? ''
        url = deeplinkUrl
      } else if (urlParts.length === 1) {
        const candidateUrl = urlParts[0] ?? ''
        const looksLikeImage = /\.(jpg|jpeg|png|webp|gif)(\?|$)/i.test(candidateUrl) || /image|thumb/i.test(candidateUrl)
        if (price != null && looksLikeImage) {
          thumbnailUrl = candidateUrl
        } else {
          deeplinkUrl = candidateUrl
          url = deeplinkUrl
        }
      }
    }

    const urlMetadata = deeplinkUrl ? metadataFromUrl(deeplinkUrl) : { title: '', thumbnailUrl: '', deeplinkUrl }
    if (!title) {
      title = urlMetadata.title
    }
    if (!thumbnailUrl) {
      thumbnailUrl = urlMetadata.thumbnailUrl
    }
    if (!deeplinkUrl && urlMetadata.deeplinkUrl) {
      deeplinkUrl = urlMetadata.deeplinkUrl
      url = deeplinkUrl
    }

    const dedupeKey = deeplinkUrl || thumbnailUrl || title
    if (!dedupeKey || seen.has(dedupeKey)) continue
    seen.add(dedupeKey)

    const index = results.length + 1
    const providerUrl = deeplinkUrl || url
    results.push({
      id: `editorial-pick-${index}`,
      title: title || `추천 상품 ${index}`,
      price,
      thumbnailUrl: thumbnailUrl || undefined,
      url: url || undefined,
      deeplinkUrl: deeplinkUrl || undefined,
      provider: providerLabelFromUrl(providerUrl),
    })
  }

  return results
}

function normalizeScheduleText(value: string) {
  const trimmed = value.trim()
  if (!trimmed) return ''
  const normalized = trimmed.replace(/\./g, '-').replace('T', ' ')
  const match = normalized.match(/^(\d{4})-(\d{2})-(\d{2})(?:\s+(\d{2}):(\d{2}))?$/)
  if (!match) return value
  const [, year, month, day, hour = '00', minute = '00'] = match
  return `${year}-${month}-${day} ${hour}:${minute}`
}

function buildRecommendationItemFromRow(row: RecommendationDraftRow, fallbackIndex: number): EditorialRecommendationPreview {
  const parsed = row.parsed
  const registeredAt = normalizeScheduleText(row.startsAt || parsed?.registeredAt || '')
  const startsAt = normalizeScheduleText(row.startsAt || parsed?.startsAt || parsed?.registeredAt || '')
  return {
    id: row.id || `editorial-pick-${fallbackIndex + 1}`,
    historyId: parsed?.historyId,
    raw: row.raw.trim(),
    title: parsed?.title ?? '',
    price: parsed?.price,
    thumbnailUrl: parsed?.thumbnailUrl ?? '',
    url: parsed?.url ?? parsed?.deeplinkUrl ?? '',
    deeplinkUrl: parsed?.deeplinkUrl ?? parsed?.url ?? '',
    provider: parsed?.provider ?? '',
    displaySlot: row.displaySlot,
    startsAt,
    endsAt: normalizeScheduleText(row.endsAt),
    registeredAt,
    deletedAt: parsed?.deletedAt ?? '',
    updatedAt: parsed?.updatedAt ?? '',
  }
}

function parseRecommendationDraftRows(
  raw: string,
  cachedItems: EditorialRecommendationPreview[] = [],
): RecommendationDraftRow[] {
  const sourceLines = raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'))
  const parsedItems = parseEditorialRecommendations(raw)
  return sourceLines.map((line, index) => {
    const id = `editorial-pick-${index + 1}`
    const cached = cachedItems[index] ?? null
    return {
      id,
      raw: line,
      parsed: cached ? { ...cached, id } : parsedItems[index] ?? null,
      displaySlot: cached?.displaySlot ?? 999,
      startsAt: normalizeScheduleText(cached?.startsAt ?? ''),
      endsAt: normalizeScheduleText(cached?.endsAt ?? ''),
    }
  })
}

function stringifyRecommendationDraftRows(rows: RecommendationDraftRow[]) {
  return rows.map((row) => row.raw.trim()).filter(Boolean).join('\n')
}

function parseRecommendationSheetText(value: unknown) {
  return typeof value === 'string' ? value.trim() : value == null ? '' : String(value).trim()
}

function parseRecommendationSheetPrice(value: unknown) {
  if (typeof value === 'number' && Number.isFinite(value)) return value
  const digits = parseRecommendationSheetText(value).replace(/[^0-9]/g, '')
  if (!digits) return undefined
  const parsed = Number(digits)
  return Number.isFinite(parsed) ? parsed : undefined
}

function buildRecommendationSheetRows(rows: RecommendationDraftRow[]): RecommendationSheetRecord[] {
  const source = rows.length > 0
    ? rows
    : [{ id: 'editorial-pick-1', raw: '', parsed: null, displaySlot: 999, startsAt: '', endsAt: '' }]
  return source.map((row) => ({
    '노출 순번': row.displaySlot,
    'URL': row.raw,
    '등록일시': normalizeScheduleText(row.startsAt || row.parsed?.registeredAt || ''),
    '종료일시': normalizeScheduleText(row.endsAt),
    '상품명': row.parsed?.title ?? '',
    '가격': row.parsed?.price ?? '',
    '썸네일 URL': row.parsed?.thumbnailUrl ?? '',
    'Provider': row.parsed?.provider ?? '',
  }))
}

function buildRecommendationRowsFromSheet(records: Record<string, unknown>[]): RecommendationDraftRow[] {
  return records
    .map<RecommendationDraftRow | null>((record, index) => {
      const raw = parseRecommendationSheetText(record['URL'] ?? record['입력값'] ?? record.raw ?? record.url)
      const explicitProvider = parseRecommendationSheetText(record.Provider ?? record.provider)
      const explicitTitle = parseRecommendationSheetText(record['상품명'] ?? record.title)
      const explicitThumbnail = parseRecommendationSheetText(record['썸네일 URL'] ?? record['썸네일'] ?? record.thumbnailUrl)
      const explicitStartsAt = normalizeScheduleText(parseRecommendationSheetText(record['등록일시'] ?? record['노출 시작'] ?? record['노출시작'] ?? record.startsAt ?? record.registeredAt))
      const explicitEndsAt = normalizeScheduleText(parseRecommendationSheetText(record['종료일시'] ?? record['노출 종료'] ?? record['노출종료'] ?? record.endsAt))
      const explicitPrice = parseRecommendationSheetPrice(record['가격'] ?? record.price)
      const parsedSlot = Number(parseRecommendationSheetText(record['노출 순번'] ?? record['노출'] ?? record.displaySlot ?? record.slot) || 999)
      const displaySlot = parsedSlot >= 1 && parsedSlot <= 10 ? parsedSlot : 999
      const fallbackParsed = raw ? parseEditorialRecommendations(raw)[0] ?? null : null
      const hasStructuredData = Boolean(
        explicitProvider
          || explicitTitle
          || explicitThumbnail
          || explicitStartsAt
          || explicitEndsAt
          || explicitPrice != null,
      )

      if (!raw && !hasStructuredData) {
        return null
      }

      const id = `editorial-pick-${index + 1}`
      const providerUrl = fallbackParsed?.deeplinkUrl || fallbackParsed?.url || raw
      const normalizedRaw = raw || explicitTitle || `imported-row-${index + 1}`
      const parsed = hasStructuredData || fallbackParsed
        ? {
          id,
          raw: normalizedRaw,
          title: explicitTitle || fallbackParsed?.title || '',
          price: explicitPrice ?? fallbackParsed?.price,
          thumbnailUrl: explicitThumbnail || fallbackParsed?.thumbnailUrl || '',
          url: fallbackParsed?.url || fallbackParsed?.deeplinkUrl || raw,
          deeplinkUrl: fallbackParsed?.deeplinkUrl || fallbackParsed?.url || raw,
          provider: explicitProvider || fallbackParsed?.provider || providerLabelFromUrl(providerUrl),
          displaySlot,
          startsAt: explicitStartsAt,
          endsAt: explicitEndsAt,
          registeredAt: explicitStartsAt,
        }
        : null

      return {
        id,
        raw: normalizedRaw,
        parsed,
        displaySlot,
        startsAt: explicitStartsAt,
        endsAt: explicitEndsAt,
      }
    })
    .filter((row): row is RecommendationDraftRow => row !== null)
}

function recommendationLifecycleState(item: {
  startsAt?: string
  endsAt?: string
  registeredAt?: string
  deletedAt?: string
}, now = new Date()) {
  if (item.deletedAt) return 'deleted' as const
  const start = parseRecommendationDateTime(item.startsAt)
  const end = parseRecommendationDateTime(item.endsAt)
  if (start && start.getTime() > now.getTime()) return 'scheduled' as const
  if (end && end.getTime() < now.getTime()) return 'ended' as const
  if (item.registeredAt) return 'active' as const
  if (item.startsAt || item.endsAt) return 'draftScheduled' as const
  return 'draft' as const
}

function recommendationDraftStatusLabel(row: RecommendationDraftRow, hasSlotConflict = false) {
  if (hasSlotConflict) return '슬롯중복'
  switch (recommendationLifecycleState({
    startsAt: row.startsAt || row.parsed?.startsAt,
    endsAt: row.endsAt || row.parsed?.endsAt,
    registeredAt: row.parsed?.registeredAt,
    deletedAt: row.parsed?.deletedAt,
  })) {
    case 'deleted':
      return '삭제'
    case 'active':
      return '운영중'
    case 'scheduled':
      return row.parsed?.registeredAt ? '등록대기' : '대기'
    case 'ended':
      return '종료'
    case 'draftScheduled':
      return '예약'
    case 'draft':
    default:
      return '초안'
  }
}

function recommendationHistoryStatusLabel(item: EditorialRecommendationHistoryEntry) {
  switch (recommendationLifecycleState(item)) {
    case 'deleted':
      return '삭제'
    case 'active':
      return '운영중'
    case 'scheduled':
      return '예정'
    case 'ended':
      return '지난 노출'
    case 'draft':
    case 'draftScheduled':
    default:
      return '등록 이력'
  }
}

function matchesRecommendationSearch(value: string | undefined, needle: string) {
  if (!needle) return true
  return (value ?? '').toLocaleLowerCase().includes(needle)
}

function parseRecommendationDateTime(value: string | undefined) {
  if (!value?.trim()) return null
  const normalized = value.includes('T') ? value : value.replace(' ', 'T')
  const parsed = new Date(normalized)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function isRecommendationActiveAt(item: {
  startsAt?: string
  endsAt?: string
  registeredAt?: string
  deletedAt?: string
}, now: Date) {
  if (item.deletedAt) return false
  const start = parseRecommendationDateTime(item.startsAt)
  const end = parseRecommendationDateTime(item.endsAt)
  if (start && start.getTime() > now.getTime()) return false
  if (end && end.getTime() < now.getTime()) return false
  if (!start && !end && !item.registeredAt) return false
  return true
}

function buildStorePromoPreview(settings: ExploreSettings): StoreContextPromoPreview[] {
  const maxPromos = settings.stateRules.storeContext.storeContextMaxPromos ?? settings.storeContextMaxPromos
  const labels = settings.storeContextPromoSeedLabels
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, maxPromos)

  if (labels.length === 0) {
    return settings.storeContextPromos ?? []
  }

  return labels.map((label, index) => ({
    id: `store-promo-${index + 1}`,
    title: `${label} 확인`,
    body: settings.storeContextPromoBody,
    badgeLabel: label,
    storeName: settings.storeContextStoreName,
    ctaLabel: settings.storeContextPromoCtaLabel,
    placementLabel: '매장 프로모션',
    intentHint: '같은 구매 의도 기준',
    source: 'store-context-preview',
    sourceType: settings.storeContextPromoSourceType,
    priority: Math.max(0, settings.storeContextPromoPriorityStart - (index * 10)),
    isSponsored: settings.storeContextPromoSponsored,
    sponsorLabel: settings.storeContextPromoSponsored ? settings.storeContextPromoSponsorLabel : '',
  }))
}

export default function ExploreAdminPage() {
  const { t } = useAdminCopy()
  const res = useAdminData<{ ok: boolean; data: ExploreSettings }>('/admin/explore', {
    ok: true,
    data: mockExploreSettings as ExploreSettings,
  })
  const appConfigRes = useAdminData<AppConfigDto>('/v1/app-config', {
    ok: true,
    data: {
      copy: {
        help: {
          pageTitle: 'Explore',
          subtitle: '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요',
        },
      },
      explore: mockExploreSettings,
      features: {
        coupangPartnersEnabled: false,
        coupangPartnersAffiliateReady: false,
        exploreOfferBridgeEnabled: false,
      },
    },
  })
  const [form, setForm] = useState<ExploreSettings>(res.data.data)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [previewScenario, setPreviewScenario] = useState<ExploreStateId>('activeShopping')
  const [layoutState, setLayoutState] = useState<ExploreStateId>('activeShopping')
  const [selectedRecommendationId, setSelectedRecommendationId] = useState<string | null>(null)
  const [selectedRecommendationRowIds, setSelectedRecommendationRowIds] = useState<string[]>([])
  const [resolvingRowId, setResolvingRowId] = useState<string | null>(null)
  const [registeringRowId, setRegisteringRowId] = useState<string | null>(null)
  const [deletingRowIds, setDeletingRowIds] = useState<string[]>([])
  const [bulkRecommendationAction, setBulkRecommendationAction] = useState<'resolve' | 'register' | 'delete' | null>(null)
  const [pendingDeleteRecommendationRowIds, setPendingDeleteRecommendationRowIds] = useState<string[] | null>(null)
  const [savingRecommendations, setSavingRecommendations] = useState(false)
  const [importingRecommendationSheet, setImportingRecommendationSheet] = useState(false)
  const [recommendationSearchField, setRecommendationSearchField] = useState<(typeof RECOMMENDATION_SEARCH_OPTIONS)[number]['id']>('registeredAt')
  const [recommendationSearchQuery, setRecommendationSearchQuery] = useState('')
  const [activeWorkspace, setActiveWorkspace] = useState<ExploreWorkspaceId>(readExploreWorkspaceFromLocation)
  const [previewNonce, setPreviewNonce] = useState(0)
  const previewPopupRef = useRef<Window | null>(null)
  const recommendationSheetInputRef = useRef<HTMLInputElement | null>(null)
  const recommendationSheetViewportRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    setForm(res.data.data)
  }, [res.data.data])

  const enabledSections = useMemo(() => parseSectionList(form.enabledSections), [form.enabledSections])

  function stateOrderKey(state: ExploreStateId) {
    switch (state) {
      case 'activeShopping':
        return 'activeShoppingSectionOrder' as const
      case 'postSave':
        return 'postSaveSectionOrder' as const
      case 'storeContext':
        return 'storeContextSectionOrder' as const
      case 'idlePlanning':
      default:
        return 'idlePlanningSectionOrder' as const
    }
  }

  const orderedSections = useMemo(() => {
    const enabled = new Set(enabledSections)
    const base = parseSectionList(form[stateOrderKey(layoutState)]).filter((item) => enabled.has(item))
    for (const option of EXPLORE_SECTION_OPTIONS) {
      if (enabled.has(option.id) && !base.includes(option.id)) {
        base.push(option.id)
      }
    }
    return base
  }, [enabledSections, form, layoutState])
  const layoutSectionRows = useMemo(() => {
    const orderMap = new Map(orderedSections.map((id, index) => [id, index]))
    return [...EXPLORE_SECTION_OPTIONS].sort((left, right) => {
      const leftIndex = orderMap.get(left.id)
      const rightIndex = orderMap.get(right.id)
      if (leftIndex != null && rightIndex != null) return leftIndex - rightIndex
      if (leftIndex != null) return -1
      if (rightIndex != null) return 1
      return EXPLORE_SECTION_OPTIONS.findIndex((item) => item.id === left.id)
        - EXPLORE_SECTION_OPTIONS.findIndex((item) => item.id === right.id)
    })
  }, [orderedSections])
  const currentStateRules = form.stateRules[layoutState]
  const currentPromoPolicy = form.statePromoPolicies[layoutState]
  const currentDecisionPriority = form.stateDecisionPriorities[layoutState]
  const currentDecisionMaxCount = form.stateDecisionMaxCounts[layoutState]
  const isDirty = JSON.stringify(form) !== JSON.stringify(res.data.data)
  const storePromoPreview = useMemo(() => buildStorePromoPreview(form), [form])
  const editorialPoolPreview = useMemo(() => {
    const hydratedItems = (form.editorialRecommendationsItems ?? []).filter((item) => {
      return Boolean(item.title?.trim() || item.deeplinkUrl?.trim() || item.thumbnailUrl?.trim())
    })
    if (hydratedItems.length > 0) {
      return hydratedItems
    }
    return parseEditorialRecommendations(form.editorialRecommendationsPoolRaw)
  }, [form.editorialRecommendationsItems, form.editorialRecommendationsPoolRaw])
  const historicalRecommendationRows = useMemo(() => {
    const activeHistoryIds = new Set(
      (form.editorialRecommendationsItems ?? [])
        .map((item) => item.historyId)
        .filter((value): value is string => Boolean(value)),
    )
    return [...(form.editorialRecommendationsHistory ?? [])]
      .filter((item) => !activeHistoryIds.has(item.historyId))
      .sort((a, b) => {
        const left = b.deletedAt || b.endsAt || b.updatedAt || b.registeredAt || ''
        const right = a.deletedAt || a.endsAt || a.updatedAt || a.registeredAt || ''
        return left.localeCompare(right)
      })
  }, [form.editorialRecommendationsHistory, form.editorialRecommendationsItems])
  const recommendationDraftRows = useMemo(
    () => parseRecommendationDraftRows(form.editorialRecommendationsPoolRaw, form.editorialRecommendationsItems ?? []),
    [form.editorialRecommendationsItems, form.editorialRecommendationsPoolRaw],
  )
  const recommendationSearchNeedle = recommendationSearchQuery.trim()
  const recommendationSearchNeedleLower = recommendationSearchNeedle.toLocaleLowerCase()
  const recommendationSearchOption = RECOMMENDATION_SEARCH_OPTIONS.find((option) => option.id === recommendationSearchField) ?? RECOMMENDATION_SEARCH_OPTIONS[0]
  const filteredRecommendationDraftRows = useMemo(() => {
    return recommendationDraftRows.filter((row) => {
      if (!recommendationSearchNeedle) return true
      const registeredAt = row.parsed?.registeredAt ?? ''
      switch (recommendationSearchField) {
        case 'registeredAt':
          return registeredAt.startsWith(recommendationSearchNeedle)
        case 'provider':
          return matchesRecommendationSearch(row.parsed?.provider, recommendationSearchNeedleLower)
        case 'title':
        default:
          return matchesRecommendationSearch(row.parsed?.title || row.raw, recommendationSearchNeedleLower)
      }
    })
  }, [recommendationDraftRows, recommendationSearchField, recommendationSearchNeedle, recommendationSearchNeedleLower])
  const filteredHistoricalRecommendationRows = useMemo(() => {
    return historicalRecommendationRows.filter((item) => {
      if (!recommendationSearchNeedle) return true
      const registeredAt = item.registeredAt ?? ''
      switch (recommendationSearchField) {
        case 'registeredAt':
          return registeredAt.startsWith(recommendationSearchNeedle)
        case 'provider':
          return matchesRecommendationSearch(item.provider, recommendationSearchNeedleLower)
        case 'title':
        default:
          return matchesRecommendationSearch(item.title || item.raw, recommendationSearchNeedleLower)
      }
    })
  }, [historicalRecommendationRows, recommendationSearchField, recommendationSearchNeedle, recommendationSearchNeedleLower])
  const selectedRecommendationRowIdSet = useMemo(() => new Set(selectedRecommendationRowIds), [selectedRecommendationRowIds])
  const visibleRecommendationRowIds = useMemo(() => filteredRecommendationDraftRows.map((row) => row.id), [filteredRecommendationDraftRows])
  const visibleSelectedRecommendationRowIds = useMemo(
    () => visibleRecommendationRowIds.filter((id) => selectedRecommendationRowIdSet.has(id)),
    [selectedRecommendationRowIdSet, visibleRecommendationRowIds],
  )
  const allVisibleRecommendationRowsSelected = visibleRecommendationRowIds.length > 0 && visibleSelectedRecommendationRowIds.length === visibleRecommendationRowIds.length
  const hasSelectedRecommendationRows = visibleSelectedRecommendationRowIds.length > 0
  const isRecommendationActionBusy = Boolean(
    bulkRecommendationAction
      || resolvingRowId
      || registeringRowId
      || deletingRowIds.length > 0
      || savingRecommendations,
  )
  const hasRecommendationSearchQuery = Boolean(recommendationSearchNeedle)

  useEffect(() => {
    const existingIds = new Set(recommendationDraftRows.map((row) => row.id))
    setSelectedRecommendationRowIds((prev) => {
      const next = prev.filter((id) => existingIds.has(id))
      return next.length === prev.length ? prev : next
    })
    setPendingDeleteRecommendationRowIds((prev) => {
      if (!prev) return null
      const next = prev.filter((id) => existingIds.has(id))
      return next.length > 0 ? next : null
    })
  }, [recommendationDraftRows])

  const recommendationDuplicateSlotIds = useMemo(() => {
    const bucket = new Map<number, string[]>()
    for (const row of recommendationDraftRows) {
      if (row.displaySlot < 1 || row.displaySlot > 10) continue
      const current = bucket.get(row.displaySlot) ?? []
      current.push(row.id)
      bucket.set(row.displaySlot, current)
    }
    const duplicates = new Set<string>()
    for (const ids of bucket.values()) {
      if (ids.length < 2) continue
      for (const id of ids) duplicates.add(id)
    }
    return duplicates
  }, [recommendationDraftRows])
  const recommendationDuplicateSlots = useMemo(() => {
    const counts = new Map<number, number>()
    for (const row of recommendationDraftRows) {
      if (row.displaySlot < 1 || row.displaySlot > 10) continue
      counts.set(row.displaySlot, (counts.get(row.displaySlot) ?? 0) + 1)
    }
    return [...counts.entries()]
      .filter(([, count]) => count > 1)
      .map(([slot]) => slot)
      .sort((a, b) => a - b)
  }, [recommendationDraftRows])
  const hasRecommendationSlotConflicts = recommendationDuplicateSlots.length > 0
  const liveTitle = appConfigRes.data.data.copy?.help?.pageTitle ?? 'Explore'
  const liveSubtitle = appConfigRes.data.data.copy?.help?.subtitle ?? '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요'
  const features = appConfigRes.data.data.features
  const activeWorkspaceOption =
    EXPLORE_WORKSPACE_OPTIONS.find((option) => option.id === activeWorkspace) ??
    EXPLORE_WORKSPACE_OPTIONS[0]
  const activeStateOption =
    EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState) ??
    EXPLORE_STATE_OPTIONS[0]
  const visibleRecommendationCount = form.editorialRecommendationsEnabled
    ? Math.min(form.editorialRecommendationsCount || DEFAULT_EDITORIAL_VISIBLE_COUNT, editorialPoolPreview.length)
    : 0
  const activeSectionLabels = orderedSections
    .map((id) => EXPLORE_SECTION_OPTIONS.find((option) => option.id === id)?.label)
    .filter((value): value is string => Boolean(value))
  const modePreviewHeadline = (() => {
    switch (layoutState) {
      case 'activeShopping':
        return '현재 카트와 최근 스캔을 먼저 끌어올리는 실행 모드'
      case 'postSave':
        return '저장 직후 회고와 다음 장보기 결정을 잇는 모드'
      case 'idlePlanning':
        return '평상시 반복 구매와 저장 카트 재진입을 여는 모드'
      case 'storeContext':
        return '마트 문맥에서 행사와 프로모션을 먼저 세우는 모드'
      default:
        return activeStateOption.description
    }
  })()
  const activeWorkspaceStat = (() => {
    switch (activeWorkspace) {
      case 'layout':
        return `${enabledSections.length} sections`
      case 'recommendations':
        return `${editorialPoolPreview.length} pool`
      case 'rules':
        return `${DECISION_FIELDS.length} priorities`
      case 'copy':
        return `${DECISION_COPY_MESSAGE_FIELDS.length + 1} copy groups`
      case 'store':
        return `${storePromoPreview.length} promos`
      default:
        return '-'
    }
  })()

  useEffect(() => {
    ensureLocationChangeEventPatched()
    const syncWorkspace = () => setActiveWorkspace(readExploreWorkspaceFromLocation())
    syncWorkspace()
    window.addEventListener('popstate', syncWorkspace)
    window.addEventListener('cartly:locationchange', syncWorkspace as EventListener)
    return () => {
      window.removeEventListener('popstate', syncWorkspace)
      window.removeEventListener('cartly:locationchange', syncWorkspace as EventListener)
    }
  }, [])

  useEffect(() => {
    if (editorialPoolPreview.length === 0) {
      setSelectedRecommendationId(null)
      return
    }
    if (!selectedRecommendationId || !editorialPoolPreview.some((item) => item.id === selectedRecommendationId)) {
      setSelectedRecommendationId(editorialPoolPreview[0]?.id ?? null)
    }
  }, [editorialPoolPreview, selectedRecommendationId])

  function update<K extends keyof ExploreSettings>(key: K, value: ExploreSettings[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  function setActiveExploreState(next: ExploreStateId) {
    setLayoutState(next)
    setPreviewScenario(next)
  }

  function recommendationRowIndex(rowId: string) {
    return recommendationDraftRows.findIndex((row) => row.id === rowId)
  }

  function updateRecommendationRow(rowId: string, nextRaw: string) {
    const nextRows = recommendationDraftRows.map((row) =>
      row.id === rowId ? { ...row, raw: nextRaw } : row,
    )
    const rowIndex = recommendationRowIndex(rowId)
    const nextItems = [...(form.editorialRecommendationsItems ?? [])]
    if (rowIndex >= 0) {
      while (nextItems.length <= rowIndex) {
        nextItems.push({ id: `editorial-pick-${nextItems.length + 1}`, title: '', provider: '', displaySlot: 999 })
      }
      nextItems[rowIndex] = {
        ...nextItems[rowIndex],
        id: rowId,
        raw: nextRaw,
        title: '',
        price: undefined,
        thumbnailUrl: '',
        url: '',
        deeplinkUrl: '',
        provider: '',
        historyId: '',
        registeredAt: '',
        deletedAt: '',
        updatedAt: '',
      }
    }
    setForm((prev) => ({
      ...prev,
      editorialRecommendationsPoolRaw: stringifyRecommendationDraftRows(nextRows),
      editorialRecommendationsItems: nextItems,
    }))
  }

  function updateRecommendationDisplaySlot(rowId: string, value: string) {
    const parsed = Number(value || 999)
    const displaySlot = parsed >= 1 && parsed <= 10 ? parsed : 999
    const nextRows = recommendationDraftRows.map((row) =>
      row.id === rowId ? { ...row, displaySlot } : row,
    )
    const rowIndex = recommendationRowIndex(rowId)
    const nextItems = [...(form.editorialRecommendationsItems ?? [])]
    while (nextItems.length <= rowIndex) {
      nextItems.push({ id: `editorial-pick-${nextItems.length + 1}`, title: '', provider: '', displaySlot: 999 })
    }
    if (rowIndex >= 0) {
      nextItems[rowIndex] = { ...nextItems[rowIndex], id: rowId, displaySlot }
    }
    setForm((prev) => ({
      ...prev,
      editorialRecommendationsPoolRaw: stringifyRecommendationDraftRows(nextRows),
      editorialRecommendationsItems: nextItems,
    }))
  }

  function updateRecommendationSchedule(rowId: string, key: 'startsAt' | 'endsAt', value: string) {
    const normalized = value
    const nextRows = recommendationDraftRows.map((row) =>
      row.id === rowId ? { ...row, [key]: normalized } : row,
    )
    const rowIndex = recommendationRowIndex(rowId)
    if (rowIndex < 0) return
    const nextItems = [...(form.editorialRecommendationsItems ?? [])]
    while (nextItems.length <= rowIndex) {
      nextItems.push({ id: `editorial-pick-${nextItems.length + 1}`, title: '', provider: '', displaySlot: 999 })
    }
    nextItems[rowIndex] = { ...nextItems[rowIndex], id: rowId, [key]: normalized }
    setForm((prev) => ({
      ...prev,
      editorialRecommendationsPoolRaw: stringifyRecommendationDraftRows(nextRows),
      editorialRecommendationsItems: nextItems,
    }))
  }

  function normalizeRecommendationSchedule(rowId: string, key: 'startsAt' | 'endsAt') {
    const row = recommendationDraftRows.find((item) => item.id === rowId)
    if (!row) return
    updateRecommendationSchedule(rowId, key, normalizeScheduleText(row[key]))
  }

  function toggleRecommendationRowSelection(rowId: string, checked: boolean) {
    setSelectedRecommendationRowIds((prev) => {
      if (checked) {
        return prev.includes(rowId) ? prev : [...prev, rowId]
      }
      return prev.filter((id) => id !== rowId)
    })
  }

  function toggleAllVisibleRecommendationRows(checked: boolean) {
    setSelectedRecommendationRowIds((prev) => {
      const visibleSet = new Set(visibleRecommendationRowIds)
      if (checked) {
        const next = [...prev]
        for (const id of visibleRecommendationRowIds) {
          if (!next.includes(id)) next.push(id)
        }
        return next
      }
      return prev.filter((id) => !visibleSet.has(id))
    })
  }

  function openRecommendationDeleteDialog(rowIds: string[]) {
    const nextIds = [...new Set(rowIds)].filter((id) => recommendationDraftRows.some((row) => row.id === id))
    if (nextIds.length === 0) {
      setMessage('삭제할 행을 먼저 선택해줘')
      return
    }
    setPendingDeleteRecommendationRowIds(nextIds)
  }

  function closeRecommendationDeleteDialog() {
    setPendingDeleteRecommendationRowIds(null)
  }

  function handleRecommendationSheetWheel(event: WheelEvent<HTMLDivElement>) {
    const viewport = recommendationSheetViewportRef.current
    if (!viewport) return
    if (viewport.scrollWidth <= viewport.clientWidth) return
    if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) return
    viewport.scrollLeft += event.deltaY
    event.preventDefault()
  }

  function applyRecommendationDraftRows(nextRows: RecommendationDraftRow[]) {
    const normalizedRows = nextRows.map((row, index) => ({
      id: `editorial-pick-${index + 1}`,
      raw: row.raw.trim(),
      parsed: row.parsed ? { ...row.parsed, id: `editorial-pick-${index + 1}` } : null,
      displaySlot: row.displaySlot >= 1 && row.displaySlot <= 10 ? row.displaySlot : 999,
      startsAt: normalizeScheduleText(row.startsAt),
      endsAt: normalizeScheduleText(row.endsAt),
    }))
    setForm((prev) => ({
      ...prev,
      editorialRecommendationsPoolRaw: stringifyRecommendationDraftRows(normalizedRows),
      editorialRecommendationsItems: normalizedRows.map((row, index) => buildRecommendationItemFromRow(row, index)),
    }))
    setSelectedRecommendationId(normalizedRows[0]?.id ?? null)
  }

  async function downloadRecommendationSheet() {
    setMessage(null)
    try {
      const csvText = csvTextFromObjects(buildRecommendationSheetRows(recommendationDraftRows), {
        headers: RECOMMENDATION_SHEET_COLUMNS,
        commentLines: [
          '필수 컬럼: 노출 순번, URL, 등록일시, 종료일시',
          '날짜 형식: YYYY-MM-DD 00:00',
          '종료일시는 빈칸 허용',
          '상품명, 가격, 썸네일 URL을 비우면 URL 기준 결과를 사용함',
        ],
      })
      downloadCsv('cartly-recommendations.csv', csvText)
      setMessage('추천 상품 CSV 다운로드 완료')
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '추천 상품 CSV 다운로드 실패')
    }
  }

  async function uploadRecommendationSheet(file: File | null) {
    if (!file) return
    setImportingRecommendationSheet(true)
    setMessage(null)
    try {
      if (!/\.csv$/i.test(file.name)) {
        throw new Error('CSV 파일만 업로드할 수 있어')
      }
      const rows = await readCsvObjects(file)
      const importedRows = buildRecommendationRowsFromSheet(rows)
      if (importedRows.length === 0) {
        throw new Error('업로드할 추천 상품 행이 없어')
      }
      applyRecommendationDraftRows(importedRows)
      setMessage(`추천 상품 CSV 업로드 완료, ${importedRows.length}개 행 반영됨`)
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '추천 상품 CSV 업로드 실패')
    } finally {
      if (recommendationSheetInputRef.current) {
        recommendationSheetInputRef.current.value = ''
      }
      setImportingRecommendationSheet(false)
    }
  }

  async function resolveRecommendationRow(rowId: string) {
    const row = recommendationDraftRows.find((item) => item.id === rowId)
    if (!row) return
    setResolvingRowId(rowId)
    setMessage(null)
    try {
      const response = await postJson<{ ok: boolean; data: EditorialRecommendationPreview }>('/admin/explore/resolve-item', {
        id: row.id,
        historyId: row.parsed?.historyId,
        raw: row.raw,
        displaySlot: row.displaySlot,
        startsAt: normalizeScheduleText(row.startsAt),
        endsAt: normalizeScheduleText(row.endsAt),
      })
      const resolved = response.data
      const rowIndex = recommendationRowIndex(rowId)
      const nextItems = [...(form.editorialRecommendationsItems ?? [])]
      while (nextItems.length <= rowIndex) {
        nextItems.push({ id: `editorial-pick-${nextItems.length + 1}`, title: '', provider: '', displaySlot: 999 })
      }
      if (rowIndex >= 0) {
        nextItems[rowIndex] = { ...resolved, raw: row.raw, displaySlot: row.displaySlot }
      }
      setForm((prev) => ({ ...prev, editorialRecommendationsItems: nextItems }))
      setSelectedRecommendationId(rowId)
      return { ...resolved, raw: row.raw, displaySlot: row.displaySlot }
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '추천 행 확인에 실패했어')
      return null
    } finally {
      setResolvingRowId(null)
    }
  }

  function buildRecommendationSectionPatch(rows: RecommendationDraftRow[], items: EditorialRecommendationPreview[]) {
    return {
      editorialRecommendationsEnabled: form.editorialRecommendationsEnabled,
      naverShoppingResultsEnabled: form.naverShoppingResultsEnabled,
      editorialRecommendationsTitle: form.editorialRecommendationsTitle,
      editorialRecommendationsSubtitle: form.editorialRecommendationsSubtitle,
      editorialRecommendationsCount: form.editorialRecommendationsCount,
      editorialRecommendationsPoolRaw: stringifyRecommendationDraftRows(rows),
      editorialRecommendationsDisclaimer: form.editorialRecommendationsDisclaimer,
      editorialRecommendationsItems: items.map((item, index) => ({
        ...item,
        id: item.id || `editorial-pick-${index + 1}` ,
      })),
    }
  }

  async function saveRecommendationSection() {
    if (hasRecommendationSlotConflicts) {
      setMessage(`고정 슬롯 중복부터 정리해줘. 충돌 슬롯: ${recommendationDuplicateSlots.join(', ')}`)
      return
    }
    setSavingRecommendations(true)
    setMessage(null)
    try {
      const payload = {
        ...res.data.data,
        ...buildRecommendationSectionPatch(
          recommendationDraftRows,
          recommendationDraftRows.map((row, index) => buildRecommendationItemFromRow(row, index)),
        ),
      }
      await putJson<{ ok: boolean; data: ExploreSettings }>('/admin/explore', payload)
      setMessage('추천 상품 섹션 저장 완료')
      await Promise.allSettled([res.reload(), appConfigRes.reload()])
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '추천 상품 섹션 저장 실패')
    } finally {
      setSavingRecommendations(false)
    }
  }

  async function registerRecommendationRow(rowId: string) {
    const rowIndex = recommendationRowIndex(rowId)
    if (rowIndex < 0) return false
    const row = recommendationDraftRows[rowIndex]
    if (recommendationDuplicateSlotIds.has(rowId)) {
      setMessage(`고정 슬롯 ${row.displaySlot} 중복을 먼저 정리해줘`)
      return false
    }
    setRegisteringRowId(rowId)
    setMessage(null)
    try {
      const registeredAtDraft = normalizeScheduleText(row.startsAt) || normalizeScheduleText(row.parsed?.registeredAt ?? '')
      const endsAtDraft = normalizeScheduleText(row.endsAt)
      const resolvedBase = row.parsed?.title?.trim() ? buildRecommendationItemFromRow(row, rowIndex) : await resolveRecommendationRow(rowId)
      if (!resolvedBase) return false
      const resolved = {
        ...resolvedBase,
        registeredAt: registeredAtDraft || resolvedBase.registeredAt || '',
        startsAt: registeredAtDraft || resolvedBase.startsAt || resolvedBase.registeredAt || '',
        endsAt: endsAtDraft,
      }
      const baseRows = parseRecommendationDraftRows(
        res.data.data.editorialRecommendationsPoolRaw,
        res.data.data.editorialRecommendationsItems ?? [],
      )
      while (baseRows.length <= rowIndex) {
        baseRows.push({
          id: `editorial-pick-${baseRows.length + 1}`,
          raw: 'https://',
          parsed: null,
          displaySlot: 999,
          startsAt: '',
          endsAt: '',
        })
      }
      baseRows[rowIndex] = {
        id: `editorial-pick-${rowIndex + 1}`,
        raw: row.raw,
        parsed: resolved,
        displaySlot: row.displaySlot,
        startsAt: registeredAtDraft || normalizeScheduleText(row.startsAt),
        endsAt: endsAtDraft,
      }
      const payload = {
        ...res.data.data,
        ...buildRecommendationSectionPatch(
          baseRows,
          baseRows.map((entry, index) => buildRecommendationItemFromRow(entry, index)),
        ),
      }
      await putJson<{ ok: boolean; data: ExploreSettings }>('/admin/explore', payload)
      setMessage('추천 상품 행 등록 완료')
      await Promise.allSettled([res.reload(), appConfigRes.reload()])
      return true
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '추천 상품 행 등록 실패')
      return false
    } finally {
      setRegisteringRowId(null)
    }
  }

  function appendRecommendationRow() {
    const nextRows = [...recommendationDraftRows, { id: `draft-${Date.now()}`, raw: 'https://', parsed: null, displaySlot: 999, startsAt: '', endsAt: '' }]
    update('editorialRecommendationsPoolRaw', stringifyRecommendationDraftRows(nextRows))
  }

  async function deleteRecommendationRows(rowIds: string[]) {
    const targetIds = [...new Set(rowIds)].filter((id) => recommendationDraftRows.some((row) => row.id === id))
    if (targetIds.length === 0) {
      setMessage('삭제할 행을 먼저 선택해줘')
      return false
    }

    const savedRows = parseRecommendationDraftRows(
      res.data.data.editorialRecommendationsPoolRaw,
      res.data.data.editorialRecommendationsItems ?? [],
    )
    const savedRowCount = savedRows.length
    const targetIdSet = new Set(targetIds)
    const selectedIndexes = targetIds
      .map((id) => recommendationRowIndex(id))
      .filter((index) => index >= 0)
    const hasPersistedRow = selectedIndexes.some((index) => index < savedRowCount)
    const nextRows = recommendationDraftRows.filter((row) => !targetIdSet.has(row.id))

    setDeletingRowIds(targetIds)
    setMessage(null)
    try {
      setSelectedRecommendationRowIds((prev) => prev.filter((id) => !targetIdSet.has(id)))
      if (selectedRecommendationId && targetIdSet.has(selectedRecommendationId)) {
        setSelectedRecommendationId(nextRows[0]?.id ?? null)
      }

      if (!hasPersistedRow) {
        setForm((prev) => ({
          ...prev,
          editorialRecommendationsPoolRaw: stringifyRecommendationDraftRows(nextRows),
          editorialRecommendationsItems: nextRows.map((row, index) => buildRecommendationItemFromRow(row, index)),
        }))
        setMessage(targetIds.length === 1 ? '저장 전 행 제거 완료' : `선택 ${targetIds.length}개 행 제거 완료`)
        return true
      }

      const payload = {
        ...res.data.data,
        ...buildRecommendationSectionPatch(
          nextRows,
          nextRows.map((entry, index) => buildRecommendationItemFromRow(entry, index)),
        ),
      }
      await putJson<{ ok: boolean; data: ExploreSettings }>('/admin/explore', payload)
      setMessage(targetIds.length === 1 ? '추천 상품 행 삭제 완료' : `선택 ${targetIds.length}개 행 삭제 완료`)
      await Promise.allSettled([res.reload(), appConfigRes.reload()])
      return true
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '추천 상품 행 삭제 실패')
      return false
    } finally {
      setDeletingRowIds([])
      setPendingDeleteRecommendationRowIds(null)
    }
  }

  async function bulkResolveRecommendationRows() {
    if (!hasSelectedRecommendationRows) {
      setMessage('선택한 행이 없어')
      return
    }
    setBulkRecommendationAction('resolve')
    setMessage(null)
    try {
      let successCount = 0
      for (const rowId of visibleSelectedRecommendationRowIds) {
        const resolved = await resolveRecommendationRow(rowId)
        if (resolved) successCount += 1
      }
      setMessage(successCount === visibleSelectedRecommendationRowIds.length ? `선택 ${successCount}개 행 확인 완료` : `선택 ${successCount}/${visibleSelectedRecommendationRowIds.length}개 행 확인 완료`)
    } finally {
      setBulkRecommendationAction(null)
    }
  }

  async function bulkRegisterRecommendationRows() {
    if (!hasSelectedRecommendationRows) {
      setMessage('선택한 행이 없어')
      return
    }
    setBulkRecommendationAction('register')
    setMessage(null)
    try {
      let successCount = 0
      for (const rowId of visibleSelectedRecommendationRowIds) {
        const registered = await registerRecommendationRow(rowId)
        if (registered) successCount += 1
      }
      setMessage(successCount === visibleSelectedRecommendationRowIds.length ? `선택 ${successCount}개 행 등록 완료` : `선택 ${successCount}/${visibleSelectedRecommendationRowIds.length}개 행 등록 완료`)
    } finally {
      setBulkRecommendationAction(null)
    }
  }

  async function confirmDeleteRecommendationRows() {
    if (!pendingDeleteRecommendationRowIds || pendingDeleteRecommendationRowIds.length === 0) return
    setBulkRecommendationAction('delete')
    await deleteRecommendationRows(pendingDeleteRecommendationRowIds)
    setBulkRecommendationAction(null)
  }

  function updateStateRule<K extends keyof ExploreStateRuleSet>(key: K, value: ExploreStateRuleSet[K]) {
    setForm((prev) => ({
      ...prev,
      stateRules: {
        ...prev.stateRules,
        [layoutState]: {
          ...prev.stateRules[layoutState],
          [key]: value,
        },
      },
    }))
  }

  function updatePromoPolicy<K extends keyof ExplorePromoPolicySet>(key: K, value: ExplorePromoPolicySet[K]) {
    setForm((prev) => ({
      ...prev,
      statePromoPolicies: {
        ...prev.statePromoPolicies,
        [layoutState]: {
          ...prev.statePromoPolicies[layoutState],
          [key]: value,
        },
      },
    }))
  }

  function updateDecisionCopy<K extends keyof ExploreDecisionCopy>(key: K, value: ExploreDecisionCopy[K]) {
    setForm((prev) => ({
      ...prev,
      decisionCopy: {
        ...prev.decisionCopy,
        [key]: value,
      },
    }))
  }

  function updateDecisionPriority<K extends keyof ExploreDecisionPrioritySet>(key: K, value: ExploreDecisionPrioritySet[K]) {
    setForm((prev) => ({
      ...prev,
      stateDecisionPriorities: {
        ...prev.stateDecisionPriorities,
        [layoutState]: {
          ...prev.stateDecisionPriorities[layoutState],
          [key]: value,
        },
      },
    }))
  }

  function updateDecisionMaxCount<K extends keyof ExploreDecisionMaxCountSet>(key: K, value: ExploreDecisionMaxCountSet[K]) {
    setForm((prev) => ({
      ...prev,
      stateDecisionMaxCounts: {
        ...prev.stateDecisionMaxCounts,
        [layoutState]: {
          ...prev.stateDecisionMaxCounts[layoutState],
          [key]: value,
        },
      },
    }))
  }

  function updateSectionConfig(nextEnabled: string[], nextOrder: string[]) {
    setForm((prev) => ({
      ...prev,
      enabledSections: stringifySectionList(nextEnabled),
      sectionOrder: stringifySectionList(nextOrder),
      [stateOrderKey(layoutState)]: stringifySectionList(nextOrder),
    }))
  }

  function toggleSection(sectionId: string) {
    const enabled = new Set(enabledSections)
    const nextOrder = [...orderedSections]
    if (enabled.has(sectionId)) {
      enabled.delete(sectionId)
      const cleanedOrder = nextOrder.filter((id) => id !== sectionId)
      setForm((prev) => {
        const next = {
          ...prev,
          enabledSections: stringifySectionList(
            EXPLORE_SECTION_OPTIONS.map((option) => option.id).filter((id) => enabled.has(id)),
          ),
        }
        for (const state of EXPLORE_STATE_OPTIONS) {
          const key = stateOrderKey(state.id)
          next[key] = stringifySectionList(parseSectionList(prev[key]).filter((id) => id !== sectionId))
        }
        next.sectionOrder = stringifySectionList(cleanedOrder)
        return next
      })
      return
    }

    enabled.add(sectionId)
    if (!nextOrder.includes(sectionId)) {
      nextOrder.push(sectionId)
    }
    updateSectionConfig(
      EXPLORE_SECTION_OPTIONS.map((option) => option.id).filter((id) => enabled.has(id)),
      nextOrder,
    )
  }

  function moveSection(sectionId: string, direction: -1 | 1) {
    const index = orderedSections.indexOf(sectionId)
    const nextIndex = index + direction
    if (index < 0 || nextIndex < 0 || nextIndex >= orderedSections.length) return
    const nextOrder = [...orderedSections]
    const [item] = nextOrder.splice(index, 1)
    nextOrder.splice(nextIndex, 0, item)
    updateSectionConfig(enabledSections, nextOrder)
  }

  function previewPayload() {
    return {
      helpPageTitle: liveTitle,
      helpSubtitle: liveSubtitle,
      __previewScreen: 'help',
      __previewExploreState: previewScenario,
      __previewMemberMode: previewScenario !== 'activeShopping',
      __previewExploreConfig: {
        ...form,
        storeContextPromos: storePromoPreview,
      },
    }
  }

  function postPreviewPayload() {
    previewPopupRef.current?.postMessage(
      {
        type: 'branding-preview',
        payload: previewPayload(),
      },
      '*',
    )
  }

  function openPreviewPopup() {
    const existing = previewPopupRef.current
    if (existing && !existing.closed) {
      existing.focus()
      postPreviewPayload()
      return
    }
    const next = window.open(PREVIEW_SRC, 'cartly-explore-preview', 'popup=yes,width=480,height=920,resizable=yes,scrollbars=yes')
    if (!next) {
      setMessage('브라우저가 preview popup을 막았어. 팝업 허용 후 다시 눌러줘.')
      return
    }
    previewPopupRef.current = next
    next.focus()
    window.setTimeout(() => {
      postPreviewPayload()
    }, 500)
  }

  useEffect(() => {
    postPreviewPayload()
  }, [form, liveTitle, liveSubtitle, previewNonce, previewScenario])

  async function onSave() {
    if (res.usingFallback) {
      setMessage('fallback 상태에서는 Explore 설정 저장을 막아둘게')
      return
    }
    setSaving(true)
    setMessage(null)
    try {
      await putJson<{ ok: boolean; data: ExploreSettings }>('/admin/explore', form)
      setMessage('Explore 운영 설정 저장 완료')
      await Promise.allSettled([res.reload(), appConfigRes.reload()])
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Explore 운영 설정 저장 실패')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={res.usingFallback ? '대체 데이터' : res.loading ? '불러오는 중' : '실데이터'}
        title={t('admin.explore.title', 'Explore')}
        description={`${activeStateOption.label} · ${activeWorkspaceOption.description}`}
        actions={(
          <div className="exploreHeaderActionStrip">
            <div className="exploreHeaderActionGroup exploreHeaderActionGroupPreview">
              <div className="exploreHeaderActionRow">
                <button className="primaryBtn pageActionBtn pageActionBtnPrimary exploreHeaderActionBtn" type="button" onClick={openPreviewPopup}>
                  미리보기
                </button>
                <button
                  className="ghostBtn pageActionBtn exploreHeaderIconBtn"
                  type="button"
                  onClick={() => setPreviewNonce((value) => value + 1)}
                  aria-label="미리보기 다시 보내기"
                  title="미리보기 다시 보내기"
                >
                  ↻
                </button>
              </div>
              <div className="exploreHeaderMiniField">
                <span>미리보기 기준</span>
                <strong style={{ fontSize: 11, color: '#111827' }}>{activeStateOption.label}</strong>
              </div>
            </div>
            <span className="exploreHeaderActionDivider" aria-hidden="true" />
            <div className="exploreHeaderActionGroup">
              <button className="primaryBtn pageActionBtn pageActionBtnPrimary exploreHeaderActionBtn" type="button" onClick={() => void onSave()} disabled={saving}>
                {saving ? '저장 중...' : '저장'}
              </button>
              <button
                className="ghostBtn pageActionBtn exploreHeaderIconBtn"
                type="button"
                onClick={() => setForm(res.data.data)}
                disabled={saving || !isDirty}
                aria-label="저장 되돌리기"
                title="저장 되돌리기"
              >
                ↻
              </button>
            </div>
            <span className="exploreHeaderActionDivider" aria-hidden="true" />
            <div className="exploreHeaderActionGroup">
              <button
                className="ghostBtn pageActionBtn exploreHeaderActionBtn"
                type="button"
                onClick={() => void Promise.allSettled([res.reload(), appConfigRes.reload()])}
                disabled={res.loading || appConfigRes.loading || saving}
              >
                {res.loading || appConfigRes.loading || saving ? '불러오는 중...' : '다시 불러오기'}
              </button>
            </div>
          </div>
        )}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {message ? <div className="saveMessage" style={{ marginBottom: 16 }}>{message}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>실데이터 탐색 설정 불러오기 실패</strong> 지금 화면은 대체 데이터일 수 있어.
        </div>
      ) : null}

      <div className="exploreSummaryGrid" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <span className="exploreSummaryLabel">현재 상태</span>
          <strong className="exploreSummaryValue">{activeStateOption.label}</strong>
          <span className="exploreSummaryNote">{modePreviewHeadline}</span>
        </div>
        <div className="exploreSummaryCell">
          <span className="exploreSummaryLabel">작업 화면</span>
          <strong className="exploreSummaryValue">{activeWorkspaceOption.label}</strong>
          <span className="exploreSummaryNote">{activeWorkspaceStat} · {activeWorkspaceOption.description}</span>
        </div>
        <div className="exploreSummaryCell">
          <span className="exploreSummaryLabel">노출 섹션</span>
          <strong className="exploreSummaryValue">{enabledSections.length}</strong>
          <span className="exploreSummaryNote">{activeSectionLabels.slice(0, 3).join(' · ') || '-'}</span>
        </div>
        <div className="exploreSummaryCell">
          <span className="exploreSummaryLabel">대안 / 추천</span>
          <strong className="exploreSummaryValue">{currentStateRules.offerMaxSlots} / {form.editorialRecommendationsEnabled ? `${visibleRecommendationCount} / ${editorialPoolPreview.length}` : '중지'}</strong>
          <span className="exploreSummaryNote">{features?.coupangPartnersAffiliateReady ? '제휴 준비 완료' : '검색 운영 모드'}</span>
        </div>
        <div className="exploreSummaryCell">
          <span className="exploreSummaryLabel">마트 행사</span>
          <strong className="exploreSummaryValue">{form.storeContextEnabled ? '사용' : '중지'}</strong>
          <span className="exploreSummaryNote">{form.storeContextStoreName} · {storePromoPreview.length}개 미리보기</span>
        </div>
      </div>

      <div className="metaRow compactMetaRow section" style={{ marginTop: 8 }}>
        <span className="metaPill">상태 {activeStateOption.label}</span>
        <span className="metaPill">화면 {activeWorkspaceOption.label}</span>
        <span className="metaPill">상태 선택 {form.stateMode === 'auto' ? '자동' : `고정 ${form.stateMode}`}</span>
        <span className="metaPill">{isDirty ? '미저장 변경' : '저장 완료'}</span>
        <span className="metaPill">{res.usingFallback ? '대체 데이터' : '실데이터'}</span>
      </div>

      <div className="card exploreDenseCard exploreSheetCard" style={{ marginTop: 12, marginBottom: 12 }}>
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>편집 상태</h2>
            <p className="pageDesc" style={{ margin: 0 }}>좌측 메뉴에서 작업을 바꾸고, 여기서는 편집 상태만 고른다.</p>
          </div>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">현재 작업 {activeWorkspaceOption.label}</span>
            <span className="metaPill">미리보기는 상단 버튼에서 실행</span>
          </div>
        </div>
        <div className="editorSubtabRow">
          {EXPLORE_STATE_OPTIONS.map((state) => (
            <button
              key={state.id}
              className={`editorSubtab${layoutState === state.id ? ' active' : ''}`}
              type="button"
              onClick={() => setActiveExploreState(state.id)}
            >
              {state.label}
            </button>
          ))}
        </div>
      </div>

      <div>
          <div className="card" style={{ marginBottom: activeWorkspace === 'layout' ? 16 : 0, display: activeWorkspace === 'layout' ? 'block' : 'none' }}>
            <div className="sectionHeader" style={{ marginBottom: 10 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 0 }}>섹션 배치</h2>
              </div>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">상태 {activeStateOption.label}</span>
                <span className="metaPill">좌측 메뉴 기준 편집</span>
              </div>
            </div>
            <div className="tableWrap">
              <table className="dataTable exploreDenseTable">
                <thead>
                  <tr>
                    <th>사용</th>
                    <th>섹션</th>
                    <th>키</th>
                    <th>순서</th>
                    <th>조작</th>
                  </tr>
                </thead>
                <tbody>
                  {layoutSectionRows.map((section) => {
                    const enabled = enabledSections.includes(section.id)
                    const orderIndex = orderedSections.indexOf(section.id)
                    return (
                      <tr key={section.id} className={enabled ? '' : 'exploreRowMuted'}>
                        <td data-label="사용">
                          <input type="checkbox" checked={enabled} onChange={() => toggleSection(section.id)} />
                        </td>
                        <td data-label="섹션">
                          <div style={{ fontWeight: 800, color: '#0f172a' }}>{section.label}</div>
                        </td>
                        <td data-label="키"><code>{section.id}</code></td>
                        <td data-label="순서">{enabled ? `${orderIndex + 1}번째` : '숨김'}</td>
                        <td data-label="조작">
                          <div className="exploreRowActions">
                            <button className="ghostBtnSmall" type="button" onClick={() => moveSection(section.id, -1)} disabled={!enabled || orderIndex <= 0}>
                              위로
                            </button>
                            <button className="ghostBtnSmall" type="button" onClick={() => moveSection(section.id, 1)} disabled={!enabled || orderIndex < 0 || orderIndex >= orderedSections.length - 1}>
                              아래로
                            </button>
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <details className="exploreLayoutAdvanced" style={{ marginTop: 12 }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600, color: '#334155' }}>고급 설정</summary>
              <div className="sectionGrid" style={{ gridTemplateColumns: '1fr 1fr', marginTop: 12 }}>
                <label className="field">
                  <div className="fieldLabel">{stateOrderKey(layoutState)}</div>
                  <input className="textInput" value={form[stateOrderKey(layoutState)]} onChange={(e) => update(stateOrderKey(layoutState), e.target.value)} />
                </label>
                <label className="field">
                  <div className="fieldLabel">상태 선택</div>
                  <select className="textInput" value={form.stateMode} onChange={(e) => update('stateMode', e.target.value as ExploreSettings['stateMode'])}>
                    <option value="auto">자동</option>
                    {EXPLORE_STATE_OPTIONS.map((state) => <option key={state.id} value={state.id}>{state.id}</option>)}
                  </select>
                </label>
              </div>
            </details>
          </div>

          <div className="card exploreDenseCard exploreSheetCard" style={{ marginBottom: activeWorkspace === 'recommendations' ? 16 : 0, display: activeWorkspace === 'recommendations' ? 'block' : 'none' }}>
            <div className="sectionHeader exploreDenseHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
              <div className="exploreSheetHeaderMain">
                <h2 className="panelTitle" style={{ marginBottom: 0 }}>추천 제품</h2>
                <label className="exploreSheetInlineCheck">
                  <input type="checkbox" checked={form.editorialRecommendationsEnabled} onChange={(e) => update('editorialRecommendationsEnabled', e.target.checked)} />
                  <span>추천 풀 활성화</span>
                </label>
                <label className="exploreSheetInlineCheck">
                  <input type="checkbox" checked={form.naverShoppingResultsEnabled} onChange={(e) => update('naverShoppingResultsEnabled', e.target.checked)} />
                  <span>네이버 결과 사용</span>
                </label>
                <label className="exploreSheetInlineField exploreSheetInlineFieldCount">
                  <span>노출 개수</span>
                  <input className="textInput exploreSheetInput" type="number" min={1} max={50} value={form.editorialRecommendationsCount} onChange={(e) => update('editorialRecommendationsCount', Number(e.target.value || DEFAULT_EDITORIAL_VISIBLE_COUNT))} />
                </label>
                <label className="exploreSheetInlineField exploreSheetInlineFieldTitle">
                  <span>섹션 제목</span>
                  <input className="textInput exploreSheetInput" value={form.editorialRecommendationsTitle} onChange={(e) => update('editorialRecommendationsTitle', e.target.value)} />
                </label>
                <label className="exploreSheetInlineField exploreSheetInlineFieldSubtitle">
                  <span>섹션 설명</span>
                  <input className="textInput exploreSheetInput" value={form.editorialRecommendationsSubtitle} onChange={(e) => update('editorialRecommendationsSubtitle', e.target.value)} />
                </label>
              </div>
              <div className="exploreSheetHeaderActions">
                <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => void downloadRecommendationSheet()}>
                  양식 다운로드
                </button>
                <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => recommendationSheetInputRef.current?.click()} disabled={importingRecommendationSheet}>
                  {importingRecommendationSheet ? 'CSV 업로드중' : 'CSV 업로드'}
                </button>
                <input
                  ref={recommendationSheetInputRef}
                  className="hiddenInput"
                  type="file"
                  accept=".csv,text/csv"
                  onChange={(event) => void uploadRecommendationSheet(event.currentTarget.files?.[0] ?? null)}
                />
                <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => void bulkResolveRecommendationRows()} disabled={!hasSelectedRecommendationRows || isRecommendationActionBusy}>
                  {bulkRecommendationAction === 'resolve' ? '일괄 확인중' : '일괄 확인'}
                </button>
                <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => void bulkRegisterRecommendationRows()} disabled={!hasSelectedRecommendationRows || isRecommendationActionBusy || hasRecommendationSlotConflicts}>
                  {bulkRecommendationAction === 'register' ? '일괄 등록중' : '일괄 등록'}
                </button>
                <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => openRecommendationDeleteDialog(visibleSelectedRecommendationRowIds)} disabled={!hasSelectedRecommendationRows || isRecommendationActionBusy}>
                  {bulkRecommendationAction === 'delete' ? '일괄 삭제중' : '일괄 삭제'}
                </button>
                <button className="primaryBtn exploreCompactBtn" type="button" onClick={() => void saveRecommendationSection()} disabled={savingRecommendations || hasRecommendationSlotConflicts || isRecommendationActionBusy}>
                  {savingRecommendations ? '저장 중...' : '저장'}
                </button>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 10 }}>
              <span className="metaPill">표시 {filteredRecommendationDraftRows.length + filteredHistoricalRecommendationRows.length}행</span>
              <span className="metaPill">이력 {historicalRecommendationRows.length}개</span>
              <span className="metaPill">선택 {visibleSelectedRecommendationRowIds.length}개</span>
              {hasRecommendationSlotConflicts ? <span className="metaPill exploreMetaPillWarn">slot {recommendationDuplicateSlots.join(', ')} 중복</span> : null}
            </div>
            <div className="sectionGrid exploreSheetFilterGrid" style={{ marginBottom: 10 }}>
              <label className="field">
                <div className="fieldLabel exploreSheetFieldLabel">검색 기준</div>
                <select
                  className="textInput exploreSheetInput"
                  value={recommendationSearchField}
                  onChange={(e) => {
                    const nextField = e.target.value as (typeof RECOMMENDATION_SEARCH_OPTIONS)[number]['id']
                    setRecommendationSearchField(nextField)
                  }}
                >
                  {RECOMMENDATION_SEARCH_OPTIONS.map((option) => (
                    <option key={option.id} value={option.id}>{option.label}</option>
                  ))}
                </select>
              </label>
              <label className="field">
                <div className="fieldLabel exploreSheetFieldLabel">검색어</div>
                <input
                  className="textInput exploreSheetInput"
                  type="text"
                  value={recommendationSearchQuery}
                  onChange={(e) => setRecommendationSearchQuery(e.target.value)}
                  placeholder={recommendationSearchOption.placeholder}
                />
              </label>
            </div>
            <div
              ref={recommendationSheetViewportRef}
              className="exploreSheetViewport"
              style={{ marginBottom: 6 }}
              onWheel={handleRecommendationSheetWheel}
            >
              <div className="exploreSheetCanvas">
                <table className="exploreSpreadsheetTable exploreSimpleSheet">
                <colgroup>
                  <col style={{ width: 36 }} />
                  <col style={{ width: 76 }} />
                  <col style={{ width: 112 }} />
                  <col style={{ width: 64 }} />
                  <col style={{ width: 220 }} />
                  <col style={{ width: 88 }} />
                  <col style={{ width: 360 }} />
                  <col style={{ width: 88 }} />
                  <col style={{ width: 56 }} />
                  <col style={{ width: 64 }} />
                  <col style={{ width: 124 }} />
                  <col style={{ width: 124 }} />
                  <col style={{ width: 60 }} />
                  <col style={{ width: 60 }} />
                  <col style={{ width: 60 }} />
                </colgroup>
                <thead>
                  <tr>
                    <th>
                      <input
                        type="checkbox"
                        checked={allVisibleRecommendationRowsSelected}
                        onChange={(e) => toggleAllVisibleRecommendationRows(e.target.checked)}
                        disabled={visibleRecommendationRowIds.length === 0 || isRecommendationActionBusy}
                        aria-label="현재 보이는 추천 행 전체 선택"
                      />
                    </th>
                    <th>상태</th>
                    <th>등록일</th>
                    <th>노출</th>
                    <th>입력값</th>
                    <th>판매처</th>
                    <th>상품명</th>
                    <th>가격</th>
                    <th>썸네일</th>
                    <th>링크</th>
                    <th>등록일시</th>
                    <th>종료일시</th>
                    <th>확인</th>
                    <th>등록</th>
                    <th>삭제</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRecommendationDraftRows.length > 0 || filteredHistoricalRecommendationRows.length > 0 ? (
                    <>
                      {filteredRecommendationDraftRows.map((row) => {
                        const parsed = row.parsed
                        const selected = selectedRecommendationId === row.id
                        const checked = selectedRecommendationRowIdSet.has(row.id)
                        const isDeleting = deletingRowIds.includes(row.id)
                        const hasSlotConflict = recommendationDuplicateSlotIds.has(row.id)
                        return (
                          <tr key={row.id} className={`${selected ? 'exploreRowSelected ' : ''}${hasSlotConflict ? 'exploreRowConflict' : ''}`.trim()}>
                            <td data-label="선택">
                              <input
                                type="checkbox"
                                checked={checked}
                                onChange={(e) => toggleRecommendationRowSelection(row.id, e.target.checked)}
                                disabled={isRecommendationActionBusy}
                                aria-label={`${row.id} 선택`}
                              />
                            </td>
                            <td data-label="상태">{recommendationDraftStatusLabel(row, hasSlotConflict)}</td>
                            <td data-label="등록일">{row.parsed?.registeredAt || '-'}</td>
                            <td data-label="노출">
                              <div className="exploreSlotCell">
                                <input
                                  className="textInput exploreMatrixInput"
                                  type="number"
                                  min={1}
                                  max={999}
                                  value={row.displaySlot}
                                  onChange={(e) => updateRecommendationDisplaySlot(row.id, e.target.value)}
                                />
                                {hasSlotConflict ? <span className="exploreSlotConflictTag">중복</span> : null}
                              </div>
                            </td>
                            <td data-label="입력값">
                              <input
                                className="textInput exploreSpreadsheetInput"
                                value={row.raw}
                                onChange={(e) => updateRecommendationRow(row.id, e.target.value)}
                                placeholder="URL 또는 iframe / HTML"
                              />
                            </td>
                            <td data-label="판매처">{parsed?.provider ?? '-'}</td>
                            <td data-label="상품명">
                              <div className="exploreCellTitle">{parsed?.title ?? '-'}</div>
                            </td>
                            <td data-label="가격">{parsed?.price != null ? `₩${parsed.price.toLocaleString('ko-KR')}` : '-'}</td>
                            <td data-label="썸네일">
                              {parsed?.thumbnailUrl ? (
                                <a href={parsed.thumbnailUrl} target="_blank" rel="noreferrer" className="exploreMiniThumbLink">
                                  <img src={parsed.thumbnailUrl} alt={parsed.title} className="exploreMiniThumb" />
                                </a>
                              ) : (
                                '-'
                              )}
                            </td>
                            <td data-label="링크">
                              {parsed?.deeplinkUrl || parsed?.url ? (
                                <a href={parsed?.deeplinkUrl || parsed?.url} target="_blank" rel="noreferrer" className="editorExternalLink">
                                  열기
                                </a>
                              ) : (
                                '-'
                              )}
                            </td>
                            <td data-label="등록일시">
                              <input
                                className="textInput exploreDateInput"
                                type="text"
                                value={row.startsAt}
                                onChange={(e) => updateRecommendationSchedule(row.id, 'startsAt', e.target.value)}
                                onBlur={() => normalizeRecommendationSchedule(row.id, 'startsAt')}
                                placeholder="YYYY-MM-DD 00:00"
                              />
                            </td>
                            <td data-label="종료일시">
                              <input
                                className="textInput exploreDateInput"
                                type="text"
                                value={row.endsAt}
                                onChange={(e) => updateRecommendationSchedule(row.id, 'endsAt', e.target.value)}
                                onBlur={() => normalizeRecommendationSchedule(row.id, 'endsAt')}
                                placeholder="YYYY-MM-DD 00:00"
                              />
                            </td>
                            <td data-label="확인">
                              <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => void resolveRecommendationRow(row.id)} disabled={isRecommendationActionBusy}>
                                {resolvingRowId === row.id ? '확인중' : '확인'}
                              </button>
                            </td>
                            <td data-label="등록">
                              <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => void registerRecommendationRow(row.id)} disabled={isRecommendationActionBusy || hasSlotConflict}>
                                {registeringRowId === row.id ? '등록중' : '등록'}
                              </button>
                            </td>
                            <td data-label="삭제">
                              <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={() => openRecommendationDeleteDialog([row.id])} disabled={isRecommendationActionBusy}>
                                {isDeleting ? '삭제중' : '삭제'}
                              </button>
                            </td>
                          </tr>
                        )
                      })}
                      {filteredHistoricalRecommendationRows.map((item) => (
                        <tr key={`history-${item.historyId}`} className="exploreRowHistory">
                          <td data-label="선택">-</td>
                          <td data-label="상태">{recommendationHistoryStatusLabel(item)}</td>
                          <td data-label="등록일">{item.registeredAt || '-'}</td>
                          <td data-label="노출">{item.displaySlot ?? 999}</td>
                          <td data-label="입력값"><div className="exploreHistoryRaw">{item.raw || item.deeplinkUrl || item.url || '-'}</div></td>
                          <td data-label="판매처">{item.provider || '-'}</td>
                          <td data-label="상품명"><div className="exploreCellTitle">{item.title || '-'}</div></td>
                          <td data-label="가격">{item.price != null ? `₩${item.price.toLocaleString('ko-KR')}` : '-'}</td>
                          <td data-label="썸네일">
                            {item.thumbnailUrl ? (
                              <a href={item.thumbnailUrl} target="_blank" rel="noreferrer" className="exploreMiniThumbLink">
                                <img src={item.thumbnailUrl} alt={item.title} className="exploreMiniThumb" />
                              </a>
                            ) : '-'}
                          </td>
                          <td data-label="링크">
                            {item.deeplinkUrl || item.url ? (
                              <a href={item.deeplinkUrl || item.url} target="_blank" rel="noreferrer" className="editorExternalLink">열기</a>
                            ) : '-'}
                          </td>
                          <td data-label="등록일시">{item.registeredAt || item.startsAt || '-'}</td>
                          <td data-label="종료일시">{item.endsAt || '-'}</td>
                          <td data-label="확인">-</td>
                          <td data-label="등록">-</td>
                          <td data-label="삭제">-</td>
                        </tr>
                      ))}
                    </>
                  ) : (
                    <tr>
                      <td data-label="상태" colSpan={15} className="emptyState">
                        {hasRecommendationSearchQuery ? '검색 결과 없음' : '행 없음'}
                      </td>
                    </tr>
                  )}
                </tbody>
                </table>
              </div>
            </div>
            {pendingDeleteRecommendationRowIds && pendingDeleteRecommendationRowIds.length > 0 ? (
              <div className="confirmOverlay" role="dialog" aria-modal="true" aria-label="추천 상품 삭제 확인">
                <div className="confirmDialog">
                  <div className="confirmTitle">삭제 확인</div>
                  <div className="confirmText">
                    {pendingDeleteRecommendationRowIds.length === 1
                      ? '이 추천 상품 행을 삭제할까? 확인을 누르면 삭제됩니다.'
                      : `선택한 ${pendingDeleteRecommendationRowIds.length}개 행을 삭제할까? 확인을 누르면 삭제됩니다.`}
                  </div>
                  <div className="confirmActions">
                    <button className="ghostBtnSmall exploreSheetBtn" type="button" onClick={closeRecommendationDeleteDialog} disabled={bulkRecommendationAction === 'delete'}>
                      취소
                    </button>
                    <button className="primaryBtn exploreCompactBtn confirmDangerBtn" type="button" onClick={() => void confirmDeleteRecommendationRows()} disabled={bulkRecommendationAction === 'delete'}>
                      {bulkRecommendationAction === 'delete' ? '삭제중' : '확인'}
                    </button>
                  </div>
                </div>
              </div>
            ) : null}
            <div className="compactActionRow" style={{ marginBottom: 12 }}>
              <button className="ghostBtnSmall exploreSheetUtilityBtn" type="button" onClick={appendRecommendationRow}>
                행 추가
              </button>
            </div>
            <label className="field" style={{ marginTop: 8 }}>
              <div className="fieldLabel exploreSheetFieldLabel">하단 단서조항</div>
              <textarea className="textInput exploreSheetTextarea" rows={3} value={form.editorialRecommendationsDisclaimer} onChange={(e) => update('editorialRecommendationsDisclaimer', e.target.value)} placeholder="이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다." />
            </label>
          </div>

          <div className="card exploreDenseCard exploreRuleSheetCard" style={{ marginBottom: activeWorkspace === 'rules' ? 16 : 0, display: activeWorkspace === 'rules' ? 'block' : 'none' }}>
            <div className="sectionHeader" style={{ marginBottom: 10 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 0 }}>노출 규칙</h2>
              </div>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">상태 {activeStateOption.label}</span>
                <span className="metaPill">좌측 메뉴 기준 편집</span>
              </div>
            </div>
            <div className="tableWrap exploreRuleSheetWrap">
              <table className="dataTable exploreRuleSheetTable">
                <colgroup>
                  <col style={{ width: '44%' }} />
                  <col style={{ width: '14%' }} />
                  <col style={{ width: '14%' }} />
                  <col style={{ width: '14%' }} />
                  <col style={{ width: '14%' }} />
                </colgroup>
                <thead>
                  <tr>
                    <th>항목</th>
                    <th>값</th>
                    <th>범위</th>
                    <th>우선순위</th>
                    <th>상한</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="exploreRuleSectionRow">
                    <td colSpan={5}>기본</td>
                  </tr>
                  {STATE_RULE_FIELDS.map((field) => (
                    <tr key={field.key}>
                      <td data-label="항목">
                        <div className="exploreRuleItemCell">
                          <div className="exploreRuleItemLabel">{STATE_RULE_META[field.key].label}</div>
                          <div className="exploreRuleItemKey">{field.key}</div>
                        </div>
                      </td>
                      <td data-label="값">
                        <input
                          className="textInput exploreRuleNumberInput"
                          type="number"
                          min={field.min}
                          max={field.max}
                          value={currentStateRules[field.key]}
                          onChange={(e) => updateStateRule(field.key, Number(e.target.value || field.min))}
                        />
                      </td>
                      <td data-label="범위"><span className="exploreRuleRange">{field.min}–{field.max}</span></td>
                      <td data-label="우선순위" className="exploreRuleEmptyCell">-</td>
                      <td data-label="CAP" className="exploreRuleEmptyCell">-</td>
                    </tr>
                  ))}
                  <tr className="exploreRuleSectionRow">
                    <td colSpan={5}>정책</td>
                  </tr>
                  {PROMO_POLICY_FIELDS.map((field) => (
                    <tr key={field.key}>
                      <td data-label="항목">
                        <div className="exploreRuleItemCell">
                          <div className="exploreRuleItemLabel">{field.label}</div>
                          <div className="exploreRuleItemKey">{field.key}</div>
                        </div>
                      </td>
                      <td data-label="값">
                        {field.key === 'maxSponsoredPromos' ? (
                          <input
                            className="textInput exploreRuleNumberInput"
                            type="number"
                            min={0}
                            max={12}
                            value={currentPromoPolicy.maxSponsoredPromos}
                            onChange={(e) => updatePromoPolicy('maxSponsoredPromos', Number(e.target.value || 0))}
                          />
                        ) : (
                          <label className="exploreRuleCheck">
                            <input
                              type="checkbox"
                              checked={field.key === 'allowSponsoredPromos' ? currentPromoPolicy.allowSponsoredPromos : currentPromoPolicy.organicFirst}
                              onChange={(e) => {
                                if (field.key === 'allowSponsoredPromos') {
                                  updatePromoPolicy('allowSponsoredPromos', e.target.checked)
                                  return
                                }
                                updatePromoPolicy('organicFirst', e.target.checked)
                              }}
                            />
                          </label>
                        )}
                      </td>
                      <td data-label="범위"><span className="exploreRuleRange">{field.range}</span></td>
                      <td data-label="우선순위" className="exploreRuleEmptyCell">-</td>
                      <td data-label="CAP" className="exploreRuleEmptyCell">-</td>
                    </tr>
                  ))}
                  <tr className="exploreRuleSectionRow">
                    <td colSpan={5}>우선순위</td>
                  </tr>
                  {DECISION_FIELDS.map((key) => (
                    <tr key={key}>
                      <td data-label="항목">
                        <div className="exploreRuleItemCell">
                          <div className="exploreRuleItemLabel">{DECISION_FIELD_META[key].label}</div>
                          <div className="exploreRuleItemKey">{key}</div>
                        </div>
                      </td>
                      <td data-label="값" className="exploreRuleEmptyCell">-</td>
                      <td data-label="범위" className="exploreRuleEmptyCell">-</td>
                      <td data-label="우선순위">
                        <input className="textInput exploreRuleNumberInput" type="number" min={0} max={999} value={currentDecisionPriority[key]} onChange={(e) => updateDecisionPriority(key, Number(e.target.value || 0))} />
                      </td>
                      <td data-label="CAP">
                        <input className="textInput exploreRuleNumberInput" type="number" min={0} max={4} value={currentDecisionMaxCount[key]} onChange={(e) => updateDecisionMaxCount(key, Number(e.target.value || 0))} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="card exploreDenseCard exploreSheetCard exploreCopyWorkspaceCard" style={{ marginBottom: activeWorkspace === 'copy' ? 16 : 0, display: activeWorkspace === 'copy' ? 'block' : 'none' }}>
            <div className="sectionHeader exploreCopyHeader" style={{ marginBottom: 6 }}>
              <h2 className="panelTitle" style={{ marginBottom: 0 }}>문구</h2>
              <a className="editorExternalLink" href="/content?section=app">브랜드·문구</a>
            </div>
            <div className="exploreCopyReferenceStrip">
              <div className="exploreCopyReferenceFields">
                <label className="field exploreCopyMiniField">
                  <div className="fieldLabel">도움 페이지 제목</div>
                  <input className="textInput exploreCopyInput" value={liveTitle} disabled readOnly />
                </label>
                <label className="field exploreCopyMiniField">
                  <div className="fieldLabel">도움 설명</div>
                  <input className="textInput exploreCopyInput" value={liveSubtitle} disabled readOnly />
                </label>
              </div>
            </div>
            <div className="exploreCopySectionTitleRow">
              <strong>결정 인박스 문구</strong>
            </div>
            <div className="tableWrap exploreCopySheetWrap">
              <table className="dataTable exploreCopySheetTable">
                <colgroup>
                  <col style={{ width: '20%' }} />
                  <col style={{ width: '22%' }} />
                  <col style={{ width: '58%' }} />
                </colgroup>
                <thead>
                  <tr>
                    <th>항목</th>
                    <th>짧은 라벨</th>
                    <th>본문</th>
                  </tr>
                </thead>
                <tbody>
                  {DECISION_COPY_MESSAGE_FIELDS.map((field) => (
                    <tr key={field.id}>
                      <td data-label="항목">
                        <div className="exploreRuleItemCell">
                          <div className="exploreRuleItemLabel">{field.label}</div>
                          <div className="exploreRuleItemKey">{field.reasonKey}</div>
                        </div>
                      </td>
                      <td data-label="짧은 라벨">
                        <input className="textInput exploreCopyInput" value={form.decisionCopy[field.reasonKey]} onChange={(e) => updateDecisionCopy(field.reasonKey, e.target.value)} />
                      </td>
                      <td data-label="본문">
                        <textarea className="textInput exploreCopyTextarea" rows={1} value={form.decisionCopy[field.bodyKey]} onChange={(e) => updateDecisionCopy(field.bodyKey, e.target.value)} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="exploreCopySectionTitleRow">
              <strong>대안 문구</strong>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState)?.label}</span>
            </div>
            <div className="exploreCopyOfferGrid">
              <label className="field exploreCopyMiniField">
                <div className="fieldLabel">상태별 짧은 라벨</div>
                <input className="textInput exploreCopyInput" value={form.decisionCopy[OFFER_REASON_LABEL_FIELDS[layoutState]]} onChange={(e) => updateDecisionCopy(OFFER_REASON_LABEL_FIELDS[layoutState], e.target.value)} />
              </label>
              <label className="field exploreCopyMiniField">
                <div className="fieldLabel">공통 본문</div>
                <textarea className="textInput exploreCopyTextarea" rows={1} value={form.decisionCopy.offerBody} onChange={(e) => updateDecisionCopy('offerBody', e.target.value)} />
              </label>
            </div>
          </div>

          <div className="card" style={{ display: activeWorkspace === 'store' ? 'block' : 'none' }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 0 }}>마트 문맥</h2>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">{form.storeContextEnabled ? '행사 노출 사용' : '행사 노출 중지'}</span>
              <span className="metaPill">{form.storeContextStoreName}</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' }}>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">
                  <input type="checkbox" checked={form.storeContextEnabled} onChange={(e) => update('storeContextEnabled', e.target.checked)} style={{ marginRight: 8 }} />
                  마트 문맥 사용
                </div>
              </label>
              <label className="field">
                <div className="fieldLabel">마트명</div>
                <input className="textInput" value={form.storeContextStoreName} onChange={(e) => update('storeContextStoreName', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">행사 최대 개수</div>
                <input className="textInput" type="number" min={0} max={12} value={form.stateRules.storeContext.storeContextMaxPromos} onChange={(e) => setForm((prev) => ({ ...prev, stateRules: { ...prev.stateRules, storeContext: { ...prev.stateRules.storeContext, storeContextMaxPromos: Number(e.target.value || 0) } } }))} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">행사 제목</div>
                <input className="textInput" value={form.storeContextPromoTitle} onChange={(e) => update('storeContextPromoTitle', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">행사 설명</div>
                <textarea className="textInput" rows={3} value={form.storeContextPromoBody} onChange={(e) => update('storeContextPromoBody', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">행사 기준 문구</div>
                <input className="textInput" value={form.storeContextPromoSeedLabels} onChange={(e) => update('storeContextPromoSeedLabels', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">행사 유형</div>
                <select className="textInput" value={form.storeContextPromoSourceType} onChange={(e) => update('storeContextPromoSourceType', e.target.value as ExploreSettings['storeContextPromoSourceType'])}>
                  <option value="storeSale">마트 행사</option>
                  <option value="sponsoredPlacement">제휴 노출</option>
                  <option value="editorialCuration">운영 추천</option>
                </select>
              </label>
              <label className="field">
                <div className="fieldLabel">행사 시작 우선순위</div>
                <input className="textInput" type="number" min={0} max={1000} value={form.storeContextPromoPriorityStart} onChange={(e) => update('storeContextPromoPriorityStart', Number(e.target.value || 0))} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">
                  <input type="checkbox" checked={form.storeContextPromoSponsored} onChange={(e) => update('storeContextPromoSponsored', e.target.checked)} style={{ marginRight: 8 }} />
                  제휴 행사
                </div>
              </label>
              <label className="field">
                <div className="fieldLabel">제휴 표기</div>
                <input className="textInput" value={form.storeContextPromoSponsorLabel} onChange={(e) => update('storeContextPromoSponsorLabel', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">버튼 문구</div>
                <input className="textInput" value={form.storeContextPromoCtaLabel} onChange={(e) => update('storeContextPromoCtaLabel', e.target.value)} />
              </label>
            </div>
            <div className="metaRow" style={{ marginTop: 12 }}>
              <span className="metaPill">미리보기 행사</span>
              {storePromoPreview.map((promo) => (
                <span className="metaPill" key={promo.id}>{promo.badgeLabel} · {promo.sourceType} · p{promo.priority} · {promo.isSponsored ? '제휴' : '일반'}</span>
              ))}
            </div>
          </div>
        </div>
    </div>
  )
}
