'use client'

import { useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson } from '../../lib/api'
import { KOREA_CITIES, regionOptionsForLevel, regionSummaryFromKeys, type RegionLevel } from '../../lib/koreaRegions'
import { mockPushAdmin } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type PushStatusDto = {
  enabled: boolean
  provider: string
  ready: boolean
  blockers: string[]
  firebaseProjectId: string | null
  devices: {
    total: number
    active: number
    invalid?: number
    tokenReady: number
  }
}

type PushDeviceDto = {
  id: string
  userId: string | null
  installId: string
  platform: string
  pushProvider: string | null
  hasPushToken: boolean
  notificationsEnabled: boolean
  status: string
  appVersion: string | null
  locale: string | null
  lastRegisteredAt: string | null
  lastSeenAt: string | null
  updatedAt: string | null
}

type PushRegionSegment = {
  mode: 'none' | 'recent' | 'frequent' | 'primary'
  regionKeys: string[]
  recentWithinDays?: number | null
  minVisits?: number | null
}

type PushCampaignDto = {
  id: string
  kind: 'notice' | 'promotion' | string
  audience: 'all' | 'members' | 'guests' | 'upload' | string
  status: string
  title: string
  message: string
  targetTab: 'home' | 'explore' | 'my' | null
  targetUrl: string | null
  requestedBy: string | null
  requestedBySource: string | null
  segment?: PushRegionSegment | null
  deliveryProvider: string | null
  errorMessage: string | null
  createdAt: string | null
  sentAt: string | null
}

type BroadcastResponse = {
  campaign: PushCampaignDto
  runtime: PushStatusDto
  delivery?: {
    sentCount: number
    failureCount: number
    invalidatedCount?: number
    status: string
  }
}

type AudienceMode = 'all' | 'members' | 'guests' | 'upload'
type RegionSegmentMode = 'none' | 'recent' | 'frequent' | 'primary'

type KoreaRegionOption = {
  key: string
  label: string
  fullLabel: string
  cityName?: string | null
  districtName?: string | null
}
type CampaignStatusFilter = 'all' | 'sent' | 'failed' | 'draft'
type DeviceFilter = 'blockers' | 'ready' | 'all'
type DeviceIssue = 'ready' | 'invalid' | 'token_missing' | 'notifications_off' | 'inactive'

type UploadedAudienceEntry = {
  userId?: string
  installId?: string
  name?: string
  memo?: string
}

type AudiencePreviewRow = {
  userId?: string | null
  installId?: string | null
  name?: string | null
  memo?: string | null
  issue: 'ready' | 'not_found' | 'token_missing' | 'notifications_off' | 'invalid' | 'inactive'
  matchedDeviceCount: number
  readyDeviceCount: number
  platforms: string[]
  lastSeenAt: string | null
}

type AudiencePreviewResponse = {
  summary: {
    uploadedRows: number
    matchedRows: number
    readyRows: number
    matchedDevices: number
    readyDevices: number
    notFoundRows: number
    tokenMissingRows: number
    notificationsOffRows: number
    invalidRows: number
    inactiveRows: number
  }
  rows: AudiencePreviewRow[]
}

type SegmentPreviewResponse = {
  audience: AudienceMode | string
  segment?: PushRegionSegment | null
  summary: {
    readyDeviceCount: number
    readyUserCount: number
  }
}

const PRESETS = [
  {
    label: '운영 공지',
    payload: {
      kind: 'notice' as const,
      audience: 'all' as const,
      title: 'Cartly 운영 안내',
      message: '지금 일부 기능을 점검하고 있어요. 잠시 뒤 다시 확인해 주세요.',
      targetTab: 'home' as const,
      targetUrl: '',
    },
  },
  {
    label: '영수증 등록 리마인드',
    payload: {
      kind: 'notice' as const,
      audience: 'all' as const,
      title: '영수증 등록을 잊지 마세요',
      message: '장보기가 끝났다면 저장한 카트에 영수증을 이어서 등록해 보세요.',
      targetTab: 'home' as const,
      targetUrl: '',
    },
  },
  {
    label: '혜택 알림',
    payload: {
      kind: 'promotion' as const,
      audience: 'members' as const,
      title: '지금 확인할 만한 혜택이 있어요',
      message: '탐색 탭에서 같은 구매 의도 기준으로 다시 비교해 보세요.',
      targetTab: 'explore' as const,
      targetUrl: '',
    },
  },
]

function fmt(value?: string | null) {
  if (!value) return '-'
  return value.replace('T', ' ').slice(0, 19)
}

function targetLabel(campaign: Pick<PushCampaignDto, 'targetTab' | 'targetUrl'>) {
  if (campaign.targetUrl) return campaign.targetUrl
  if (campaign.targetTab) return `tab:${campaign.targetTab}`
  return '-'
}

function previewText(value: string, max = 84) {
  const cleaned = value.replace(/\s+/g, ' ').trim()
  if (!cleaned) return '-'
  return cleaned.length > max ? `${cleaned.slice(0, max - 1)}…` : cleaned
}

function normalizeAudienceMode(value?: string | null): AudienceMode {
  if (value === 'members' || value === 'guests' || value === 'upload') return value
  return 'all'
}

function deviceIssue(device: PushDeviceDto): DeviceIssue {
  if (device.status !== 'active') return device.status === 'invalid' ? 'invalid' : 'inactive'
  if (!device.hasPushToken) return 'token_missing'
  if (!device.notificationsEnabled) return 'notifications_off'
  return 'ready'
}

function deviceIssueLabel(issue: DeviceIssue) {
  switch (issue) {
    case 'invalid':
      return 'invalid'
    case 'token_missing':
      return 'token missing'
    case 'notifications_off':
      return 'notifications off'
    case 'inactive':
      return 'inactive'
    default:
      return 'ready'
  }
}

function uploadIssueLabel(issue: AudiencePreviewRow['issue']) {
  switch (issue) {
    case 'not_found':
      return 'not found'
    case 'token_missing':
      return 'token missing'
    case 'notifications_off':
      return 'notifications off'
    case 'invalid':
      return 'invalid'
    case 'inactive':
      return 'inactive'
    default:
      return 'ready'
  }
}

function normalizeSheetValue(value: unknown) {
  return String(value ?? '').trim()
}

function buildUploadedAudienceEntries(rows: Record<string, unknown>[]) {
  const entries: UploadedAudienceEntry[] = []
  for (const row of rows) {
    const userId = normalizeSheetValue(row.userId ?? row.user_id ?? row.USER_ID ?? row['User ID'] ?? row['user id'])
    const installId = normalizeSheetValue(row.installId ?? row.install_id ?? row.INSTALL_ID ?? row['Install ID'] ?? row['install id'])
    const name = normalizeSheetValue(row.name ?? row.NAME ?? row['Name'] ?? row['이름'])
    const memo = normalizeSheetValue(row.memo ?? row.MEMO ?? row['Memo'] ?? row['메모'])
    if (!userId && !installId) continue
    entries.push({
      userId: userId || undefined,
      installId: installId || undefined,
      name: name || undefined,
      memo: memo || undefined,
    })
  }
  return entries
}

export default function PushPage() {
  const { t } = useAdminCopy()
  const statusRes = useAdminData<{ ok: boolean; data: PushStatusDto }>('/admin/push/status', {
    ok: true,
    data: mockPushAdmin.status,
  })
  const devicesRes = useAdminData<{ ok: boolean; data: { devices: PushDeviceDto[] } }>('/admin/push/devices', {
    ok: true,
    data: { devices: mockPushAdmin.devices },
  })
  const campaignsRes = useAdminData<{ ok: boolean; data: { campaigns: PushCampaignDto[] } }>('/admin/push/campaigns', {
    ok: true,
    data: { campaigns: mockPushAdmin.campaigns as PushCampaignDto[] },
  })

  const status = statusRes.data.data
  const devices = devicesRes.data.data.devices
  const campaigns = campaignsRes.data.data.campaigns

  const [kind, setKind] = useState<'notice' | 'promotion'>('notice')
  const [audienceMode, setAudienceMode] = useState<AudienceMode>('all')
  const [targetTab, setTargetTab] = useState<'home' | 'explore' | 'my' | ''>('home')
  const [targetUrl, setTargetUrl] = useState('')
  const [title, setTitle] = useState('')
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [sendMessage, setSendMessage] = useState<string | null>(null)
  const [selectedPresetIndex, setSelectedPresetIndex] = useState<number | null>(null)
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [campaignQuery, setCampaignQuery] = useState('')
  const [campaignStatusFilter, setCampaignStatusFilter] = useState<CampaignStatusFilter>('all')
  const [deviceQuery, setDeviceQuery] = useState('')
  const [deviceFilter, setDeviceFilter] = useState<DeviceFilter>('blockers')
  const [uploadingAudience, setUploadingAudience] = useState(false)
  const [uploadedAudienceEntries, setUploadedAudienceEntries] = useState<UploadedAudienceEntry[]>([])
  const [audiencePreview, setAudiencePreview] = useState<AudiencePreviewResponse | null>(null)
  const [regionSegmentMode, setRegionSegmentMode] = useState<RegionSegmentMode>('none')
  const [regionLevel, setRegionLevel] = useState<Exclude<RegionLevel, 'all'>>('district')
  const [selectedRegionKeys, setSelectedRegionKeys] = useState<string[]>([])
  const [regionRecentWithinDays, setRegionRecentWithinDays] = useState('30')
  const [regionVisitCountMin, setRegionVisitCountMin] = useState('3')
  const [segmentPreview, setSegmentPreview] = useState<SegmentPreviewResponse | null>(null)
  const [segmentPreviewLoading, setSegmentPreviewLoading] = useState(false)
  const [regionPickerOpen, setRegionPickerOpen] = useState(false)
  const [regionPickerDraftKeys, setRegionPickerDraftKeys] = useState<string[]>([])
  const [regionPickerCity, setRegionPickerCity] = useState('')
  const [regionPickerDistrict, setRegionPickerDistrict] = useState('')

  const loading = statusRes.loading || devicesRes.loading || campaignsRes.loading
  const usingFallback = statusRes.usingFallback || devicesRes.usingFallback || campaignsRes.usingFallback
  const activeDeviceCount = status.devices.active
  const tokenReadyCount = status.devices.tokenReady
  const pushReady = status.ready && tokenReadyCount > 0
  const selectedPreset = selectedPresetIndex != null ? PRESETS[selectedPresetIndex] ?? null : null
  const composerTarget = targetUrl.trim() || (targetTab ? `tab:${targetTab}` : '-')
  const districtOptions = useMemo(() => (regionPickerCity ? regionOptionsForLevel('district', regionPickerCity) as KoreaRegionOption[] : []), [regionPickerCity])
  const neighborhoodOptions = useMemo(() => (regionPickerCity ? regionOptionsForLevel('neighborhood', regionPickerCity, regionPickerDistrict) as KoreaRegionOption[] : []), [regionPickerCity, regionPickerDistrict])
  const pickerOptions = useMemo(() => {
    if (regionLevel === 'city') return KOREA_CITIES as KoreaRegionOption[]
    if (regionLevel === 'district') return districtOptions
    return neighborhoodOptions
  }, [districtOptions, neighborhoodOptions, regionLevel])

  function currentRegionSegmentPayload(): PushRegionSegment | null {
    if (regionSegmentMode === 'none' || selectedRegionKeys.length === 0) return null
    return {
      mode: regionSegmentMode,
      regionKeys: selectedRegionKeys,
      recentWithinDays: regionSegmentMode === 'recent' ? Number(regionRecentWithinDays || '30') : null,
      minVisits: regionSegmentMode === 'frequent' ? Number(regionVisitCountMin || '3') : null,
    }
  }

  function openRegionPicker() {
    setRegionPickerDraftKeys(selectedRegionKeys)
    setRegionPickerCity('')
    setRegionPickerDistrict('')
    setRegionPickerOpen(true)
  }

  function applyRegionPicker() {
    setSelectedRegionKeys([...regionPickerDraftKeys].sort())
    setRegionPickerOpen(false)
  }

  function toggleRegionDraftKey(key: string) {
    setRegionPickerDraftKeys((current) => current.includes(key) ? current.filter((item) => item !== key) : [...current, key].sort())
  }

  const platformSummary = useMemo(() => {
    const counts = new Map<string, number>()
    for (const device of devices) {
      counts.set(device.platform, (counts.get(device.platform) ?? 0) + 1)
    }
    return Array.from(counts.entries())
  }, [devices])

  const filteredCampaigns = useMemo(() => {
    const query = campaignQuery.trim().toLowerCase()
    return [...campaigns]
      .sort((a, b) => {
        const left = a.sentAt ?? a.createdAt ?? ''
        const right = b.sentAt ?? b.createdAt ?? ''
        return right.localeCompare(left)
      })
      .filter((campaign) => {
        const matchesStatus = campaignStatusFilter === 'all'
          ? true
          : campaignStatusFilter === 'failed'
            ? ['failed', 'partial_failure', 'blocked', 'no_targets'].includes(campaign.status)
            : campaign.status === campaignStatusFilter
        const haystacks = [campaign.title, campaign.message, campaign.kind, campaign.audience, campaign.status, campaign.targetTab, campaign.targetUrl]
        const matchesQuery = !query || haystacks.filter(Boolean).some((value) => String(value).toLowerCase().includes(query))
        return matchesStatus && matchesQuery
      })
  }, [campaigns, campaignQuery, campaignStatusFilter])

  const deviceIssueSummary = useMemo(() => {
    return devices.reduce<Record<DeviceIssue, number>>((acc, device) => {
      const issue = deviceIssue(device)
      acc[issue] += 1
      return acc
    }, { ready: 0, invalid: 0, token_missing: 0, notifications_off: 0, inactive: 0 })
  }, [devices])

  const filteredDevices = useMemo(() => {
    const query = deviceQuery.trim().toLowerCase()
    return devices.filter((device) => {
      const issue = deviceIssue(device)
      const matchesFilter = deviceFilter === 'all' ? true : deviceFilter === 'ready' ? issue === 'ready' : issue !== 'ready'
      const haystacks = [device.platform, device.userId, device.installId, device.status, device.appVersion, device.locale, issue]
      const matchesQuery = !query || haystacks.filter(Boolean).some((value) => String(value).toLowerCase().includes(query))
      return matchesFilter && matchesQuery
    })
  }, [devices, deviceFilter, deviceQuery])

  function applyPreset(index: number) {
    const preset = PRESETS[index]?.payload
    if (!preset) return
    setSelectedPresetIndex(index)
    setKind(preset.kind)
    setAudienceMode(normalizeAudienceMode(preset.audience))
    setTitle(preset.title)
    setMessage(preset.message)
    setTargetTab(preset.targetTab)
    setTargetUrl(preset.targetUrl)
    setSendMessage(null)
  }

  function reuseCampaign(campaign: PushCampaignDto) {
    setSelectedPresetIndex(null)
    setKind(campaign.kind === 'promotion' ? 'promotion' : 'notice')
    setAudienceMode(normalizeAudienceMode(campaign.audience))
    setTitle(campaign.title)
    setMessage(campaign.message)
    setTargetTab(campaign.targetTab ?? '')
    setTargetUrl(campaign.targetUrl ?? '')
    const segment = campaign.segment
    setRegionSegmentMode(segment?.mode ?? 'none')
    setSelectedRegionKeys(segment?.regionKeys ?? [])
    setRegionRecentWithinDays(String(segment?.recentWithinDays ?? 30))
    setRegionVisitCountMin(String(segment?.minVisits ?? 3))
    setSendMessage(`최근 캠페인 "${campaign.title}" 내용을 composer로 가져왔어`)
  }

  async function downloadAudienceTemplate() {
    setSendMessage(null)
    try {
      const XLSX = await import('xlsx')
      const workbook = XLSX.utils.book_new()
      const template = XLSX.utils.json_to_sheet([
        { userId: '11111111-1111-1111-1111-111111111111', installId: '', name: '홍길동', memo: 'VIP 재안내' },
        { userId: '', installId: 'cartly-install-abc', name: '', memo: '설치 기준 타겟' },
      ], { header: ['userId', 'installId', 'name', 'memo'] })
      template['!cols'] = [{ wch: 38 }, { wch: 28 }, { wch: 18 }, { wch: 28 }]
      XLSX.utils.book_append_sheet(workbook, template, 'Audience')
      const guide = XLSX.utils.aoa_to_sheet([
        ['기준'],
        ['필수 컬럼', 'userId 또는 installId 중 하나는 꼭 채워야 해'],
        ['선택 컬럼', 'name, memo'],
        ['주의', 'push token을 넣지 말고 사용자/설치 식별자만 넣어'],
      ])
      guide['!cols'] = [{ wch: 18 }, { wch: 68 }]
      XLSX.utils.book_append_sheet(workbook, guide, 'Guide')
      XLSX.writeFile(workbook, 'cartly-push-audience-template.xlsx')
      setSendMessage('직접 업로드 템플릿 다운로드 완료')
    } catch (error) {
      setSendMessage(error instanceof Error ? error.message : '템플릿 다운로드 실패')
    }
  }

  async function uploadAudienceSheet(file: File | null) {
    if (!file) return
    setUploadingAudience(true)
    setSendMessage(null)
    try {
      const XLSX = await import('xlsx')
      const workbook = XLSX.read(await file.arrayBuffer(), { type: 'array' })
      const firstSheetName = workbook.SheetNames[0]
      if (!firstSheetName) {
        throw new Error('첫 번째 시트를 찾지 못했어')
      }
      const worksheet = workbook.Sheets[firstSheetName]
      const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(worksheet, { defval: '' })
      const entries = buildUploadedAudienceEntries(rows)
      if (entries.length === 0) {
        throw new Error('업로드할 userId/installId 행이 없어')
      }
      const response = await postJson<{ ok: boolean; data: AudiencePreviewResponse }>('/admin/push/audience-preview', { entries })
      setAudienceMode('upload')
      setSelectedPresetIndex(null)
      setUploadedAudienceEntries(entries)
      setAudiencePreview(response.data)
      setSendMessage(`직접 업로드 ${entries.length}행 분석 완료, ready ${response.data.summary.readyDevices}기기`)
    } catch (error) {
      setUploadedAudienceEntries([])
      setAudiencePreview(null)
      setSendMessage(error instanceof Error ? error.message : '업로드 대상 분석 실패')
    } finally {
      setUploadingAudience(false)
    }
  }

  async function previewRegionSegment() {
    setSegmentPreviewLoading(true)
    setSendMessage(null)
    try {
      const response = await postJson<{ ok: boolean; data: SegmentPreviewResponse }>('/admin/push/segment-preview', {
        audience: audienceMode === 'upload' ? 'all' : audienceMode,
        segment: currentRegionSegmentPayload(),
      })
      setSegmentPreview(response.data)
      setSendMessage(`세그먼트 preview 완료, users ${response.data.summary.readyUserCount}, devices ${response.data.summary.readyDeviceCount}`)
    } catch (error) {
      setSegmentPreview(null)
      setSendMessage(error instanceof Error ? error.message : '세그먼트 preview 실패')
    } finally {
      setSegmentPreviewLoading(false)
    }
  }

  async function sendPush() {
    if (!title.trim() || !message.trim()) {
      setSendMessage('제목과 본문을 먼저 넣어줘')
      return
    }
    if (audienceMode === 'upload' && uploadedAudienceEntries.length === 0) {
      setSendMessage('직접 업로드 파일을 먼저 넣어줘')
      return
    }

    setSending(true)
    setSendMessage(null)
    try {
      const response = await postJson<{ ok: boolean; data: BroadcastResponse }>('/admin/push/broadcast', {
        kind,
        audience: audienceMode,
        title: title.trim(),
        message: message.trim(),
        targetTab: targetTab || null,
        targetUrl: targetUrl.trim() || null,
        explicitAudience: audienceMode === 'upload' ? uploadedAudienceEntries : undefined,
        segment: audienceMode === 'upload' ? undefined : currentRegionSegmentPayload(),
      })
      const delivery = response.data.delivery
      if (delivery) {
        const invalidated = delivery.invalidatedCount ? `, stale 정리 ${delivery.invalidatedCount}` : ''
        setSendMessage(`보냈어. success ${delivery.sentCount}, fail ${delivery.failureCount}, status ${delivery.status}${invalidated}`)
      } else {
        setSendMessage(`저장했어. status ${response.data.campaign.status}`)
      }
      await Promise.allSettled([statusRes.reload(), devicesRes.reload(), campaignsRes.reload()])
    } catch (error) {
      setSendMessage(error instanceof Error ? error.message : '푸시 발송에 실패했어')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.push.title', 'Push')}
        description={t('admin.push.desc', '운영 공지와 혜택 알림을 다루는 Growth operator surface')}
        onRefresh={() => {
          void Promise.allSettled([statusRes.reload(), devicesRes.reload(), campaignsRes.reload()])
        }}
        refreshing={loading}
      />

      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          live push 상태를 못 읽으면 fallback으로 보여줘. 실제 발송 전에는 live badge인지 한 번 확인하는 게 안전해.
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Push runtime</div>
          <div className="exploreSummaryValue">{status.ready ? 'READY' : 'CHECK'}</div>
          <div className="exploreSummaryNote">{status.provider} · project {status.firebaseProjectId ?? '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Devices</div>
          <div className="exploreSummaryValue">{activeDeviceCount}</div>
          <div className="exploreSummaryNote">전체 {status.devices.total} · invalid {status.devices.invalid ?? 0}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Token ready</div>
          <div className="exploreSummaryValue">{tokenReadyCount}</div>
          <div className="exploreSummaryNote">{pushReady ? 'send ready' : 'needs app opt-in'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Campaigns</div>
          <div className="exploreSummaryValue">{campaigns.length}</div>
          <div className="exploreSummaryNote">latest {campaigns[0]?.status ?? '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Blockers</div>
          <div className="exploreSummaryValue">{status.blockers.length}</div>
          <div className="exploreSummaryNote">{status.blockers[0] ?? 'clear'}</div>
        </div>
      </div>

      <div className="metaRow section" style={{ marginTop: 8 }}>
        <span className="metaPill">provider {status.provider}</span>
        <span className="metaPill">firebase {status.firebaseProjectId ?? '-'}</span>
        <span className="metaPill">ready {status.ready ? 'yes' : 'no'}</span>
        <span className="metaPill">token ready {tokenReadyCount}</span>
        <span className="metaPill">invalid {status.devices.invalid ?? 0}</span>
        {platformSummary.map(([platform, count]) => (
          <span key={platform} className="metaPill">{platform} {count}</span>
        ))}
      </div>

      {!pushReady ? (
        <div className="loginError" style={{ marginTop: 8, marginBottom: 0 }}>
          지금은 실제로 받을 수 있는 토큰이 부족해. 먼저 최신 앱에서 알림 허용까지 끝나야 send가 살아나.
          {status.blockers.length > 0 ? ` (${status.blockers.join(', ')})` : ''}
        </div>
      ) : null}

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Composer</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">audience {audienceMode}</div>
              <div className="metaPill">target {composerTarget}</div>
              <div className="metaPill">presets {PRESETS.length}</div>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 8 }}>
            {PRESETS.map((preset, index) => {
              const isActive = selectedPresetIndex === index
              return (
                <button
                  key={preset.label}
                  type="button"
                  className="ghostBtn ghostBtnSmall"
                  aria-pressed={isActive}
                  onClick={() => applyPreset(index)}
                  style={{
                    width: '100%',
                    padding: '10px 12px',
                    borderColor: isActive ? '#E31837' : undefined,
                    background: isActive ? '#E31837' : undefined,
                    color: isActive ? '#fff' : undefined,
                    boxShadow: 'none',
                  }}
                >
                  {preset.label}
                </button>
              )
            })}
          </div>

          <div style={{ display: 'grid', gap: 8, padding: '10px 12px', border: `1px solid ${selectedPreset ? '#f3c7cf' : '#e6ebf1'}`, borderRadius: 10, background: selectedPreset ? '#fff5f7' : '#f8fafc' }}>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap' }}>
              <strong style={{ fontSize: 12, color: '#111827' }}>선택 결과</strong>
              <span className="metaPill">{selectedPreset?.label ?? '직접 작성'}</span>
            </div>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">kind {kind}</span>
              <span className="metaPill">audience {audienceMode}</span>
              <span className="metaPill">target {composerTarget}</span>
              {audienceMode === 'upload' && audiencePreview ? <span className="metaPill">upload ready {audiencePreview.summary.readyDevices}</span> : null}
              {audienceMode !== 'upload' && regionSegmentMode !== 'none' ? <span className="metaPill">segment {regionSummaryFromKeys(selectedRegionKeys)}</span> : null}
            </div>
            <div style={{ display: 'grid', gap: 4 }}>
              <strong style={{ fontSize: 13, color: '#111827' }}>{title.trim() || '제목 없음'}</strong>
              <span style={{ color: '#475569', fontSize: 12, whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{message.trim() || '본문 없음'}</span>
            </div>
          </div>

          <div style={{ display: 'grid', gap: 8 }}>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap' }}>
              <strong style={{ fontSize: 12, color: '#111827' }}>발송 대상</strong>
              {audienceMode === 'upload' && audiencePreview ? <span className="metaPill">rows {audiencePreview.summary.uploadedRows} · ready devices {audiencePreview.summary.readyDevices}</span> : null}
            </div>
            <div className="editorSubtabRow" style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))' }}>
              {([
                ['all', '전체'],
                ['members', '회원'],
                ['guests', '게스트'],
                ['upload', '직접 업로드'],
              ] as const).map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  className={`editorSubtab ${audienceMode === value ? 'active' : ''}`}
                  onClick={() => setAudienceMode(value)}
                  style={audienceMode === value ? { background: '#E31837', borderColor: '#E31837' } : undefined}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>

          {audienceMode !== 'upload' ? (
            <div style={{ display: 'grid', gap: 10, padding: '10px 12px', border: '1px solid #e6ebf1', borderRadius: 10, background: '#fff' }}>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap' }}>
                <strong style={{ fontSize: 12, color: '#111827' }}>지역 리타게팅</strong>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <button type="button" className="ghostBtn ghostBtnSmall" onClick={openRegionPicker}>지역선택</button>
                  <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => void previewRegionSegment()} disabled={segmentPreviewLoading || regionSegmentMode === 'none' || selectedRegionKeys.length === 0}>
                    {segmentPreviewLoading ? 'preview...' : 'preview'}
                  </button>
                </div>
              </div>
              <div className="exploreSheetFilterGrid compactFilterGrid" style={{ gridTemplateColumns: 'repeat(4, minmax(160px, 1fr))' }}>
                <label className="field" style={{ margin: 0 }}>
                  <div className="exploreSheetFieldLabel">세그먼트 모드</div>
                  <select className="textInput exploreSheetInput" value={regionSegmentMode} onChange={(event) => setRegionSegmentMode(event.target.value as RegionSegmentMode)}>
                    <option value="none">안씀</option>
                    <option value="recent">최근 방문</option>
                    <option value="frequent">자주 방문</option>
                    <option value="primary">대표 활동지역</option>
                  </select>
                </label>
                <label className="field" style={{ margin: 0 }}>
                  <div className="exploreSheetFieldLabel">지역단위</div>
                  <select className="textInput exploreSheetInput" value={regionLevel} onChange={(event) => setRegionLevel(event.target.value as Exclude<RegionLevel, 'all'>)}>
                    <option value="city">시/도</option>
                    <option value="district">구/군/시</option>
                    <option value="neighborhood">동/읍/면</option>
                  </select>
                </label>
                <div className="field" style={{ margin: 0 }}>
                  <div className="exploreSheetFieldLabel">지역선택</div>
                  <div className="compactToggleCard"><span>{selectedRegionKeys.length === 0 ? '미선택' : regionSummaryFromKeys(selectedRegionKeys)}</span></div>
                </div>
                <label className="field" style={{ margin: 0 }}>
                  <div className="exploreSheetFieldLabel">기준</div>
                  {regionSegmentMode === 'recent' ? (
                    <select className="textInput exploreSheetInput" value={regionRecentWithinDays} onChange={(event) => setRegionRecentWithinDays(event.target.value)}>
                      <option value="7">7일</option>
                      <option value="30">30일</option>
                      <option value="90">90일</option>
                      <option value="180">180일</option>
                    </select>
                  ) : regionSegmentMode === 'frequent' ? (
                    <input className="textInput exploreSheetInput" inputMode="numeric" value={regionVisitCountMin} onChange={(event) => setRegionVisitCountMin(event.target.value)} placeholder=">= 3" />
                  ) : (
                    <div className="compactToggleCard"><span>{regionSegmentMode === 'primary' ? '최다 방문 기준' : '전체'}</span></div>
                  )}
                </label>
              </div>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">recent = 최근 기간 내 방문</span>
                <span className="metaPill">frequent = 누적 방문수 기준</span>
                <span className="metaPill">primary = 대표 활동지역 기준</span>
                {segmentPreview ? <span className="metaPill">preview users {segmentPreview.summary.readyUserCount} · devices {segmentPreview.summary.readyDeviceCount}</span> : null}
              </div>
            </div>
          ) : null}

          {audienceMode === 'upload' ? (
            <div style={{ display: 'grid', gap: 10, padding: '10px 12px', border: '1px solid #e6ebf1', borderRadius: 10, background: '#fff' }}>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap' }}>
                <strong style={{ fontSize: 12, color: '#111827' }}>직접 업로드 audience</strong>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => void downloadAudienceTemplate()}>
                    template
                  </button>
                  <label className="ghostBtn ghostBtnSmall" style={{ width: 'auto', cursor: 'pointer' }}>
                    {uploadingAudience ? '분석중...' : 'xlsx / csv 업로드'}
                    <input
                      type="file"
                      accept=".xlsx,.xls,.csv"
                      onChange={(event) => void uploadAudienceSheet(event.target.files?.[0] ?? null)}
                      style={{ display: 'none' }}
                      disabled={uploadingAudience}
                    />
                  </label>
                </div>
              </div>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">userId 또는 installId 필수</span>
                <span className="metaPill">push token 업로드 금지</span>
                <span className="metaPill">서버가 live device 상태로 재검증</span>
              </div>
              {audiencePreview ? (
                <>
                  <div className="exploreSummaryGrid" style={{ marginTop: 0 }}>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">Rows</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.uploadedRows}</div>
                      <div className="exploreSummaryNote">matched {audiencePreview.summary.matchedRows}</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">Ready devices</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.readyDevices}</div>
                      <div className="exploreSummaryNote">matched {audiencePreview.summary.matchedDevices}</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">Not found</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.notFoundRows}</div>
                      <div className="exploreSummaryNote">user/install 미매칭</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">Token missing</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.tokenMissingRows}</div>
                      <div className="exploreSummaryNote">ready 대상 제외</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">Blocked</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.notificationsOffRows + audiencePreview.summary.invalidRows + audiencePreview.summary.inactiveRows}</div>
                      <div className="exploreSummaryNote">notif off / invalid / inactive</div>
                    </div>
                  </div>

                  <div className="tableWrap" style={{ marginTop: 4 }}>
                    <table className="dataTable">
                      <thead>
                        <tr>
                          <th>Uploaded target</th>
                          <th>Issue</th>
                          <th>Matched</th>
                          <th>Platform</th>
                          <th>Last seen</th>
                        </tr>
                      </thead>
                      <tbody>
                        {audiencePreview.rows.slice(0, 8).map((row, index) => (
                          <tr key={`${row.userId ?? row.installId ?? 'row'}-${index}`}>
                            <td>
                              <div style={{ display: 'grid', gap: 4, minWidth: 220 }}>
                                <strong>{row.name || row.userId || row.installId || '-'}</strong>
                                <span style={{ color: '#64748b', fontSize: 12 }}>{row.userId ?? '-'}</span>
                                <span style={{ color: '#64748b', fontSize: 12 }}>{row.installId ?? row.memo ?? '-'}</span>
                              </div>
                            </td>
                            <td><span className="metaPill">{uploadIssueLabel(row.issue)}</span></td>
                            <td>{row.readyDeviceCount} / {row.matchedDeviceCount}</td>
                            <td>{row.platforms.join(', ') || '-'}</td>
                            <td>{fmt(row.lastSeenAt)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </>
              ) : (
                <div className="emptyState" style={{ margin: 0 }}>xlsx / csv를 올리면 실제 발송 가능 모수를 먼저 보여줄게.</div>
              )}
            </div>
          ) : null}

          <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(220px, 0.9fr) minmax(320px, 1.4fr) auto', alignItems: 'end' }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">제목</div>
              <input className="textInput exploreSheetInput" value={title} onChange={(event) => setTitle(event.target.value)} placeholder="예: Cartly 운영 안내" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">본문</div>
              <textarea className="textInput exploreSheetInput" value={message} onChange={(event) => setMessage(event.target.value)} placeholder="예: 지금 일부 기능을 점검하고 있어요." rows={3} />
            </label>
            <div style={{ display: 'grid', gap: 8 }}>
              <button className="primaryBtn pageActionBtn" type="button" onClick={() => void sendPush()} disabled={sending}>
                {sending ? '보내는 중...' : '지금 보내기'}
              </button>
              <span className="metaPill">token ready only</span>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8, justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap' }}>
            <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setShowAdvanced((prev) => !prev)}>
              {showAdvanced ? '고급 편집 닫기' : '고급 편집'}
            </button>
            <span className="metaPill">preset 후에는 제목/본문만 바로 수정, 세부 옵션은 필요할 때만</span>
          </div>

          {showAdvanced ? (
            <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">종류</div>
                <select className="textInput exploreSheetInput" value={kind} onChange={(event) => setKind(event.target.value as 'notice' | 'promotion')}>
                  <option value="notice">운영 공지</option>
                  <option value="promotion">혜택 알림</option>
                </select>
              </label>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">열릴 탭</div>
                <select className="textInput exploreSheetInput" value={targetTab} onChange={(event) => setTargetTab(event.target.value as 'home' | 'explore' | 'my' | '')}>
                  <option value="">없음</option>
                  <option value="home">home</option>
                  <option value="explore">explore</option>
                  <option value="my">my</option>
                </select>
              </label>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">딥링크 URL</div>
                <input className="textInput exploreSheetInput" value={targetUrl} onChange={(event) => setTargetUrl(event.target.value)} placeholder="https://..." />
              </label>
            </div>
          ) : null}

          {sendMessage ? <div className="saveMessage" style={{ marginBottom: 0 }}>{sendMessage}</div> : null}
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard" style={{ gridColumn: '1 / -1' }}>
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Campaign queue</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">filtered {filteredCampaigns.length}</div>
              <div className="metaPill">all {campaigns.length}</div>
              <div className="metaPill">reuse to composer</div>
            </div>
          </div>

          <div style={{ display: 'grid', gap: 8 }}>
            <div className="editorSubtabRow">
              {([
                ['all', `All (${campaigns.length})`],
                ['sent', `Sent (${campaigns.filter((item) => item.status === 'sent').length})`],
                ['failed', `Failed (${campaigns.filter((item) => ['failed', 'partial_failure', 'blocked', 'no_targets'].includes(item.status)).length})`],
                ['draft', `Draft (${campaigns.filter((item) => item.status === 'draft').length})`],
              ] as const).map(([value, label]) => (
                <button key={value} type="button" className={`editorSubtab ${campaignStatusFilter === value ? 'active' : ''}`} onClick={() => setCampaignStatusFilter(value)}>
                  {label}
                </button>
              ))}
            </div>
            <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(260px, 480px)' }}>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">검색</div>
                <input className="textInput exploreSheetInput" value={campaignQuery} onChange={(event) => setCampaignQuery(event.target.value)} placeholder="title / message / target" />
              </label>
            </div>
          </div>

          {filteredCampaigns.length === 0 ? (
            <div className="emptyState" style={{ marginTop: 12 }}>조건에 맞는 push campaign이 없어.</div>
          ) : (
            <div className="tableWrap" style={{ marginTop: 12 }}>
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>Campaign</th>
                    <th>Audience</th>
                    <th>Delivery</th>
                    <th>Last sent</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredCampaigns.map((campaign) => (
                    <tr key={campaign.id}>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 260 }}>
                          <strong>{campaign.title}</strong>
                          <span style={{ color: '#475569', fontSize: 12, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{previewText(campaign.message, 96)}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>target {targetLabel(campaign)}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">{campaign.audience}</span>
                          <span className="metaPill">{campaign.kind}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">{campaign.status}</span>
                          <span style={{ color: campaign.errorMessage ? '#9f1239' : '#64748b', fontSize: 12 }}>{campaign.errorMessage ?? campaign.deliveryProvider ?? '-'}</span>
                        </div>
                      </td>
                      <td>{fmt(campaign.sentAt ?? campaign.createdAt)}</td>
                      <td>
                        <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => reuseCampaign(campaign)}>
                          reuse
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard" style={{ gridColumn: '1 / -1' }}>
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Delivery blockers</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">filtered {filteredDevices.length}</div>
              <div className="metaPill">ready {deviceIssueSummary.ready}</div>
              <div className="metaPill">blockers {deviceIssueSummary.invalid + deviceIssueSummary.token_missing + deviceIssueSummary.notifications_off + deviceIssueSummary.inactive}</div>
            </div>
          </div>

          <div style={{ display: 'grid', gap: 8 }}>
            <div className="editorSubtabRow">
              {([
                ['blockers', `Blockers (${deviceIssueSummary.invalid + deviceIssueSummary.token_missing + deviceIssueSummary.notifications_off + deviceIssueSummary.inactive})`],
                ['ready', `Ready (${deviceIssueSummary.ready})`],
                ['all', `All (${devices.length})`],
              ] as const).map(([value, label]) => (
                <button key={value} type="button" className={`editorSubtab ${deviceFilter === value ? 'active' : ''}`} onClick={() => setDeviceFilter(value)}>
                  {label}
                </button>
              ))}
            </div>
            <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(240px, 420px)' }}>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">기기 검색</div>
                <input className="textInput exploreSheetInput" value={deviceQuery} onChange={(event) => setDeviceQuery(event.target.value)} placeholder="platform / user / install / version" />
              </label>
            </div>
          </div>

          {filteredDevices.length === 0 ? (
            <div className="emptyState" style={{ marginTop: 12 }}>조건에 맞는 기기가 없어.</div>
          ) : (
            <div className="tableWrap" style={{ marginTop: 12 }}>
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>Device</th>
                    <th>Issue</th>
                    <th>State</th>
                    <th>Version</th>
                    <th>Last seen</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredDevices.map((device) => {
                    const issue = deviceIssue(device)
                    return (
                      <tr key={device.id}>
                        <td>
                          <div style={{ display: 'grid', gap: 4, minWidth: 220 }}>
                            <strong>{device.platform}</strong>
                            <span style={{ color: '#64748b', fontSize: 12 }}>{device.userId ?? device.installId}</span>
                            <span style={{ color: '#64748b', fontSize: 12 }}>{device.locale ?? '-'}</span>
                          </div>
                        </td>
                        <td><span className="metaPill">{deviceIssueLabel(issue)}</span></td>
                        <td>
                          <div style={{ display: 'grid', gap: 4 }}>
                            <span className="metaPill">{device.status}</span>
                            <span style={{ color: '#64748b', fontSize: 12 }}>{device.pushProvider ?? '-'}</span>
                          </div>
                        </td>
                        <td>{device.appVersion ?? '-'}</td>
                        <td>{fmt(device.lastSeenAt ?? device.updatedAt ?? device.lastRegisteredAt)}</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {regionPickerOpen ? (
        <div className="sheetModalBackdrop" onClick={() => setRegionPickerOpen(false)}>
          <div className="sheetModalCard" style={{ width: 'min(960px, calc(100vw - 32px))' }} onClick={(event) => event.stopPropagation()}>
            <div className="sectionHeader exploreSheetHeader">
              <h2 className="panelTitle" style={{ marginBottom: 0 }}>푸시 지역 세그먼트 선택</h2>
              <div style={{ display: 'flex', gap: 8 }}>
                <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setRegionPickerDraftKeys([])}>전체해제</button>
                <button type="button" className="pageActionBtn" onClick={applyRegionPicker}>적용</button>
              </div>
            </div>
            <div className="exploreSheetFilterGrid compactFilterGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(180px, 1fr))', marginBottom: 12 }}>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">시/도</div>
                <select className="textInput exploreSheetInput" value={regionPickerCity} onChange={(event) => { setRegionPickerCity(event.target.value); setRegionPickerDistrict('') }}>
                  <option value="">선택</option>
                  {(KOREA_CITIES as KoreaRegionOption[]).map((option) => <option key={option.key} value={option.cityName ?? ''}>{option.label}</option>)}
                </select>
              </label>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">구/군/시</div>
                <select className="textInput exploreSheetInput" value={regionPickerDistrict} onChange={(event) => setRegionPickerDistrict(event.target.value)} disabled={regionLevel === 'city' || !regionPickerCity}>
                  <option value="">선택</option>
                  {districtOptions.map((option) => <option key={option.key} value={option.districtName ?? ''}>{option.label}</option>)}
                </select>
              </label>
              <div className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">선택 요약</div>
                <div className="compactToggleCard"><span>{selectedRegionKeys.length === 0 ? '미선택' : regionSummaryFromKeys(regionPickerDraftKeys)}</span></div>
              </div>
            </div>
            <div className="tableWrap" style={{ maxHeight: '52vh' }}>
              <table className="dataTable exploreDenseTable">
                <thead>
                  <tr>
                    <th style={{ width: 64 }}>선택</th>
                    <th>Label</th>
                    <th>Full</th>
                  </tr>
                </thead>
                <tbody>
                  {pickerOptions.length === 0 ? (
                    <tr><td colSpan={3}>먼저 상위 지역을 선택해줘</td></tr>
                  ) : pickerOptions.map((option) => (
                    <tr key={option.key}>
                      <td><input type="checkbox" checked={regionPickerDraftKeys.includes(option.key)} onChange={() => toggleRegionDraftKey(option.key)} /></td>
                      <td>{option.label}</td>
                      <td>{option.fullLabel}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
