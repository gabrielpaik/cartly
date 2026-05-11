'use client'

import { useEffect, useMemo, useRef, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { putJson } from '../../lib/api'
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
  title: string
  price?: number
  thumbnailUrl?: string
  url?: string
  deeplinkUrl?: string
  provider: string
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
  editorialRecommendationsTitle: string
  editorialRecommendationsSubtitle: string
  editorialRecommendationsCount: number
  editorialRecommendationsPoolRaw: string
  editorialRecommendationsDisclaimer: string
  editorialRecommendationsItems?: EditorialRecommendationPreview[]
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

type ExploreStateOption = {
  id: ExploreStateId
  label: string
  description: string
}

const PREVIEW_SRC = '/app-preview/index.html?screen=help'
const EDITORIAL_VISIBLE_COUNT = 5
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
  const [previewNonce, setPreviewNonce] = useState(0)
  const previewFrameRef = useRef<HTMLIFrameElement | null>(null)

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
  const currentStateRules = form.stateRules[layoutState]
  const currentPromoPolicy = form.statePromoPolicies[layoutState]
  const currentDecisionPriority = form.stateDecisionPriorities[layoutState]
  const currentDecisionMaxCount = form.stateDecisionMaxCounts[layoutState]
  const isDirty = JSON.stringify(form) !== JSON.stringify(res.data.data)
  const storePromoPreview = useMemo(() => buildStorePromoPreview(form), [form])
  const editorialPoolPreview = useMemo(() => {
    if ((form.editorialRecommendationsItems?.length ?? 0) > 0) {
      return form.editorialRecommendationsItems ?? []
    }
    return parseEditorialRecommendations(form.editorialRecommendationsPoolRaw)
  }, [form.editorialRecommendationsItems, form.editorialRecommendationsPoolRaw])
  const liveTitle = appConfigRes.data.data.copy?.help?.pageTitle ?? 'Explore'
  const liveSubtitle = appConfigRes.data.data.copy?.help?.subtitle ?? '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요'
  const features = appConfigRes.data.data.features

  function update<K extends keyof ExploreSettings>(key: K, value: ExploreSettings[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
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
    previewFrameRef.current?.contentWindow?.postMessage(
      {
        type: 'branding-preview',
        payload: previewPayload(),
      },
      '*',
    )
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
    <div>
      <PageHeader
        badge={res.usingFallback ? 'Fallback data' : res.loading ? 'Loading...' : 'Live data'}
        title={t('admin.explore.title', 'Explore')}
        description={t('admin.explore.desc', '도움/Explore 탭 운영 제어를 Content에서 분리한 전용 화면')}
        onRefresh={() => void Promise.allSettled([res.reload(), appConfigRes.reload()])}
        refreshing={res.loading || appConfigRes.loading || saving}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {message ? <div className="saveMessage" style={{ marginBottom: 16 }}>{message}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>Live explore config unavailable.</strong> 지금 화면은 fallback/mock data일 수 있어.
        </div>
      ) : null}

      <div className="kpiGrid">
        <StatCard label="Visible sections" value={`${enabledSections.length}`} note={enabledSections.join(' · ') || '-'} />
        <StatCard label="Explore state" value={form.stateMode === 'auto' ? 'AUTO' : form.stateMode} note={form.stateMode === 'auto' ? 'runtime decides' : 'forced override'} />
        <StatCard label="Revisit cap" value={`${currentStateRules.revisitMaxItems}`} note={`recent ${currentStateRules.revisitRecentScanLimit} · cart ${currentStateRules.revisitCartItemLimit}`} />
        <StatCard label="Repeat rule" value={`≥ ${currentStateRules.repeatMinCount}`} note={`max ${currentStateRules.repeatMaxItems}`} />
        <StatCard label="Offer slots" value={`${currentStateRules.offerMaxSlots}`} note={features?.coupangPartnersAffiliateReady ? 'affiliate ready' : 'fallback/search mode'} />
        <StatCard label="Manual picks" value={form.editorialRecommendationsEnabled ? `${Math.min(EDITORIAL_VISIBLE_COUNT, editorialPoolPreview.length)} / ${editorialPoolPreview.length}` : 'OFF'} note="show 5 fixed" />
        <StatCard label="Store promo" value={form.storeContextEnabled ? 'ON' : 'OFF'} note={`${form.storeContextStoreName} · ${storePromoPreview.length}개 preview`} />
      </div>

      <div className="metaRow section" style={{ marginTop: 16 }}>
        <span className="metaPill">same-intent + manual picks</span>
        <span className="metaPill">bridge {features?.exploreOfferBridgeEnabled ? 'on' : 'off'}</span>
        <span className="metaPill">coupang {features?.coupangPartnersEnabled ? 'enabled' : 'disabled'}</span>
        <span className="metaPill">title/subtitle in Content</span>
        <span className="metaPill">decision copy in Explore</span>
      </div>

      <div className="twoCol" style={{ marginTop: 16 }}>
        <div>
          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>표시할 섹션</h2>
                <p className="pageDesc">보일지 끌지 정하고, 상태별 레이아웃 순서를 따로 다듬으면 돼.</p>
              </div>
            </div>
            <div className="metaRow" style={{ marginBottom: 12 }}>
              {EXPLORE_STATE_OPTIONS.map((state) => (
                <button
                  key={state.id}
                  className="ghostBtnSmall"
                  type="button"
                  onClick={() => setLayoutState(state.id)}
                  disabled={layoutState === state.id}
                >
                  {state.label}
                </button>
              ))}
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">편집 중</span>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState)?.label}</span>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState)?.description}</span>
            </div>
            <div style={{ display: 'grid', gap: 12 }}>
              {EXPLORE_SECTION_OPTIONS.map((section) => {
                const enabled = enabledSections.includes(section.id)
                const orderIndex = orderedSections.indexOf(section.id)
                return (
                  <div
                    key={section.id}
                    style={{
                      border: '1px solid rgba(15, 23, 42, 0.08)',
                      borderRadius: 16,
                      padding: 14,
                      background: enabled ? '#ffffff' : '#f8fafc',
                    }}
                  >
                    <label style={{ display: 'flex', gap: 10, alignItems: 'flex-start', cursor: 'pointer' }}>
                      <input type="checkbox" checked={enabled} onChange={() => toggleSection(section.id)} style={{ marginTop: 4 }} />
                      <div>
                        <div style={{ fontWeight: 700, color: '#0f172a', marginBottom: 4 }}>{section.label}</div>
                        <div style={{ fontSize: 13, lineHeight: 1.5, color: '#475569' }}>{section.description}</div>
                      </div>
                    </label>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginTop: 12, paddingLeft: 26 }}>
                      <span className="metaPill">{enabled ? `표시 중 · ${orderIndex + 1}번째` : '숨김'}</span>
                      <button className="ghostBtnSmall" type="button" onClick={() => moveSection(section.id, -1)} disabled={!enabled || orderIndex <= 0}>
                        위로
                      </button>
                      <button className="ghostBtnSmall" type="button" onClick={() => moveSection(section.id, 1)} disabled={!enabled || orderIndex < 0 || orderIndex >= orderedSections.length - 1}>
                        아래로
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
            <div className="metaRow" style={{ marginTop: 12 }}>
              <span className="metaPill">현재 순서</span>
              {orderedSections.map((sectionId) => {
                const section = EXPLORE_SECTION_OPTIONS.find((item) => item.id === sectionId)
                return <span className="metaPill" key={sectionId}>{section?.label ?? sectionId}</span>
              })}
            </div>
            <details style={{ marginTop: 12 }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600, color: '#334155' }}>고급값 직접 보기</summary>
              <div className="sectionGrid" style={{ gridTemplateColumns: '1fr 1fr', marginTop: 12 }}>
                <label className="field">
                  <div className="fieldLabel">enabledSections</div>
                  <input className="textInput" value={form.enabledSections} onChange={(e) => update('enabledSections', e.target.value)} />
                </label>
                <label className="field">
                  <div className="fieldLabel">sectionOrder (legacy fallback)</div>
                  <input className="textInput" value={form.sectionOrder} onChange={(e) => update('sectionOrder', e.target.value)} />
                </label>
                <label className="field">
                  <div className="fieldLabel">{stateOrderKey(layoutState)}</div>
                  <input className="textInput" value={form[stateOrderKey(layoutState)]} onChange={(e) => update(stateOrderKey(layoutState), e.target.value)} />
                </label>
                <label className="field">
                  <div className="fieldLabel">stateMode</div>
                  <select className="textInput" value={form.stateMode} onChange={(e) => update('stateMode', e.target.value as ExploreSettings['stateMode'])}>
                    <option value="auto">auto</option>
                    {EXPLORE_STATE_OPTIONS.map((state) => <option key={state.id} value={state.id}>{state.id}</option>)}
                  </select>
                </label>
              </div>
            </details>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Explore state mode</h2>
                <p className="pageDesc">기본은 runtime이 상태를 고르고, 필요하면 특정 상태로 강제할 수 있어.</p>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button className="ghostBtnSmall" type="button" onClick={() => update('stateMode', 'auto')} disabled={form.stateMode === 'auto'}>
                Auto
              </button>
              {EXPLORE_STATE_OPTIONS.map((state) => (
                <button
                  key={state.id}
                  className="ghostBtnSmall"
                  type="button"
                  onClick={() => update('stateMode', state.id)}
                  disabled={form.stateMode === state.id}
                >
                  {state.label} 강제
                </button>
              ))}
            </div>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>추천 제품</h2>
                <p className="pageDesc">앱에는 상품명, 가격, 썸네일만 보이게 하고 링크는 카드 탭 동작에만 써. 하단 단서조항도 여기서 같이 관리해.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">pool {editorialPoolPreview.length}개</span>
              <span className="metaPill">show {Math.min(EDITORIAL_VISIBLE_COUNT, editorialPoolPreview.length || EDITORIAL_VISIBLE_COUNT)}개</span>
              <span className="metaPill">fixed 5</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' }}>
              <label className="field">
                <div className="fieldLabel">
                  <input type="checkbox" checked={form.editorialRecommendationsEnabled} onChange={(e) => update('editorialRecommendationsEnabled', e.target.checked)} style={{ marginRight: 8 }} />
                  추천 제품 섹션 활성화
                </div>
              </label>
              <label className="field">
                <div className="fieldLabel">노출 개수</div>
                <input className="textInput" value="5" disabled />
              </label>
              <label className="field">
                <div className="fieldLabel">섹션 제목</div>
                <input className="textInput" value={form.editorialRecommendationsTitle} onChange={(e) => update('editorialRecommendationsTitle', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">섹션 설명</div>
                <input className="textInput" value={form.editorialRecommendationsSubtitle} onChange={(e) => update('editorialRecommendationsSubtitle', e.target.value)} />
              </label>
            </div>
            <label className="field" style={{ marginTop: 12 }}>
              <div className="fieldLabel">추천 상품 풀</div>
              <textarea className="textInput" rows={10} value={form.editorialRecommendationsPoolRaw} onChange={(e) => update('editorialRecommendationsPoolRaw', e.target.value)} placeholder={'상품명 | 12900 | https://image.example.com/item.jpg | https://partners.coupang.com/...\n상품명 | 5980 | https://image.example.com/item.jpg'} />
              <div className="previewSubtitle" style={{ marginTop: 8 }}>한 줄에 하나씩 넣어. 권장 형식은 `상품명 | 가격 | 썸네일URL | 링크URL` 이고, 링크는 선택이야.</div>
            </label>
            <label className="field" style={{ marginTop: 12 }}>
              <div className="fieldLabel">하단 단서조항</div>
              <textarea className="textInput" rows={3} value={form.editorialRecommendationsDisclaimer} onChange={(e) => update('editorialRecommendationsDisclaimer', e.target.value)} placeholder="이 섹션에는 제휴 링크가 포함될 수 있으며, 이에 따라 일정 수수료를 제공받을 수 있어요." />
              <div className="previewSubtitle" style={{ marginTop: 8 }}>추천 상품 카드 5개 아래에 작은 안내문으로 노출돼.</div>
            </label>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>State rules & counts</h2>
                <p className="pageDesc">지금 선택한 상태에서 몇 개를 보여줄지, 어떤 기준으로 자를지 따로 조절해.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">rule target</span>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState)?.label}</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
              <label className="field">
                <div className="fieldLabel">revisitRecentScanLimit</div>
                <input className="textInput" type="number" min={0} max={8} value={currentStateRules.revisitRecentScanLimit} onChange={(e) => updateStateRule('revisitRecentScanLimit', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">revisitCartItemLimit</div>
                <input className="textInput" type="number" min={0} max={8} value={currentStateRules.revisitCartItemLimit} onChange={(e) => updateStateRule('revisitCartItemLimit', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">revisitMaxItems</div>
                <input className="textInput" type="number" min={0} max={12} value={currentStateRules.revisitMaxItems} onChange={(e) => updateStateRule('revisitMaxItems', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">repeatMinCount</div>
                <input className="textInput" type="number" min={1} max={10} value={currentStateRules.repeatMinCount} onChange={(e) => updateStateRule('repeatMinCount', Number(e.target.value || 1))} />
              </label>
              <label className="field">
                <div className="fieldLabel">repeatMaxItems</div>
                <input className="textInput" type="number" min={0} max={12} value={currentStateRules.repeatMaxItems} onChange={(e) => updateStateRule('repeatMaxItems', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerMaxSlots</div>
                <input className="textInput" type="number" min={0} max={12} value={currentStateRules.offerMaxSlots} onChange={(e) => updateStateRule('offerMaxSlots', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">storeContextMaxPromos</div>
                <input className="textInput" type="number" min={0} max={12} value={currentStateRules.storeContextMaxPromos} onChange={(e) => updateStateRule('storeContextMaxPromos', Number(e.target.value || 0))} />
              </label>
            </div>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Promo policy</h2>
                <p className="pageDesc">현재 선택한 상태에서 sponsored를 허용할지, 몇 개까지 보일지, organic을 먼저 둘지 정해.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">policy target</span>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState)?.label}</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
              <label className="field">
                <div className="fieldLabel">
                  <input type="checkbox" checked={currentPromoPolicy.allowSponsoredPromos} onChange={(e) => updatePromoPolicy('allowSponsoredPromos', e.target.checked)} style={{ marginRight: 8 }} />
                  allowSponsoredPromos
                </div>
              </label>
              <label className="field">
                <div className="fieldLabel">maxSponsoredPromos</div>
                <input className="textInput" type="number" min={0} max={12} value={currentPromoPolicy.maxSponsoredPromos} onChange={(e) => updatePromoPolicy('maxSponsoredPromos', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">
                  <input type="checkbox" checked={currentPromoPolicy.organicFirst} onChange={(e) => updatePromoPolicy('organicFirst', e.target.checked)} style={{ marginRight: 8 }} />
                  organicFirst
                </div>
              </label>
            </div>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Decision ranking</h2>
                <p className="pageDesc">현재 선택한 상태에서 어떤 이유 카드를 먼저 위로 올릴지 숫자로 정해.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">ranking target</span>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState)?.label}</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
              <label className="field">
                <div className="fieldLabel">offerPendingReview</div>
                <input className="textInput" type="number" min={0} max={999} value={currentDecisionPriority.offerPendingReview} onChange={(e) => updateDecisionPriority('offerPendingReview', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerCurrentCart</div>
                <input className="textInput" type="number" min={0} max={999} value={currentDecisionPriority.offerCurrentCart} onChange={(e) => updateDecisionPriority('offerCurrentCart', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerRepeatPurchase</div>
                <input className="textInput" type="number" min={0} max={999} value={currentDecisionPriority.offerRepeatPurchase} onChange={(e) => updateDecisionPriority('offerRepeatPurchase', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">recentScanPending</div>
                <input className="textInput" type="number" min={0} max={999} value={currentDecisionPriority.recentScanPending} onChange={(e) => updateDecisionPriority('recentScanPending', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">recentScanInCart</div>
                <input className="textInput" type="number" min={0} max={999} value={currentDecisionPriority.recentScanInCart} onChange={(e) => updateDecisionPriority('recentScanInCart', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">currentCartHighImpact</div>
                <input className="textInput" type="number" min={0} max={999} value={currentDecisionPriority.currentCartHighImpact} onChange={(e) => updateDecisionPriority('currentCartHighImpact', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">currentCartDefault</div>
                <input className="textInput" type="number" min={0} max={999} value={currentDecisionPriority.currentCartDefault} onChange={(e) => updateDecisionPriority('currentCartDefault', Number(e.target.value || 0))} />
              </label>
            </div>
            <div className="metaRow" style={{ marginTop: 12 }}>
              <span className="metaPill">preview order</span>
              {decisionPriorityPreview(form, layoutState).map((item) => (
                <span className="metaPill" key={item.key}>{item.label} · {item.value}</span>
              ))}
            </div>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Decision max counts</h2>
                <p className="pageDesc">한 이유 타입이 decision inbox를 너무 많이 차지하지 않도록 상태별 상한선을 정해.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">cap target</span>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === layoutState)?.label}</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
              <label className="field">
                <div className="fieldLabel">offerPendingReview</div>
                <input className="textInput" type="number" min={0} max={4} value={currentDecisionMaxCount.offerPendingReview} onChange={(e) => updateDecisionMaxCount('offerPendingReview', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerCurrentCart</div>
                <input className="textInput" type="number" min={0} max={4} value={currentDecisionMaxCount.offerCurrentCart} onChange={(e) => updateDecisionMaxCount('offerCurrentCart', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerRepeatPurchase</div>
                <input className="textInput" type="number" min={0} max={4} value={currentDecisionMaxCount.offerRepeatPurchase} onChange={(e) => updateDecisionMaxCount('offerRepeatPurchase', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">recentScanPending</div>
                <input className="textInput" type="number" min={0} max={4} value={currentDecisionMaxCount.recentScanPending} onChange={(e) => updateDecisionMaxCount('recentScanPending', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">recentScanInCart</div>
                <input className="textInput" type="number" min={0} max={4} value={currentDecisionMaxCount.recentScanInCart} onChange={(e) => updateDecisionMaxCount('recentScanInCart', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">currentCartHighImpact</div>
                <input className="textInput" type="number" min={0} max={4} value={currentDecisionMaxCount.currentCartHighImpact} onChange={(e) => updateDecisionMaxCount('currentCartHighImpact', Number(e.target.value || 0))} />
              </label>
              <label className="field">
                <div className="fieldLabel">currentCartDefault</div>
                <input className="textInput" type="number" min={0} max={4} value={currentDecisionMaxCount.currentCartDefault} onChange={(e) => updateDecisionMaxCount('currentCartDefault', Number(e.target.value || 0))} />
              </label>
            </div>
            <div className="metaRow" style={{ marginTop: 12 }}>
              <span className="metaPill">preview caps</span>
              {decisionMaxCountPreview(form, layoutState).map((item) => (
                <span className="metaPill" key={item.key}>{item.label} · max {item.value}</span>
              ))}
            </div>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Decision copy</h2>
                <p className="pageDesc">결정 인박스에서 왜 지금 다시 봐야 하는지 설명하는 문구를 여기서 직접 바꿔.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">runtime editable</span>
              <span className="metaPill">preview reflects instantly</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' }}>
              <label className="field">
                <div className="fieldLabel">recentScanPendingReasonLabel</div>
                <input className="textInput" value={form.decisionCopy.recentScanPendingReasonLabel} onChange={(e) => updateDecisionCopy('recentScanPendingReasonLabel', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">recentScanInCartReasonLabel</div>
                <input className="textInput" value={form.decisionCopy.recentScanInCartReasonLabel} onChange={(e) => updateDecisionCopy('recentScanInCartReasonLabel', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">currentCartHighImpactReasonLabel</div>
                <input className="textInput" value={form.decisionCopy.currentCartHighImpactReasonLabel} onChange={(e) => updateDecisionCopy('currentCartHighImpactReasonLabel', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">currentCartDefaultReasonLabel</div>
                <input className="textInput" value={form.decisionCopy.currentCartDefaultReasonLabel} onChange={(e) => updateDecisionCopy('currentCartDefaultReasonLabel', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerReasonLabelActiveShopping</div>
                <input className="textInput" value={form.decisionCopy.offerReasonLabelActiveShopping} onChange={(e) => updateDecisionCopy('offerReasonLabelActiveShopping', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerReasonLabelPostSave</div>
                <input className="textInput" value={form.decisionCopy.offerReasonLabelPostSave} onChange={(e) => updateDecisionCopy('offerReasonLabelPostSave', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerReasonLabelIdlePlanning</div>
                <input className="textInput" value={form.decisionCopy.offerReasonLabelIdlePlanning} onChange={(e) => updateDecisionCopy('offerReasonLabelIdlePlanning', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">offerReasonLabelStoreContext</div>
                <input className="textInput" value={form.decisionCopy.offerReasonLabelStoreContext} onChange={(e) => updateDecisionCopy('offerReasonLabelStoreContext', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">recentScanPendingBody</div>
                <textarea className="textInput" rows={2} value={form.decisionCopy.recentScanPendingBody} onChange={(e) => updateDecisionCopy('recentScanPendingBody', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">recentScanInCartBody</div>
                <textarea className="textInput" rows={2} value={form.decisionCopy.recentScanInCartBody} onChange={(e) => updateDecisionCopy('recentScanInCartBody', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">currentCartHighImpactBody</div>
                <textarea className="textInput" rows={2} value={form.decisionCopy.currentCartHighImpactBody} onChange={(e) => updateDecisionCopy('currentCartHighImpactBody', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">currentCartDefaultBody</div>
                <textarea className="textInput" rows={2} value={form.decisionCopy.currentCartDefaultBody} onChange={(e) => updateDecisionCopy('currentCartDefaultBody', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">offerBody</div>
                <textarea className="textInput" rows={2} value={form.decisionCopy.offerBody} onChange={(e) => updateDecisionCopy('offerBody', e.target.value)} />
              </label>
            </div>
          </div>

          <div className="card">
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Store-context skeleton</h2>
                <p className="pageDesc">특정 마트 문맥에서 오프라인 행사와 광고를 띄우기 위한 골격이야.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">{form.storeContextEnabled ? 'store lane on' : 'store lane off'}</span>
              <span className="metaPill">{form.storeContextStoreName}</span>
            </div>
            <div className="sectionGrid" style={{ gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' }}>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">
                  <input type="checkbox" checked={form.storeContextEnabled} onChange={(e) => update('storeContextEnabled', e.target.checked)} style={{ marginRight: 8 }} />
                  store context 사용
                </div>
              </label>
              <label className="field">
                <div className="fieldLabel">storeContextStoreName</div>
                <input className="textInput" value={form.storeContextStoreName} onChange={(e) => update('storeContextStoreName', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">storeContextMaxPromos</div>
                <input className="textInput" type="number" min={0} max={12} value={form.stateRules.storeContext.storeContextMaxPromos} onChange={(e) => setForm((prev) => ({ ...prev, stateRules: { ...prev.stateRules, storeContext: { ...prev.stateRules.storeContext, storeContextMaxPromos: Number(e.target.value || 0) } } }))} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">storeContextPromoTitle</div>
                <input className="textInput" value={form.storeContextPromoTitle} onChange={(e) => update('storeContextPromoTitle', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">storeContextPromoBody</div>
                <textarea className="textInput" rows={3} value={form.storeContextPromoBody} onChange={(e) => update('storeContextPromoBody', e.target.value)} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">storeContextPromoSeedLabels</div>
                <input className="textInput" value={form.storeContextPromoSeedLabels} onChange={(e) => update('storeContextPromoSeedLabels', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">storeContextPromoSourceType</div>
                <select className="textInput" value={form.storeContextPromoSourceType} onChange={(e) => update('storeContextPromoSourceType', e.target.value as ExploreSettings['storeContextPromoSourceType'])}>
                  <option value="storeSale">storeSale</option>
                  <option value="sponsoredPlacement">sponsoredPlacement</option>
                  <option value="editorialCuration">editorialCuration</option>
                </select>
              </label>
              <label className="field">
                <div className="fieldLabel">storeContextPromoPriorityStart</div>
                <input className="textInput" type="number" min={0} max={1000} value={form.storeContextPromoPriorityStart} onChange={(e) => update('storeContextPromoPriorityStart', Number(e.target.value || 0))} />
              </label>
              <label className="field" style={{ gridColumn: '1 / -1' }}>
                <div className="fieldLabel">
                  <input type="checkbox" checked={form.storeContextPromoSponsored} onChange={(e) => update('storeContextPromoSponsored', e.target.checked)} style={{ marginRight: 8 }} />
                  sponsored promo
                </div>
              </label>
              <label className="field">
                <div className="fieldLabel">storeContextPromoSponsorLabel</div>
                <input className="textInput" value={form.storeContextPromoSponsorLabel} onChange={(e) => update('storeContextPromoSponsorLabel', e.target.value)} />
              </label>
              <label className="field">
                <div className="fieldLabel">storeContextPromoCtaLabel</div>
                <input className="textInput" value={form.storeContextPromoCtaLabel} onChange={(e) => update('storeContextPromoCtaLabel', e.target.value)} />
              </label>
            </div>
            <div className="metaRow" style={{ marginTop: 12 }}>
              <span className="metaPill">preview promos</span>
              {storePromoPreview.map((promo) => (
                <span className="metaPill" key={promo.id}>{promo.badgeLabel} · {promo.sourceType} · p{promo.priority} · {promo.isSponsored ? 'sponsored' : 'organic'}</span>
              ))}
            </div>
          </div>
        </div>

        <div className="stickySideColumn">
          <div className="card">
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Explore preview</h2>
                <p className="pageDesc">실제 Help/Explore 위젯을 preview 데이터로 렌더링한 화면이야. 스크린샷 목업은 아니야.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">real widget</span>
              <span className="metaPill">preview data</span>
              <span className="metaPill">title: {liveTitle}</span>
              <span className="metaPill">{EXPLORE_STATE_OPTIONS.find((state) => state.id === previewScenario)?.label} 화면</span>
            </div>
            <div className="metaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">decision reasons</span>
              {decisionReasonVocabulary(form, previewScenario).map((label) => (
                <span className="metaPill" key={label}>{label}</span>
              ))}
            </div>
            <div className="metaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">decision ranking</span>
              {decisionPriorityPreview(form, previewScenario).map((item) => (
                <span className="metaPill" key={`${item.key}-${item.value}`}>{item.label} · {item.value}</span>
              ))}
            </div>
            <div className="metaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">decision caps</span>
              {decisionMaxCountPreview(form, previewScenario).map((item) => (
                <span className="metaPill" key={`${item.key}-cap-${item.value}`}>{item.label} · max {item.value}</span>
              ))}
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
              {EXPLORE_STATE_OPTIONS.map((state) => (
                <button
                  key={state.id}
                  className="ghostBtnSmall"
                  type="button"
                  onClick={() => setPreviewScenario(state.id)}
                  disabled={previewScenario === state.id}
                >
                  {state.label}
                </button>
              ))}
            </div>
            <iframe
              key={previewNonce}
              ref={previewFrameRef}
              title="Explore preview"
              src={PREVIEW_SRC}
              onLoad={() => postPreviewPayload()}
              style={{ width: '100%', minHeight: 700, border: '1px solid rgba(15, 23, 42, 0.08)', borderRadius: 18, background: '#f8fafc' }}
            />
          </div>

          <div className="card utilityRailCardTight">
            <div className="sectionHeader" style={{ marginBottom: 12 }}>
              <div>
                <h2 className="panelTitle" style={{ marginBottom: 6 }}>Save</h2>
                <p className="pageDesc">탭 라벨과 상단 카피는 아직 Content에서 관리해.</p>
              </div>
            </div>
            <div className="metaRow compactMetaRow" style={{ marginBottom: 12 }}>
              <span className="metaPill">{isDirty ? 'unsaved changes' : 'saved'}</span>
            </div>
            <div style={{ display: 'grid', gap: 8 }}>
              <button className="primaryBtn compactPrimaryAction" type="button" onClick={() => void onSave()} disabled={saving}>
                {saving ? '저장 중...' : 'Explore 저장'}
              </button>
              <button className="ghostBtn" type="button" onClick={() => setForm(res.data.data)} disabled={saving || !isDirty}>
                되돌리기
              </button>
              <button className="ghostBtn" type="button" onClick={() => setPreviewNonce((value) => value + 1)}>
                preview reload
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
