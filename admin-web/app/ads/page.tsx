'use client'

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'

import { CampaignRow, fallbackSlots, SlotConfig, SlotEditorPanel, SlotHistory, SlotPreview, SlotRow } from '../../components/ads'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import PageHeader from '../../components/PageHeader'
import { fetchJsonSafe, isUnauthorizedError, postFormData, putJson } from '../../lib/api'
import { formatDate } from '../../lib/format'

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
  const [slotQuery, setSlotQuery] = useState('')
  const [slotStatusFilter, setSlotStatusFilter] = useState<'all' | 'active' | 'inactive'>('all')
  const [selectedSlotKey, setSelectedSlotKey] = useState<string | null>(null)

  const activeSlots = useMemo(() => slots.filter((slot) => slot.status === 'active').length, [slots])
  const liveCampaigns = useMemo(() => campaigns.filter((campaign) => campaign.variant === 'live').length, [campaigns])
  const reservedCampaigns = useMemo(() => campaigns.filter((campaign) => campaign.variant === 'reserved').length, [campaigns])
  const liveStatusCampaigns = useMemo(() => campaigns.filter((campaign) => campaign.status === 'live').length, [campaigns])
  const campaignsBySlot = useMemo(
    () => campaigns.reduce<Record<string, CampaignRow[]>>((acc, campaign) => {
      if (!acc[campaign.slotKey]) acc[campaign.slotKey] = []
      acc[campaign.slotKey].push(campaign)
      return acc
    }, {}),
    [campaigns],
  )
  const filteredSlots = useMemo(() => {
    const query = slotQuery.trim().toLowerCase()
    return slots.filter((slot) => {
      const matchesStatus = slotStatusFilter === 'all' ? true : slot.status === slotStatusFilter
      const haystacks = [slot.slotKey, slot.config.slotLabel, slot.config.slotDescription, slot.config.screen, slot.config.position, slot.placementType]
      const matchesQuery = !query || haystacks.filter(Boolean).some((value) => String(value).toLowerCase().includes(query))
      return matchesStatus && matchesQuery
    })
  }, [slotQuery, slotStatusFilter, slots])
  const selectedSlot = useMemo(() => {
    if (!selectedSlotKey) return filteredSlots[0] ?? null
    return slots.find((slot) => slot.slotKey === selectedSlotKey) ?? filteredSlots[0] ?? null
  }, [filteredSlots, selectedSlotKey, slots])
  const selectedSlotCampaigns = useMemo(() => {
    if (!selectedSlot) return []
    return (campaignsBySlot[selectedSlot.slotKey] ?? []).filter((campaign) => campaign.id !== selectedSlot.config.liveCampaignId && campaign.id !== selectedSlot.config.reservedCampaignId)
  }, [campaignsBySlot, selectedSlot])

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

  useEffect(() => {
    if (filteredSlots.length === 0) {
      if (selectedSlotKey !== null) setSelectedSlotKey(null)
      return
    }
    if (!selectedSlotKey || !filteredSlots.some((slot) => slot.slotKey === selectedSlotKey)) {
      setSelectedSlotKey(filteredSlots[0].slotKey)
    }
  }, [filteredSlots, selectedSlotKey])

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

  function openSlot(slotKey: string) {
    setSelectedSlotKey(slotKey)
    if (typeof window !== 'undefined') {
      window.setTimeout(() => {
        document.getElementById('selected-slot-editor')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }, 0)
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
  const bulkExportHref = `/api/cartly-admin/admin/ads/campaigns/export.xlsx${exportParams.toString() ? `?${exportParams.toString()}` : ''}`

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={usingFallback ? 'Fallback data' : loading ? 'Loading...' : 'Live data'}
        title={t('admin.ads.title', 'Ads')}
        description={t('admin.ads.desc', '광고 슬롯과 배너 자산 관리')}
        onRefresh={() => void loadSlots()}
        refreshing={loading}
      />

      {error ? <div className="loginError" style={{ marginBottom: 16 }}>{error}</div> : null}
      {message ? <div className="saveMessage" style={{ marginBottom: 16 }}>{message}</div> : null}
      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.ads.warning.fallbackTitle', 'Live ads data unavailable.')}</strong>{' '}
          {t('admin.ads.warning.fallbackBody', '지금 화면은 fallback/mock data일 수 있어서 슬롯 저장과 배너 업로드는 잠깐 막아둘게.')}
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Slots</div>
          <div className="exploreSummaryValue">{slots.length}</div>
          <div className="exploreSummaryNote">active {activeSlots} · inactive {slots.length - activeSlots}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Campaigns</div>
          <div className="exploreSummaryValue">{campaigns.length}</div>
          <div className="exploreSummaryNote">live {liveCampaigns} · reserved {reservedCampaigns}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Live status</div>
          <div className="exploreSummaryValue">{liveStatusCampaigns}</div>
          <div className="exploreSummaryNote">status=live rows</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Selected</div>
          <div className="exploreSummaryValue">{selectedSlot ? 1 : 0}</div>
          <div className="exploreSummaryNote">{selectedSlot?.slotKey ?? 'none'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Export scope</div>
          <div className="exploreSummaryValue">{historyQuery.trim() ? historyQuery.trim() : 'all'}</div>
          <div className="exploreSummaryNote">{historyVariantFilter} · {historyStatusFilter}</div>
        </div>
      </div>

      <div className="metaRow section" style={{ marginTop: 8 }}>
        <div className="metaPill">{t('admin.ads.meta.query', 'query')} {historyQuery.trim() || '-'}</div>
        <div className="metaPill">{t('admin.ads.meta.variant', 'variant')} {historyVariantFilter}</div>
        <div className="metaPill">{t('admin.ads.meta.status', 'status')} {historyStatusFilter}</div>
        <div className="metaPill">{t('admin.ads.meta.period', 'period')} {historyPeriodFrom || '-'} → {historyPeriodTo || '-'}</div>
        <div className="metaPill">{usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : t('admin.common.badge.live', 'Live data')}</div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard" style={{ marginTop: 16, marginBottom: 16 }}>
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>Slot inventory</h2>
            <p className="pageDesc" style={{ margin: 0 }}>slot, surface, live/reserved 상태를 먼저 표로 훑고 아래에서 깊게 수정하는 흐름으로 맞췄어.</p>
          </div>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <div className="metaPill">filtered {filteredSlots.length}</div>
            <div className="metaPill">all {slots.length}</div>
          </div>
        </div>
        <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(220px, 1fr) minmax(160px, 220px)' }}>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">slot 검색</div>
            <input className="textInput exploreSheetInput" value={slotQuery} onChange={(e) => setSlotQuery(e.target.value)} placeholder="slot / screen / position" />
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">status</div>
            <select className="textInput exploreSheetInput" value={slotStatusFilter} onChange={(e) => setSlotStatusFilter(e.target.value as 'all' | 'active' | 'inactive')}>
              <option value="all">all</option>
              <option value="active">active</option>
              <option value="inactive">inactive</option>
            </select>
          </label>
        </div>
        {filteredSlots.length === 0 ? (
          <div className="emptyState" style={{ marginTop: 12 }}>조건에 맞는 slot이 없어.</div>
        ) : (
          <div className="tableWrap" style={{ marginTop: 12 }}>
            <table className="dataTable">
              <thead>
                <tr>
                  <th>Slot</th>
                  <th>Surface</th>
                  <th>Status</th>
                  <th>Live / Reserved</th>
                  <th>Updated</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredSlots.map((slot) => {
                  const slotCampaigns = campaignsBySlot[slot.slotKey] ?? []
                  const liveCount = slotCampaigns.filter((campaign) => campaign.variant === 'live').length
                  const reservedCount = slotCampaigns.filter((campaign) => campaign.variant === 'reserved').length
                  const isSelected = selectedSlot?.slotKey === slot.slotKey
                  return (
                    <tr key={`inventory-${slot.slotKey}`} onClick={() => openSlot(slot.slotKey)} style={{ cursor: 'pointer', background: isSelected ? 'rgba(227, 24, 55, 0.06)' : undefined }}>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 220 }}>
                          <strong>{slot.config.slotLabel || slot.slotKey}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{slot.slotKey}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">{slot.config.screen}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{slot.config.position}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">{slot.status}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{slot.placementType}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">live {liveCount}</span>
                          <span className="metaPill">reserved {reservedCount}</span>
                        </div>
                      </td>
                      <td>{formatDate(slot.updatedAt ?? slot.createdAt)}</td>
                      <td>
                        <button className="ghostBtn ghostBtnSmall" type="button" onClick={(event) => { event.stopPropagation(); openSlot(slot.slotKey) }}>
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
      </div>

      <form className="card exploreDenseCard exploreSheetCard" style={{ marginTop: 12, marginBottom: 12 }} onSubmit={(e) => e.preventDefault()}>
        <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.ads.filters.title', '지난 광고 필터')}</h2>
            <p className="pageDesc">{t('admin.ads.filters.desc', '유형/상태/검색어와 기간으로 지난 광고를 좁혀보고, 같은 조건으로 일괄 다운로드')}</p>
          </div>
        </div>
        <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(220px, 2fr) repeat(4, minmax(140px, 1fr))' }}>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">{t('admin.ads.filters.search', '검색')}</div>
            <input className="textInput exploreSheetInput" value={historyQuery} onChange={(e) => setHistoryQuery(e.target.value)} placeholder="광고 제목, 문구, CTA" />
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">{t('admin.ads.filters.variant', '유형')}</div>
            <select className="textInput exploreSheetInput" value={historyVariantFilter} onChange={(e) => setHistoryVariantFilter(e.target.value as 'all' | 'live' | 'reserved')}>
              <option value="all">{t('admin.ads.filters.option.all', '전체')}</option>
              <option value="live">{t('admin.ads.history.variant.live', '현재 광고 이력')}</option>
              <option value="reserved">{t('admin.ads.history.variant.reserved', '예약 광고 이력')}</option>
            </select>
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">{t('admin.ads.filters.status', '상태')}</div>
            <select className="textInput exploreSheetInput" value={historyStatusFilter} onChange={(e) => setHistoryStatusFilter(e.target.value as 'all' | 'ended' | 'cancelled' | 'scheduled' | 'live')}>
              <option value="all">{t('admin.ads.filters.option.all', '전체')}</option>
              <option value="ended">{t('admin.ads.status.ended', '종료됨')}</option>
              <option value="cancelled">{t('admin.ads.status.cancelled', '취소됨')}</option>
              <option value="scheduled">{t('admin.ads.status.scheduled', '예약됨')}</option>
              <option value="live">{t('admin.ads.filters.option.live', '라이브')}</option>
            </select>
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">{t('admin.ads.filters.periodFrom', '시작일')}</div>
            <input className="textInput exploreSheetInput" type="date" value={historyPeriodFrom} onChange={(e) => setHistoryPeriodFrom(e.target.value)} />
          </label>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">{t('admin.ads.filters.periodTo', '종료일')}</div>
            <input className="textInput exploreSheetInput" type="date" value={historyPeriodTo} onChange={(e) => setHistoryPeriodTo(e.target.value)} />
          </label>
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <a className="ghostBtn pageActionBtn" href={bulkExportHref}>{t('admin.ads.filters.bulkExport', '기간내 지난광고 Excel 일괄 다운로드')}</a>
        </div>
      </form>

      {selectedSlot ? (
        <div className="card exploreDenseCard exploreSheetCard" id="selected-slot-editor">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{selectedSlot.config.slotLabel || selectedSlot.slotKey}</h2>
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
              <div className="metaPill">selected slot</div>
              <div className="metaPill">history {selectedSlotCampaigns.length}</div>
              <div className="metaPill">updated {formatDate(selectedSlot.updatedAt ?? selectedSlot.createdAt)}</div>
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
            <SlotPreview slot={selectedSlot} />
          </div>

          <div className="section" style={{ marginTop: 12 }}>
            <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
              <div>
                <h3 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.ads.history.title', '지난 광고 데이터')}</h3>
                <p className="pageDesc">{t('admin.ads.history.desc', '이 슬롯에 연결되었던 지난 광고 성과 기록')}</p>
              </div>
            </div>
            <SlotHistory
              campaigns={selectedSlotCampaigns}
              variantFilter={historyVariantFilter}
              statusFilter={historyStatusFilter}
              query={historyQuery}
              periodFrom={historyPeriodFrom}
              periodTo={historyPeriodTo}
            />
          </div>
        </div>
      ) : (
        <div className="emptyState">선택된 slot이 없어.</div>
      )}
    </div>
  )
}
