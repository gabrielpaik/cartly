'use client'

import { useAdminCopy } from './AdminCopyProvider'
import { formatDate, formatNumber, formatPercent } from '../lib/format'
import { mockSlots } from '../lib/mock'

export type SlotConfig = {
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

export type SlotRow = {
  id: string
  slotKey: string
  placementType: string
  status: string
  createdAt: string | null
  updatedAt: string | null
  config: SlotConfig
}

export type CampaignRow = {
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

export const fallbackSlots: SlotRow[] = mockSlots.map((slot) => ({
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

export function SlotEditorPanel({
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

export function SlotPreview({ slot }: { slot: SlotRow }) {
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

export function SlotHistory({
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
                <a className="ghostBtn pageActionBtn" href={`/api/cartly-admin/admin/ads/campaigns/${campaign.id}/export.xlsx`}>
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
