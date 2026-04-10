'use client'

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { fetchJsonSafe, isUnauthorizedError, postFormData, putJson } from '../../lib/api'
import { formatDate, formatNumber, formatPercent } from '../../lib/format'
import { mockSlots } from '../../lib/mock'

type SlotConfig = {
  slotLabel?: string
  slotDescription?: string
  placementNote?: string
  maxHeight: number
  screen: string
  position: string
  tone: string
  title: string
  message: string
  ctaLabel: string | null
  targetUrl: string | null
  imageUrl: string | null
  reservedTitle?: string | null
  reservedMessage?: string | null
  reservedCtaLabel?: string | null
  reservedTargetUrl?: string | null
  reservedImageUrl?: string | null
  exposureStartAt?: string | null
  exposureEndAt?: string | null
  reservationStartAt?: string | null
  reservationEndAt?: string | null
  liveCampaignId?: string | null
  reservedCampaignId?: string | null
}

type SlotRow = {
  id: string
  slotKey: string
  placementType: string
  status: string
  createdAt: string | null
  updatedAt: string | null
  config: SlotConfig
}

type CampaignRow = {
  id: string
  slotKey: string
  variant: 'live' | 'reserved'
  status: string
  title: string
  message: string
  ctaLabel: string | null
  targetUrl: string | null
  imageUrl: string | null
  startAt: string | null
  endAt: string | null
  impressions: number
  clicks: number
  ctr: number
  createdAt: string | null
  updatedAt: string | null
}

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

type SlotPreviewSpec = {
  screenTitle: string
  screenSubtitle: string
  placementLabel: string
  mode: 'save-complete-sheet' | 'saved-inline-first' | 'saved-inline-third' | 'my-inline'
}

function buildSlotPreviewSpecs(t: (key: string, fallback?: string) => string): Record<string, SlotPreviewSpec> {
  return {
    save_complete_sheet_1: {
      screenTitle: t('admin.ads.preview.spec.saveComplete.title', 'Save Complete'),
      screenSubtitle: t('admin.ads.preview.spec.saveComplete.subtitle', '저장 완료 화면'),
      placementLabel: t('admin.ads.preview.spec.saveComplete.placement', '요약 아래, 액션 버튼 위'),
      mode: 'save-complete-sheet',
    },
    saved_inline_1: {
      screenTitle: t('admin.ads.preview.spec.savedList.title', 'Saved List'),
      screenSubtitle: t('admin.ads.preview.spec.savedList.subtitle', '저장 카트 목록'),
      placementLabel: t('admin.ads.preview.spec.savedFirst.placement', '첫 카드 다음 위치'),
      mode: 'saved-inline-first',
    },
    saved_inline_2: {
      screenTitle: t('admin.ads.preview.spec.savedList.title', 'Saved List'),
      screenSubtitle: t('admin.ads.preview.spec.savedList.subtitle', '저장 카트 목록'),
      placementLabel: t('admin.ads.preview.spec.savedThird.placement', '세 번째 카드 다음 위치'),
      mode: 'saved-inline-third',
    },
    my_perks_inline_1: {
      screenTitle: t('admin.ads.preview.spec.my.title', 'My'),
      screenSubtitle: t('admin.ads.preview.spec.my.subtitle', '계정/혜택 화면'),
      placementLabel: t('admin.ads.preview.spec.my.placement', '계정 카드 아래'),
      mode: 'my-inline',
    },
  }
}

function buildFallbackConfig(slotKey: string) {
  if (slotKey === 'save_complete_sheet_1') {
    return {
      slotLabel: 'Save Complete Sheet 1',
      slotDescription: '저장 완료 직후 노출되는 bottom sheet 광고 슬롯',
      placementNote: '저장 완료 직후 요약 아래 · 88px',
      maxHeight: 88,
      screen: 'save_complete',
      position: 'after_summary_before_actions',
      tone: 'benefit_native',
      title: '',
      message: '',
      ctaLabel: null,
      targetUrl: null,
      imageUrl: null,
      reservedTitle: '',
      reservedMessage: '',
      reservedCtaLabel: null,
      reservedTargetUrl: null,
      reservedImageUrl: null,
      exposureStartAt: '2026-03-25T09:00',
      exposureEndAt: '2026-03-31T23:00',
      reservationStartAt: null,
      reservationEndAt: null,
      liveCampaignId: null,
      reservedCampaignId: null,
    } satisfies SlotConfig
  }
  if (slotKey === 'saved_inline_1') {
    return {
      slotLabel: 'Saved Inline 1',
      slotDescription: 'Saved 리스트 첫 카드 뒤에 들어가는 inline 광고 슬롯',
      placementNote: 'Saved 리스트 첫 카드 뒤 · 104px',
      maxHeight: 104,
      screen: 'saved_list',
      position: 'after_first_card',
      tone: 'benefit_native',
      title: '',
      message: '',
      ctaLabel: null,
      targetUrl: null,
      imageUrl: null,
      reservedTitle: '다음 주 저장 카트 혜택',
      reservedMessage: '예약 캠페인용 보조 문구를 미리 세팅해두는 영역이야.',
      reservedCtaLabel: '다음 혜택 보기',
      reservedTargetUrl: null,
      reservedImageUrl: null,
      exposureStartAt: null,
      exposureEndAt: null,
      reservationStartAt: '2026-04-01T09:00',
      reservationEndAt: '2026-04-07T23:00',
      liveCampaignId: null,
      reservedCampaignId: null,
    } satisfies SlotConfig
  }
  if (slotKey === 'saved_inline_2') {
    return {
      slotLabel: 'Saved Inline 2',
      slotDescription: 'Saved 리스트 세 번째 카드 뒤에 들어가는 inline 광고 슬롯',
      placementNote: 'Saved 리스트 세 번째 카드 뒤 · 104px',
      maxHeight: 104,
      screen: 'saved_list',
      position: 'after_third_card',
      tone: 'benefit_native',
      title: '',
      message: '',
      ctaLabel: null,
      targetUrl: null,
      imageUrl: null,
      reservedTitle: '',
      reservedMessage: '',
      reservedCtaLabel: null,
      reservedTargetUrl: null,
      reservedImageUrl: null,
      exposureStartAt: null,
      exposureEndAt: null,
      reservationStartAt: null,
      reservationEndAt: null,
      liveCampaignId: null,
      reservedCampaignId: null,
    } satisfies SlotConfig
  }
  return {
    slotLabel: 'My Perks Inline 1',
    slotDescription: 'My 화면 계정 카드 아래에 들어가는 inline 광고 슬롯',
    placementNote: 'My 화면 계정 카드 아래 · 96px',
    maxHeight: 96,
    screen: 'my',
    position: 'below_account_card',
    tone: 'soft_promo',
    title: '',
    message: '',
    ctaLabel: null,
    targetUrl: null,
    imageUrl: null,
    reservedTitle: '',
    reservedMessage: '',
    reservedCtaLabel: null,
    reservedTargetUrl: null,
    reservedImageUrl: null,
    exposureStartAt: null,
    exposureEndAt: null,
    reservationStartAt: null,
    reservationEndAt: null,
    liveCampaignId: null,
    reservedCampaignId: null,
  } satisfies SlotConfig
}

const fallbackSlots: SlotRow[] = mockSlots.map((slot) => ({
  ...slot,
  config: buildFallbackConfig(slot.slotKey),
}))

function formatScheduleLabel(value?: string | null) {
  if (!value) return '-'
  return value.replace('T', ' ')
}

function campaignStatusLabel(status: string) {
  switch (status) {
    case 'live':
      return '지난 라이브'
    case 'ended':
      return '종료됨'
    case 'scheduled':
      return '예약됨'
    case 'cancelled':
      return '취소됨'
    default:
      return status || '-'
  }
}

function overlapsPeriod(campaign: CampaignRow, periodFrom: string, periodTo: string) {
  if (!periodFrom && !periodTo) return true
  const rangeStart = periodFrom ? new Date(`${periodFrom}T00:00:00`) : null
  const rangeEnd = periodTo ? new Date(`${periodTo}T23:59:59`) : null
  const campaignStart = campaign.startAt ? new Date(campaign.startAt) : campaign.createdAt ? new Date(campaign.createdAt) : null
  const campaignEnd = campaign.endAt ? new Date(campaign.endAt) : campaign.createdAt ? new Date(campaign.createdAt) : null
  if (rangeStart && campaignEnd && campaignEnd < rangeStart) return false
  if (rangeEnd && campaignStart && campaignStart > rangeEnd) return false
  return true
}

function SlotEditorPanel({
  title,
  description,
  slot,
  variant,
  uploading,
  saving,
  onSlotChange,
  onConfigChange,
  onUpload,
  onSave,
}: {
  title: string
  description: string
  slot: SlotRow
  variant: 'live' | 'reserved'
  uploading: boolean
  saving: boolean
  onSlotChange: (patch: Partial<SlotRow>) => void
  onConfigChange: (patch: Partial<SlotConfig>) => void
  onUpload: (file: File) => void
  onSave: () => void
}) {
  const { t } = useAdminCopy()
  const isLive = variant === 'live'
  const currentTitle = isLive ? slot.config.title : (slot.config.reservedTitle ?? '')
  const currentMessage = isLive ? slot.config.message : (slot.config.reservedMessage ?? '')
  const currentCta = isLive ? (slot.config.ctaLabel ?? '') : (slot.config.reservedCtaLabel ?? '')
  const currentLink = isLive ? (slot.config.targetUrl ?? '') : (slot.config.reservedTargetUrl ?? '')
  const currentImage = isLive ? slot.config.imageUrl : slot.config.reservedImageUrl

  return (
    <div className="slotContentCard">
      <div className="sectionHeader" style={{ marginBottom: 14 }}>
        <div>
          <h3 className="panelTitle" style={{ marginBottom: 6 }}>{title}</h3>
          <p className="pageDesc">{description}</p>
        </div>
      </div>

      <div className="formGrid slotContentBody">
        {isLive ? (
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.fields.status', '상태')}</div>
            <select className="textInput" value={slot.status} onChange={(e) => onSlotChange({ status: e.target.value })}>
              <option value="active">active</option>
              <option value="inactive">inactive</option>
            </select>
          </label>
        ) : null}

        {isLive ? (
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.fields.slotLabel', '슬롯 이름')}</div>
            <input className="textInput" value={slot.config.slotLabel ?? ''} onChange={(e) => onConfigChange({ slotLabel: e.target.value })} />
          </label>
        ) : null}

        {isLive ? (
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.fields.slotDescription', '슬롯 설명')}</div>
            <textarea className="textInput" rows={3} value={slot.config.slotDescription ?? ''} onChange={(e) => onConfigChange({ slotDescription: e.target.value })} />
          </label>
        ) : null}

        {isLive ? (
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.fields.placementNote', '노출 위치 설명')}</div>
            <input className="textInput" value={slot.config.placementNote ?? ''} onChange={(e) => onConfigChange({ placementNote: e.target.value })} />
          </label>
        ) : null}

        <label className="field">
          <div className="fieldLabel">{t('admin.ads.fields.title', '제목')}</div>
          <input className="textInput" value={currentTitle} onChange={(e) => onConfigChange(isLive ? { title: e.target.value } : { reservedTitle: e.target.value })} />
        </label>

        <label className="field">
          <div className="fieldLabel">{t('admin.ads.fields.message', '문구')}</div>
          <textarea className="textInput" rows={3} value={currentMessage} onChange={(e) => onConfigChange(isLive ? { message: e.target.value } : { reservedMessage: e.target.value })} />
        </label>

        <label className="field">
          <div className="fieldLabel">{t('admin.ads.fields.cta', 'CTA')}</div>
          <input className="textInput" value={currentCta} onChange={(e) => onConfigChange(isLive ? { ctaLabel: e.target.value || null } : { reservedCtaLabel: e.target.value || null })} />
        </label>

        <label className="field">
          <div className="fieldLabel">{t('admin.ads.fields.link', '링크')}</div>
          <input className="textInput" value={currentLink} placeholder="https://..." onChange={(e) => onConfigChange(isLive ? { targetUrl: e.target.value || null } : { reservedTargetUrl: e.target.value || null })} />
        </label>

        <div className="scheduleEditorCard">
          <div className="fieldLabel">{isLive ? t('admin.ads.fields.exposureWindow', '노출 기간') : t('admin.ads.fields.reservationWindow', '예약 기간')}</div>
          <div className="scheduleGrid">
            <label className="field">
              <div className="scheduleFieldLabel">{isLive ? t('admin.ads.fields.exposureStart', '노출 시작') : t('admin.ads.fields.reservationStart', '예약 시작')}</div>
              <input
                type="datetime-local"
                className="textInput"
                value={isLive ? (slot.config.exposureStartAt ?? '') : (slot.config.reservationStartAt ?? '')}
                onChange={(e) => onConfigChange(isLive ? { exposureStartAt: e.target.value || null } : { reservationStartAt: e.target.value || null })}
              />
            </label>
            <label className="field">
              <div className="scheduleFieldLabel">{isLive ? t('admin.ads.fields.exposureEnd', '노출 종료') : t('admin.ads.fields.reservationEnd', '예약 종료')}</div>
              <input
                type="datetime-local"
                className="textInput"
                value={isLive ? (slot.config.exposureEndAt ?? '') : (slot.config.reservationEndAt ?? '')}
                onChange={(e) => onConfigChange(isLive ? { exposureEndAt: e.target.value || null } : { reservationEndAt: e.target.value || null })}
              />
            </label>
          </div>
        </div>

        <label className="field">
          <div className="fieldLabel">{t('admin.ads.fields.assetUpload', '배너 업로드')}</div>
          <label className="uploadBox">
            <input
              type="file"
              accept=".png,.jpg,.jpeg,.webp,.svg,image/png,image/jpeg,image/webp,image/svg+xml"
              className="hiddenInput"
              onChange={(e) => {
                const file = e.target.files?.[0]
                if (file) onUpload(file)
              }}
            />
            <div className="uploadTitle">{t('admin.ads.fields.assetSelect', '배너 파일 선택')}</div>
            <div className="uploadDesc">
              {uploading
                ? t('admin.ads.uploading', '업로드 중...')
                : isLive
                  ? t('admin.ads.fields.liveAssetDesc', '현재 노출 배너 자산')
                  : t('admin.ads.fields.reservedAssetDesc', '예약용 배너 자산')}
            </div>
          </label>
          {currentImage ? <div className="saveMessage">{t('admin.ads.fields.connected', '연결됨:')} {currentImage}</div> : null}
        </label>
      </div>

      {currentImage ? (
        <div className="section" style={{ marginTop: 16 }}>
          <img src={currentImage} alt={`${slot.slotKey} ${variant} banner`} className="logoPreview" style={{ width: '100%', maxHeight: 220, objectFit: 'cover' }} />
        </div>
      ) : null}

      <div className="buttonRow slotPanelSaveRow">
        <button className="primaryBtn slotPanelSaveBtn" disabled={saving} onClick={onSave}>
          {saving ? t('admin.ads.saving', '저장 중...') : isLive ? t('admin.ads.livePanel.save', '현재 광고 저장') : t('admin.ads.reservedPanel.save', '예약 광고 저장')}
        </button>
      </div>
    </div>
  )
}

function SlotPreview({ slot }: { slot: SlotRow }) {
  const { t } = useAdminCopy()
  const preview = buildSlotPreviewSpecs(t)[slot.slotKey]

  if (!preview) {
    return (
      <div className="slotPreviewCard">
        <div className="slotPreviewMeta">
          <div className="slotPreviewTitle">{t('admin.ads.preview.title', '노출 위치 미리보기')}</div>
          <div className="slotPreviewText">{t('admin.ads.preview.empty', '이 슬롯용 미리보기가 아직 준비되지 않았어')}</div>
        </div>
      </div>
    )
  }

  return (
    <div className="slotPreviewCard">
      <div className="slotPreviewMeta">
        <div className="slotPreviewTitle">{t('admin.ads.preview.title', '노출 위치 미리보기')}</div>
        <div className="slotPreviewText">{preview.screenTitle} · {preview.screenSubtitle}</div>
        <div className="metaRow" style={{ marginTop: 10 }}>
          <div className="metaPill">{slot.config.screen}</div>
          <div className="metaPill">{preview.placementLabel}</div>
        </div>
        <div className="slotScheduleSummary">
          <div className="slotScheduleLine">
            <span>노출</span>
            <strong>{formatScheduleLabel(slot.config.exposureStartAt)} → {formatScheduleLabel(slot.config.exposureEndAt)}</strong>
          </div>
          <div className="slotScheduleLine">
            <span>예약</span>
            <strong>{formatScheduleLabel(slot.config.reservationStartAt)} → {formatScheduleLabel(slot.config.reservationEndAt)}</strong>
          </div>
        </div>
      </div>

      <div className="slotPreviewFrame">
        <div className="slotPreviewPhone">
          <div className="slotPreviewPhoneHeader">
            <div className="slotPreviewPhoneTitle">{preview.screenTitle}</div>
            <div className="slotPreviewPhoneSub">{preview.screenSubtitle}</div>
          </div>
          <div className="slotPreviewCanvas">
            {preview.mode === 'save-complete-sheet' ? (
              <>
                <div className="slotPreviewBlock tall" />
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewHighlight sheet">{t('admin.ads.preview.adSlot', 'AD SLOT')}</div>
                <div className="slotPreviewActions">
                  <div className="slotPreviewActionBtn" />
                  <div className="slotPreviewActionBtn ghost" />
                </div>
              </>
            ) : null}
            {preview.mode === 'saved-inline-first' ? (
              <>
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewHighlight inline">AD SLOT</div>
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewBlock medium" />
              </>
            ) : null}
            {preview.mode === 'saved-inline-third' ? (
              <>
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewHighlight inline">AD SLOT</div>
                <div className="slotPreviewBlock medium" />
              </>
            ) : null}
            {preview.mode === 'my-inline' ? (
              <>
                <div className="slotPreviewBlock tall" />
                <div className="slotPreviewHighlight inline soft">AD SLOT</div>
                <div className="slotPreviewBlock medium" />
                <div className="slotPreviewBlock medium" />
              </>
            ) : null}
          </div>
        </div>
      </div>
    </div>
  )
}

function SlotHistory({
  campaigns,
  variantFilter,
  statusFilter,
  query,
  periodFrom,
  periodTo,
}: {
  campaigns: CampaignRow[]
  variantFilter: 'all' | 'live' | 'reserved'
  statusFilter: 'all' | 'ended' | 'cancelled' | 'scheduled' | 'live'
  query: string
  periodFrom: string
  periodTo: string
}) {
  const { t } = useAdminCopy()
  const trimmedQuery = query.trim().toLowerCase()
  const filtered = campaigns.filter((campaign) => {
    if (variantFilter !== 'all' && campaign.variant !== variantFilter) return false
    if (statusFilter !== 'all' && campaign.status !== statusFilter) return false
    if (!overlapsPeriod(campaign, periodFrom, periodTo)) return false
    if (!trimmedQuery) return true
    return [campaign.title, campaign.message, campaign.ctaLabel, campaign.slotKey].filter(Boolean).some((value) => String(value).toLowerCase().includes(trimmedQuery))
  })

  if (filtered.length === 0) {
    return <div className="emptyState" style={{ marginTop: 16 }}>{t('admin.ads.history.empty', '조건에 맞는 지난 광고가 없어')}</div>
  }

  return (
    <div className="tableWrap">
      <table className="dataTable">
        <thead>
          <tr>
            <th>{t('admin.ads.history.table.title', '광고명')}</th>
            <th>{t('admin.ads.history.table.variant', '유형')}</th>
            <th>{t('admin.ads.history.table.status', '상태')}</th>
            <th>{t('admin.ads.history.table.period', '기간')}</th>
            <th>{t('admin.ads.history.table.impressions', 'Impressions')}</th>
            <th>{t('admin.ads.history.table.clicks', 'Clicks')}</th>
            <th>{t('admin.ads.history.table.ctr', 'CTR')}</th>
            <th>{t('admin.ads.history.table.image', '이미지')}</th>
            <th>{t('admin.ads.history.table.download', '다운로드')}</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map((campaign) => (
            <tr key={campaign.id}>
              <td data-label={t('admin.ads.history.table.title', '광고명')}>
                <div style={{ fontWeight: 800 }}>{campaign.title || '(제목 없음)'}</div>
                <div className="adHistoryCellSub">{campaign.message || t('admin.ads.history.noMessage', '메시지 없음')}</div>
              </td>
              <td data-label={t('admin.ads.history.table.variant', '유형')}>{campaign.variant === 'live' ? t('admin.ads.history.variant.live', '현재 광고 이력') : t('admin.ads.history.variant.reserved', '예약 광고 이력')}</td>
              <td data-label={t('admin.ads.history.table.status', '상태')}>{campaignStatusLabel(campaign.status)}</td>
              <td data-label={t('admin.ads.history.table.period', '기간')}>{formatDate(campaign.startAt)} ~ {formatDate(campaign.endAt)}</td>
              <td data-label={t('admin.ads.history.table.impressions', 'Impressions')}>{formatNumber(campaign.impressions)}</td>
              <td data-label={t('admin.ads.history.table.clicks', 'Clicks')}>{formatNumber(campaign.clicks)}</td>
              <td data-label={t('admin.ads.history.table.ctr', 'CTR')}>{formatPercent(campaign.ctr)}</td>
              <td data-label={t('admin.ads.history.table.image', '이미지')}>{campaign.imageUrl ? <a href={campaign.imageUrl} target="_blank" rel="noreferrer">보기</a> : '-'}</td>
              <td data-label={t('admin.ads.history.table.download', '다운로드')}>
                <a className="ghostBtn pageActionBtn" href={`/api/wimc-admin/admin/ads/campaigns/${campaign.id}/export.xlsx`}>
                  {t('admin.ads.history.downloadSingle', 'Excel 다운로드')}
                </a>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default function AdsPage() {
  const router = useRouter()
  const { t } = useAdminCopy()
  const [slots, setSlots] = useState<SlotRow[]>(fallbackSlots)
  const [campaigns, setCampaigns] = useState<CampaignRow[]>([])
  const [usingFallback, setUsingFallback] = useState(true)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savingKey, setSavingKey] = useState<string | null>(null)
  const [uploadingKey, setUploadingKey] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [historyVariantFilter, setHistoryVariantFilter] = useState<'all' | 'live' | 'reserved'>('all')
  const [historyStatusFilter, setHistoryStatusFilter] = useState<'all' | 'ended' | 'cancelled' | 'scheduled' | 'live'>('all')
  const [historyQuery, setHistoryQuery] = useState('')
  const [historyPeriodFrom, setHistoryPeriodFrom] = useState('')
  const [historyPeriodTo, setHistoryPeriodTo] = useState('')

  const activeSlots = useMemo(() => slots.filter((slot) => slot.status === 'active').length, [slots])
  const campaignsBySlot = useMemo(
    () => campaigns.reduce<Record<string, CampaignRow[]>>((acc, campaign) => {
      if (!acc[campaign.slotKey]) acc[campaign.slotKey] = []
      acc[campaign.slotKey].push(campaign)
      return acc
    }, {}),
    [campaigns],
  )

  async function loadCampaigns() {
    try {
      const params = new URLSearchParams({ limit: '300' })
      if (historyQuery.trim()) params.set('query', historyQuery.trim())
      if (historyVariantFilter !== 'all') params.set('variant', historyVariantFilter)
      if (historyStatusFilter !== 'all') params.set('status', historyStatusFilter)
      if (historyPeriodFrom) params.set('periodFrom', historyPeriodFrom)
      if (historyPeriodTo) params.set('periodTo', historyPeriodTo)
      const res = await fetchJsonSafe<{ ok: boolean; data: { campaigns: CampaignRow[] } }>(`/admin/ads/campaigns?${params.toString()}`, { ok: true, data: { campaigns: [] } })
      setCampaigns(res.data.data.campaigns)
    } catch (err) {
      if (isUnauthorizedError(err)) router.replace('/login?reason=expired')
    }
  }

  async function loadSlots() {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchJsonSafe<{ ok: boolean; data: { slots: SlotRow[] } }>('/admin/ads/slots', { ok: true, data: { slots: fallbackSlots } })
      setSlots(res.data.data.slots)
      setUsingFallback(res.usingFallback)
      await loadCampaigns()
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setError(err instanceof Error ? err.message : '광고 슬롯을 불러오지 못했어')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void loadSlots()
  }, [])

  useEffect(() => {
    if (!loading) void loadCampaigns()
  }, [historyQuery, historyVariantFilter, historyStatusFilter, historyPeriodFrom, historyPeriodTo])

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
      await loadCampaigns()
      setMessage(`${slot.slotKey} ${variant === 'live' ? t('admin.ads.history.variant.live', '현재 광고 이력') : t('admin.ads.history.variant.reserved', '예약 광고 이력')} 저장 완료`)
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
        setMessage(`${slotKey} ${field === 'imageUrl' ? t('admin.ads.upload.liveDone', '현재') : t('admin.ads.upload.reservedDone', '예약')} ${t('admin.ads.upload.doneSuffix', '배너 업로드 완료')}`)
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

  const exportParams = new URLSearchParams()
  if (historyQuery.trim()) exportParams.set('query', historyQuery.trim())
  if (historyVariantFilter !== 'all') exportParams.set('variant', historyVariantFilter)
  if (historyStatusFilter !== 'all') exportParams.set('status', historyStatusFilter)
  if (historyPeriodFrom) exportParams.set('periodFrom', historyPeriodFrom)
  if (historyPeriodTo) exportParams.set('periodTo', historyPeriodTo)
  const bulkExportHref = `/api/wimc-admin/admin/ads/campaigns/export.xlsx${exportParams.toString() ? `?${exportParams.toString()}` : ''}`

  return (
    <div>
      <PageHeader
        badge={usingFallback ? 'Fallback data' : loading ? 'Loading...' : 'Live data'}
        title={t('admin.ads.title', 'Ads')}
        description={t('admin.ads.desc', '광고 슬롯과 배너 자산 관리')}
        onRefresh={() => void loadSlots()}
        refreshing={loading}
      />

      {error ? <div className="loginError" style={{ marginBottom: 16 }}>{error}</div> : null}
      {message ? <div className="saveMessage" style={{ marginBottom: 16 }}>{message}</div> : null}

      <div className="kpiGrid">
        <StatCard label="Slots" value={`${slots.length}`} />
        <StatCard label="Active" value={`${activeSlots}`} />
        <StatCard label="Inactive" value={`${slots.length - activeSlots}`} />
        <StatCard label="Campaigns" value={`${campaigns.length}`} />
      </div>

      <form className="card" style={{ marginTop: 16, marginBottom: 16 }} onSubmit={(e) => e.preventDefault()}>
        <div className="sectionHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.ads.filters.title', '지난 광고 필터')}</h2>
            <p className="pageDesc">{t('admin.ads.filters.desc', '유형/상태/검색어와 기간으로 지난 광고를 좁혀보고, 같은 조건으로 일괄 다운로드')}</p>
          </div>
        </div>
        <div className="sectionGrid" style={{ gridTemplateColumns: '2fr 1fr 1fr 1fr 1fr' }}>
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.filters.search', '검색')}</div>
            <input className="textInput" value={historyQuery} onChange={(e) => setHistoryQuery(e.target.value)} placeholder="광고 제목, 문구, CTA" />
          </label>
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.filters.variant', '유형')}</div>
            <select className="textInput" value={historyVariantFilter} onChange={(e) => setHistoryVariantFilter(e.target.value as 'all' | 'live' | 'reserved')}>
              <option value="all">{t('admin.ads.filters.option.all', '전체')}</option>
              <option value="live">{t('admin.ads.history.variant.live', '현재 광고 이력')}</option>
              <option value="reserved">{t('admin.ads.history.variant.reserved', '예약 광고 이력')}</option>
            </select>
          </label>
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.filters.status', '상태')}</div>
            <select className="textInput" value={historyStatusFilter} onChange={(e) => setHistoryStatusFilter(e.target.value as 'all' | 'ended' | 'cancelled' | 'scheduled' | 'live')}>
              <option value="all">{t('admin.ads.filters.option.all', '전체')}</option>
              <option value="ended">{t('admin.ads.status.ended', '종료됨')}</option>
              <option value="cancelled">{t('admin.ads.status.cancelled', '취소됨')}</option>
              <option value="scheduled">{t('admin.ads.status.scheduled', '예약됨')}</option>
              <option value="live">{t('admin.ads.filters.option.live', '라이브')}</option>
            </select>
          </label>
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.filters.periodFrom', '시작일')}</div>
            <input className="textInput" type="date" value={historyPeriodFrom} onChange={(e) => setHistoryPeriodFrom(e.target.value)} />
          </label>
          <label className="field">
            <div className="fieldLabel">{t('admin.ads.filters.periodTo', '종료일')}</div>
            <input className="textInput" type="date" value={historyPeriodTo} onChange={(e) => setHistoryPeriodTo(e.target.value)} />
          </label>
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 16, flexWrap: 'wrap' }}>
          <a className="ghostBtn pageActionBtn" href={bulkExportHref}>{t('admin.ads.filters.bulkExport', '기간내 지난광고 Excel 일괄 다운로드')}</a>
        </div>
      </form>

      <div className="section sectionGrid">
        {slots.map((slot) => {
          const slotCampaigns = (campaignsBySlot[slot.slotKey] ?? []).filter((campaign) => campaign.id !== slot.config.liveCampaignId && campaign.id !== slot.config.reservedCampaignId)
          return (
            <div className="card" key={slot.slotKey}>
              <div className="sectionHeader">
                <div>
                  <h2 className="panelTitle" style={{ marginBottom: 6 }}>{slot.config.slotLabel || slot.slotKey}</h2>
                  <p className="pageDesc" style={{ marginBottom: 8 }}>{slot.config.slotDescription || '슬롯 설명 없음'}</p>
                  <div className="metaRow" style={{ marginTop: 0 }}>
                    <div className="metaPill">{slot.slotKey}</div>
                    <div className="metaPill">{slot.placementType}</div>
                    <div className="metaPill">{slot.config.screen}</div>
                    <div className="metaPill">{slot.config.position}</div>
                    <div className="metaPill">{slot.config.placementNote || '-'}</div>
                  </div>
                </div>
                <div className="metaRow" style={{ marginTop: 0 }}>
                  <div className="metaPill">updated {formatDate(slot.updatedAt ?? slot.createdAt)}</div>
                </div>
              </div>

              <div className="slotEditorLayout">
                <SlotEditorPanel
                  title={t('admin.ads.livePanel.title', '현재 노출 광고')}
                  description={t('admin.ads.livePanel.desc', '현재 앱에 노출 중인 광고 설정')}
                  slot={slot}
                  variant="live"
                  uploading={uploadingKey === `${slot.slotKey}:imageUrl`}
                  saving={savingKey === `${slot.slotKey}:live`}
                  onSlotChange={(patch) => updateSlot(slot.slotKey, patch)}
                  onConfigChange={(patch) => updateConfig(slot.slotKey, patch)}
                  onUpload={(file) => void uploadAsset(slot.slotKey, file, 'imageUrl')}
                  onSave={() => void saveSlot(slot, 'live')}
                />
                <SlotEditorPanel
                  title={t('admin.ads.reservedPanel.title', '예약 광고 세팅')}
                  description={t('admin.ads.reservedPanel.desc', '다음 노출 순서를 미리 준비하는 예약 광고 설정')}
                  slot={slot}
                  variant="reserved"
                  uploading={uploadingKey === `${slot.slotKey}:reservedImageUrl`}
                  saving={savingKey === `${slot.slotKey}:reserved`}
                  onSlotChange={(patch) => updateSlot(slot.slotKey, patch)}
                  onConfigChange={(patch) => updateConfig(slot.slotKey, patch)}
                  onUpload={(file) => void uploadAsset(slot.slotKey, file, 'reservedImageUrl')}
                  onSave={() => void saveSlot(slot, 'reserved')}
                />
                <SlotPreview slot={slot} />
              </div>

              <div className="section" style={{ marginTop: 18 }}>
                <div className="sectionHeader" style={{ marginBottom: 12 }}>
                  <div>
                    <h3 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.ads.history.title', '지난 광고 데이터')}</h3>
                    <p className="pageDesc">{t('admin.ads.history.desc', '이 슬롯에 연결되었던 지난 광고 성과 기록')}</p>
                  </div>
                </div>
                <SlotHistory
                  campaigns={slotCampaigns}
                  variantFilter={historyVariantFilter}
                  statusFilter={historyStatusFilter}
                  query={historyQuery}
                  periodFrom={historyPeriodFrom}
                  periodTo={historyPeriodTo}
                />
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
