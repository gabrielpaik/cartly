'use client'

import { useEffect, useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson, putJson } from '../../lib/api'
import { csvTextFromObjects, downloadCsv, readCsvObjects } from '../../lib/csv'
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

type PushScheduleDto = {
  enabled: boolean
  cadence: 'weekly' | string
  weekday: 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun' | string
  time: string
  timezone: string
  kind: 'notice' | 'promotion' | string
  audience: 'all' | 'members' | 'guests' | string
  title: string
  message: string
  targetTab: 'home' | 'explore' | 'my' | null
  targetUrl: string | null
  segment?: PushRegionSegment | null
  updatedAt?: string | null
  updatedBy?: string | null
  updatedBySource?: string | null
  lastDispatchSlotKey?: string | null
  lastDispatchedAt?: string | null
  lastDispatchCampaignId?: string | null
  lastDispatchStatus?: string | null
  lastDispatchError?: string | null
  nextDispatchAt?: string | null
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

const SCHEDULE_WEEKDAY_LABELS: Record<string, string> = {
  mon: '월',
  tue: '화',
  wed: '수',
  thu: '목',
  fri: '금',
  sat: '토',
  sun: '일',
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

function scheduleLabel(schedule: Pick<PushScheduleDto, 'weekday' | 'time' | 'timezone'>) {
  return `매주 ${SCHEDULE_WEEKDAY_LABELS[schedule.weekday] ?? schedule.weekday} ${schedule.time} (${schedule.timezone})`
}

function targetLabel(campaign: Pick<PushCampaignDto, 'targetTab' | 'targetUrl'>) {
  if (campaign.targetUrl) return campaign.targetUrl
  if (campaign.targetTab === 'home') return '홈'
  if (campaign.targetTab === 'explore') return '탐색'
  if (campaign.targetTab === 'my') return '마이'
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
      return '기기 오류'
    case 'token_missing':
      return '토큰 없음'
    case 'notifications_off':
      return '알림 꺼짐'
    case 'inactive':
      return '비활성'
    default:
      return '준비'
  }
}

function uploadIssueLabel(issue: AudiencePreviewRow['issue']) {
  switch (issue) {
    case 'not_found':
      return '대상 없음'
    case 'token_missing':
      return '토큰 없음'
    case 'notifications_off':
      return '알림 꺼짐'
    case 'invalid':
      return '기기 오류'
    case 'inactive':
      return '비활성'
    default:
      return '준비'
  }
}

function campaignAudienceLabel(value: string) {
  switch (value) {
    case 'members':
      return '회원'
    case 'guests':
      return '게스트'
    case 'upload':
      return '직접 업로드'
    default:
      return '전체'
  }
}

function campaignKindLabel(value: string) {
  switch (value) {
    case 'promotion':
      return '혜택'
    case 'notice':
      return '공지'
    default:
      return value || '-'
  }
}

function campaignStatusLabel(value: string) {
  switch (value) {
    case 'sent':
      return '발송 완료'
    case 'failed':
      return '실패'
    case 'partial_failure':
      return '부분 실패'
    case 'blocked':
      return '차단'
    case 'no_targets':
      return '대상 없음'
    case 'draft':
      return '임시저장'
    default:
      return value || '-'
  }
}

function deviceStatusLabel(value: string) {
  switch (value) {
    case 'active':
      return '활성'
    case 'inactive':
      return '비활성'
    case 'invalid':
      return '오류'
    default:
      return value || '-'
  }
}

function blockerLabel(value: string) {
  switch (value) {
    case 'push_not_ready':
      return '푸시 준비 필요'
    case 'token_missing':
      return '토큰 없음'
    case 'notifications_off':
      return '알림 꺼짐'
    case 'invalid_device':
      return '기기 오류'
    case 'no_active_devices':
      return '활성 기기 없음'
    default:
      return value || '-'
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
  const scheduleRes = useAdminData<{ ok: boolean; data: PushScheduleDto }>('/admin/push/schedule', {
    ok: true,
    data: mockPushAdmin.schedule as PushScheduleDto,
  })

  const status = statusRes.data.data
  const devices = devicesRes.data.data.devices
  const campaigns = campaignsRes.data.data.campaigns
  const schedule = scheduleRes.data.data

  const [kind, setKind] = useState<'notice' | 'promotion'>('notice')
  const [audienceMode, setAudienceMode] = useState<AudienceMode>('all')
  const [targetTab, setTargetTab] = useState<'home' | 'explore' | 'my' | ''>('home')
  const [targetUrl, setTargetUrl] = useState('')
  const [title, setTitle] = useState('')
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [sendMessage, setSendMessage] = useState<string | null>(null)
  const [scheduleSaving, setScheduleSaving] = useState(false)
  const [scheduleMessage, setScheduleMessage] = useState<string | null>(null)
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
  const [scheduleEnabled, setScheduleEnabled] = useState(false)
  const [scheduleWeekday, setScheduleWeekday] = useState<PushScheduleDto['weekday']>('fri')
  const [scheduleTime, setScheduleTime] = useState('18:30')
  const [scheduleAudience, setScheduleAudience] = useState<'all' | 'members' | 'guests'>('all')
  const [scheduleKind, setScheduleKind] = useState<'notice' | 'promotion'>('promotion')
  const [scheduleTargetTab, setScheduleTargetTab] = useState<'home' | 'explore' | 'my' | ''>('home')
  const [scheduleTargetUrl, setScheduleTargetUrl] = useState('')
  const [scheduleTitle, setScheduleTitle] = useState('이번 주말 장보기')
  const [scheduleBody, setScheduleBody] = useState('이번주말 카트리로 쇼핑 어때요?')

  const loading = statusRes.loading || devicesRes.loading || campaignsRes.loading || scheduleRes.loading
  const usingFallback = statusRes.usingFallback || devicesRes.usingFallback || campaignsRes.usingFallback || scheduleRes.usingFallback
  const activeDeviceCount = status.devices.active
  const tokenReadyCount = status.devices.tokenReady
  const pushReady = status.ready && tokenReadyCount > 0
  const selectedPreset = selectedPresetIndex != null ? PRESETS[selectedPresetIndex] ?? null : null
  const districtOptions = useMemo(() => (regionPickerCity ? regionOptionsForLevel('district', regionPickerCity) as KoreaRegionOption[] : []), [regionPickerCity])
  const neighborhoodOptions = useMemo(() => (regionPickerCity ? regionOptionsForLevel('neighborhood', regionPickerCity, regionPickerDistrict) as KoreaRegionOption[] : []), [regionPickerCity, regionPickerDistrict])
  const pickerOptions = useMemo(() => {
    if (regionLevel === 'city') return KOREA_CITIES as KoreaRegionOption[]
    if (regionLevel === 'district') return districtOptions
    return neighborhoodOptions
  }, [districtOptions, neighborhoodOptions, regionLevel])

  useEffect(() => {
    setScheduleEnabled(Boolean(schedule.enabled))
    setScheduleWeekday((schedule.weekday as PushScheduleDto['weekday']) || 'fri')
    setScheduleTime(schedule.time || '18:30')
    setScheduleAudience((schedule.audience as 'all' | 'members' | 'guests') || 'all')
    setScheduleKind((schedule.kind as 'notice' | 'promotion') || 'promotion')
    setScheduleTargetTab((schedule.targetTab as 'home' | 'explore' | 'my' | null) ?? 'home')
    setScheduleTargetUrl(schedule.targetUrl || '')
    setScheduleTitle(schedule.title || '이번 주말 장보기')
    setScheduleBody(schedule.message || '이번주말 카트리로 쇼핑 어때요?')
  }, [schedule])

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
    setSendMessage(`최근 발송 "${campaign.title}" 불러오기 완료`)
  }

  async function downloadAudienceTemplate() {
    setSendMessage(null)
    try {
      const csvText = csvTextFromObjects([
        { userId: '11111111-1111-1111-1111-111111111111', installId: '', name: '홍길동', memo: 'VIP 재안내' },
        { userId: '', installId: 'cartly-install-abc', name: '', memo: '설치 기준 타겟' },
      ], {
        headers: ['userId', 'installId', 'name', 'memo'],
        commentLines: [
          '필수 항목: userId 또는 installId 중 하나 입력',
          '선택 항목: name, memo',
          '주의: push token 제외, 사용자 또는 설치 식별자만 입력',
        ],
      })
      downloadCsv('cartly-push-audience-template.csv', csvText)
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
      if (!/\.csv$/i.test(file.name)) {
        throw new Error('CSV 파일만 업로드할 수 있어')
      }
      const rows = await readCsvObjects(file)
      const entries = buildUploadedAudienceEntries(rows)
      if (entries.length === 0) {
        throw new Error('업로드 대상 행 없음')
      }
      const response = await postJson<{ ok: boolean; data: AudiencePreviewResponse }>('/admin/push/audience-preview', { entries })
      setAudienceMode('upload')
      setSelectedPresetIndex(null)
      setUploadedAudienceEntries(entries)
      setAudiencePreview(response.data)
      setSendMessage(`직접 업로드 ${entries.length}행 분석 완료, 준비 기기 ${response.data.summary.readyDevices}`)
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
      setSendMessage(`세그먼트 미리보기 완료, 이용자 ${response.data.summary.readyUserCount}, 기기 ${response.data.summary.readyDeviceCount}`)
    } catch (error) {
      setSegmentPreview(null)
      setSendMessage(error instanceof Error ? error.message : '세그먼트 미리보기 실패')
    } finally {
      setSegmentPreviewLoading(false)
    }
  }

  async function sendPush() {
    if (!title.trim() || !message.trim()) {
      setSendMessage('제목과 본문 입력 필요')
      return
    }
    if (audienceMode === 'upload' && uploadedAudienceEntries.length === 0) {
      setSendMessage('직접 업로드 파일 선택 필요')
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
        const invalidated = delivery.invalidatedCount ? `, 만료 정리 ${delivery.invalidatedCount}` : ''
        setSendMessage(`발송 완료. 성공 ${delivery.sentCount}, 실패 ${delivery.failureCount}, 상태 ${campaignStatusLabel(delivery.status)}${invalidated}`)
      } else {
        setSendMessage(`저장 완료. 상태 ${campaignStatusLabel(response.data.campaign.status)}`)
      }
      await Promise.allSettled([statusRes.reload(), devicesRes.reload(), campaignsRes.reload(), scheduleRes.reload()])
    } catch (error) {
      setSendMessage(error instanceof Error ? error.message : '푸시 발송 실패')
    } finally {
      setSending(false)
    }
  }

  function copyComposerToSchedule() {
    setScheduleTitle(title.trim() || '이번 주말 장보기')
    setScheduleBody(message.trim() || '이번주말 카트리로 쇼핑 어때요?')
    setScheduleAudience((audienceMode === 'upload' ? 'all' : audienceMode) as 'all' | 'members' | 'guests')
    setScheduleKind(kind)
    setScheduleTargetTab(targetTab || '')
    setScheduleTargetUrl(targetUrl.trim())
    setScheduleMessage('즉시 발송 내용을 예약 발송에 복사 완료')
  }

  async function saveSchedule() {
    if (!scheduleTitle.trim() || !scheduleBody.trim()) {
      setScheduleMessage('예약 푸시도 제목과 본문이 필요해')
      return
    }
    setScheduleSaving(true)
    setScheduleMessage(null)
    try {
      const response = await putJson<{ ok: boolean; data: PushScheduleDto }>('/admin/push/schedule', {
        enabled: scheduleEnabled,
        weekday: scheduleWeekday,
        time: scheduleTime || '18:30',
        timezone: 'Asia/Seoul',
        kind: scheduleKind,
        audience: scheduleAudience,
        title: scheduleTitle.trim(),
        message: scheduleBody.trim(),
        targetTab: scheduleTargetTab || null,
        targetUrl: scheduleTargetUrl.trim() || null,
      })
      setScheduleMessage(`저장했어. ${scheduleLabel(response.data)} · next ${fmt(response.data.nextDispatchAt)}`)
      await Promise.allSettled([scheduleRes.reload(), campaignsRes.reload()])
    } catch (error) {
      setScheduleMessage(error instanceof Error ? error.message : '예약 푸시 저장 실패')
    } finally {
      setScheduleSaving(false)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={usingFallback ? '대체 데이터' : loading ? '불러오는 중' : '실데이터'}
        title={'알림 운영'}
        description={'푸시 발송'}
        onRefresh={() => {
          void Promise.allSettled([statusRes.reload(), devicesRes.reload(), campaignsRes.reload(), scheduleRes.reload()])
        }}
        refreshing={loading}
      />

      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          푸시 상태를 실데이터로 못 읽었어. 발송 전에는 실데이터 여부를 먼저 확인해.
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">푸시 상태</div>
          <div className="exploreSummaryValue">{status.ready ? '준비' : '확인'}</div>
          <div className="exploreSummaryNote">{status.provider} · 프로젝트 {status.firebaseProjectId ?? '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">기기</div>
          <div className="exploreSummaryValue">{activeDeviceCount}</div>
          <div className="exploreSummaryNote">전체 {status.devices.total} · 오류 {status.devices.invalid ?? 0}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">발송 가능</div>
          <div className="exploreSummaryValue">{tokenReadyCount}</div>
          <div className="exploreSummaryNote">{pushReady ? '발송 준비' : '앱 수신 허용 필요'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">캠페인</div>
          <div className="exploreSummaryValue">{campaigns.length}</div>
          <div className="exploreSummaryNote">최근 상태 {campaignStatusLabel(campaigns[0]?.status ?? '-')}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">차단 요인</div>
          <div className="exploreSummaryValue">{status.blockers.length}</div>
          <div className="exploreSummaryNote">{status.blockers[0] ? blockerLabel(status.blockers[0]) : '없음'}</div>
        </div>
      </div>

      <div className="metaRow section" style={{ marginTop: 8 }}>
        <span className="metaPill">제공 {status.provider}</span>
        <span className="metaPill">프로젝트 {status.firebaseProjectId ?? '-'}</span>
        <span className="metaPill">준비 {status.ready ? '완료' : '확인'}</span>
        <span className="metaPill">발송 가능 {tokenReadyCount}</span>
        <span className="metaPill">오류 {status.devices.invalid ?? 0}</span>
        {platformSummary.map(([platform, count]) => (
          <span key={platform} className="metaPill">{platform} {count}</span>
        ))}
      </div>

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>정기 발송</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">{scheduleEnabled ? '사용' : '중지'}</span>
              <span className="metaPill">{scheduleLabel({ weekday: scheduleWeekday, time: scheduleTime || '18:30', timezone: 'Asia/Seoul' })}</span>
              <span className="metaPill">다음 {fmt(schedule.nextDispatchAt)}</span>
            </div>
          </div>

          <div className="exploreSheetFilterGrid compactFilterGrid" style={{ gridTemplateColumns: 'repeat(5, minmax(140px, 1fr))', marginTop: 8 }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">상태</div>
              <select className="textInput exploreSheetInput" value={scheduleEnabled ? 'enabled' : 'paused'} onChange={(event) => setScheduleEnabled(event.target.value === 'enabled')}>
                <option value="enabled">사용</option>
                <option value="paused">중지</option>
              </select>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">요일</div>
              <select className="textInput exploreSheetInput" value={scheduleWeekday} onChange={(event) => setScheduleWeekday(event.target.value as PushScheduleDto['weekday'])}>
                {Object.entries(SCHEDULE_WEEKDAY_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>{label}</option>
                ))}
              </select>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">시간</div>
              <input className="textInput exploreSheetInput" type="time" value={scheduleTime} onChange={(event) => setScheduleTime(event.target.value)} />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">유형</div>
              <select className="textInput exploreSheetInput" value={scheduleKind} onChange={(event) => setScheduleKind(event.target.value as 'notice' | 'promotion')}>
                <option value="promotion">혜택</option>
                <option value="notice">공지</option>
              </select>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">대상</div>
              <select className="textInput exploreSheetInput" value={scheduleAudience} onChange={(event) => setScheduleAudience(event.target.value as 'all' | 'members' | 'guests')}>
                <option value="all">전체</option>
                <option value="members">회원</option>
                <option value="guests">게스트</option>
              </select>
            </label>
          </div>

          <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(220px, 0.9fr) minmax(320px, 1.4fr) auto', alignItems: 'end', marginTop: 8 }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">예약 제목</div>
              <input className="textInput exploreSheetInput" value={scheduleTitle} onChange={(event) => setScheduleTitle(event.target.value)} placeholder="예: 이번 주말 장보기" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">예약 본문</div>
              <textarea className="textInput exploreSheetInput" value={scheduleBody} onChange={(event) => setScheduleBody(event.target.value)} placeholder="예: 이번주말 카트리로 쇼핑 어때요?" rows={3} />
            </label>
            <div style={{ display: 'grid', gap: 8 }}>
              <button className="primaryBtn pageActionBtn" type="button" onClick={() => void saveSchedule()} disabled={scheduleSaving}>
                {scheduleSaving ? '저장중' : '예약 저장'}
              </button>
              <button className="ghostBtn ghostBtnSmall" type="button" onClick={copyComposerToSchedule}>
                작성 내용 복사
              </button>
            </div>
          </div>

          <div className="exploreSheetFilterGrid compactFilterGrid" style={{ gridTemplateColumns: 'repeat(2, minmax(180px, 1fr))', marginTop: 8 }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">이동 탭</div>
              <select className="textInput exploreSheetInput" value={scheduleTargetTab} onChange={(event) => setScheduleTargetTab(event.target.value as 'home' | 'explore' | 'my' | '')}>
                <option value="">없음</option>
                <option value="home">홈</option>
                <option value="explore">탐색</option>
                <option value="my">마이</option>
              </select>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">이동 주소</div>
              <input className="textInput exploreSheetInput" value={scheduleTargetUrl} onChange={(event) => setScheduleTargetUrl(event.target.value)} placeholder="선택 입력, 이동 탭보다 우선" />
            </label>
          </div>

          <div className="metaRow" style={{ marginTop: 8 }}>
            <span className="metaPill">최근 발송 {fmt(schedule.lastDispatchedAt)}</span>
            <span className="metaPill">최근 상태 {schedule.lastDispatchStatus ? campaignStatusLabel(schedule.lastDispatchStatus) : '-'}</span>
            <span className="metaPill">캠페인 {schedule.lastDispatchCampaignId ?? '-'}</span>
            <span className="metaPill">수정 시각 {fmt(schedule.updatedAt)}</span>
          </div>
          {schedule.lastDispatchError ? (
            <div className="loginError" style={{ marginTop: 8, marginBottom: 0 }}>
              최근 발송 오류: {schedule.lastDispatchError}
            </div>
          ) : null}
          {scheduleMessage ? (
            <div className="loginError" style={{ marginTop: 8, marginBottom: 0, borderColor: '#d1d5db', background: '#f8fafc', color: '#0f172a' }}>
              {scheduleMessage}
            </div>
          ) : null}
        </div>
      </div>

      {!pushReady ? (
        <div className="loginError" style={{ marginTop: 8, marginBottom: 0 }}>
          지금은 실제 수신 기기가 부족해. 최신 앱에서 알림 허용까지 확인이 필요해.
          {status.blockers.length > 0 ? ` (${status.blockers.map(blockerLabel).join(', ')})` : ''}
        </div>
      ) : null}

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>즉시 발송</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">대상 {campaignAudienceLabel(audienceMode)}</div>
              <div className="metaPill">이동 {targetUrl.trim() || (targetTab ? targetLabel({ targetTab, targetUrl: null }) : '-')}</div>
              <div className="metaPill">서식 {PRESETS.length}</div>
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
              <strong style={{ fontSize: 12, color: '#111827' }}>선택 내용</strong>
              <span className="metaPill">{selectedPreset?.label ?? '직접 작성'}</span>
            </div>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">유형 {campaignKindLabel(kind)}</span>
              <span className="metaPill">대상 {campaignAudienceLabel(audienceMode)}</span>
              <span className="metaPill">이동 {targetUrl.trim() || (targetTab ? targetLabel({ targetTab, targetUrl: null }) : '-')}</span>
              {audienceMode === 'upload' && audiencePreview ? <span className="metaPill">업로드 준비 {audiencePreview.summary.readyDevices}</span> : null}
              {audienceMode !== 'upload' && regionSegmentMode !== 'none' ? <span className="metaPill">지역 {regionSummaryFromKeys(selectedRegionKeys)}</span> : null}
            </div>
            <div style={{ display: 'grid', gap: 4 }}>
              <strong style={{ fontSize: 13, color: '#111827' }}>{title.trim() || '제목 없음'}</strong>
              <span style={{ color: '#475569', fontSize: 12, whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{message.trim() || '본문 없음'}</span>
            </div>
          </div>

          <div style={{ display: 'grid', gap: 8 }}>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap' }}>
              <strong style={{ fontSize: 12, color: '#111827' }}>발송 대상</strong>
              {audienceMode === 'upload' && audiencePreview ? <span className="metaPill">행 {audiencePreview.summary.uploadedRows} · 준비 기기 {audiencePreview.summary.readyDevices}</span> : null}
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
                    {segmentPreviewLoading ? '불러오는 중' : '미리보기'}
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
                <span className="metaPill">최근 방문</span>
                <span className="metaPill">누적 방문</span>
                <span className="metaPill">대표 지역</span>
                {segmentPreview ? <span className="metaPill">미리보기 이용자 {segmentPreview.summary.readyUserCount} · 기기 {segmentPreview.summary.readyDeviceCount}</span> : null}
              </div>
            </div>
          ) : null}

          {audienceMode === 'upload' ? (
            <div style={{ display: 'grid', gap: 10, padding: '10px 12px', border: '1px solid #e6ebf1', borderRadius: 10, background: '#fff' }}>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap' }}>
                <strong style={{ fontSize: 12, color: '#111827' }}>직접 업로드 대상</strong>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => void downloadAudienceTemplate()}>
                    양식
                  </button>
                  <label className="ghostBtn ghostBtnSmall" style={{ width: 'auto', cursor: 'pointer' }}>
                    {uploadingAudience ? '분석 중...' : 'CSV 업로드'}
                    <input
                      type="file"
                      accept=".csv,text/csv"
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
                <span className="metaPill">서버 실기기 상태 재확인</span>
              </div>
              {audiencePreview ? (
                <>
                  <div className="exploreSummaryGrid" style={{ marginTop: 0 }}>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">업로드 행</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.uploadedRows}</div>
                      <div className="exploreSummaryNote">일치 {audiencePreview.summary.matchedRows}</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">준비 기기</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.readyDevices}</div>
                      <div className="exploreSummaryNote">일치 {audiencePreview.summary.matchedDevices}</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">대상 없음</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.notFoundRows}</div>
                      <div className="exploreSummaryNote">사용자·설치 미일치</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">토큰 없음</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.tokenMissingRows}</div>
                      <div className="exploreSummaryNote">발송 가능 대상 제외</div>
                    </div>
                    <div className="exploreSummaryCell">
                      <div className="exploreSummaryLabel">차단</div>
                      <div className="exploreSummaryValue">{audiencePreview.summary.notificationsOffRows + audiencePreview.summary.invalidRows + audiencePreview.summary.inactiveRows}</div>
                      <div className="exploreSummaryNote">알림 꺼짐 / 오류 / 비활성</div>
                    </div>
                  </div>

                  <div className="tableWrap" style={{ marginTop: 4 }}>
                    <table className="dataTable">
                      <thead>
                        <tr>
                          <th>업로드 대상</th>
                          <th>상태</th>
                          <th>일치</th>
                          <th>기기</th>
                          <th>최근 접속</th>
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
                <div className="emptyState" style={{ margin: 0 }}>CSV 업로드 후 발송 가능 모수 확인</div>
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
                {sending ? '발송중' : '지금 발송'}
              </button>
              <span className="metaPill">발송 가능 기기만 포함</span>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8, justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap' }}>
            <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setShowAdvanced((prev) => !prev)}>
              {showAdvanced ? '고급 편집 닫기' : '고급 편집'}
            </button>
            <span className="metaPill">기본 문구 우선, 세부 옵션 선택</span>
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
                  <option value="home">홈</option>
                  <option value="explore">탐색</option>
                  <option value="my">마이</option>
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
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>발송 기록</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">검색 결과 {filteredCampaigns.length}</div>
              <div className="metaPill">전체 {campaigns.length}</div>
              <div className="metaPill">다시 불러오기</div>
            </div>
          </div>

          <div style={{ display: 'grid', gap: 8 }}>
            <div className="editorSubtabRow">
              {([
                ['all', `전체 (${campaigns.length})`],
                ['sent', `발송 완료 (${campaigns.filter((item) => item.status === 'sent').length})`],
                ['failed', `실패 (${campaigns.filter((item) => ['failed', 'partial_failure', 'blocked', 'no_targets'].includes(item.status)).length})`],
                ['draft', `임시저장 (${campaigns.filter((item) => item.status === 'draft').length})`],
              ] as const).map(([value, label]) => (
                <button key={value} type="button" className={`editorSubtab ${campaignStatusFilter === value ? 'active' : ''}`} onClick={() => setCampaignStatusFilter(value)}>
                  {label}
                </button>
              ))}
            </div>
            <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(260px, 480px)' }}>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">검색</div>
                <input className="textInput exploreSheetInput" value={campaignQuery} onChange={(event) => setCampaignQuery(event.target.value)} placeholder="제목 / 본문 / 이동" />
              </label>
            </div>
          </div>

          {filteredCampaigns.length === 0 ? (
            <div className="emptyState" style={{ marginTop: 12 }}>조건에 맞는 발송 기록이 없어.</div>
          ) : (
            <div className="tableWrap" style={{ marginTop: 12 }}>
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>발송</th>
                    <th>대상</th>
                    <th>상태</th>
                    <th>최근 발송</th>
                    <th>불러오기</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredCampaigns.map((campaign) => (
                    <tr key={campaign.id}>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 260 }}>
                          <strong>{campaign.title}</strong>
                          <span style={{ color: '#475569', fontSize: 12, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{previewText(campaign.message, 96)}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>이동 {targetLabel(campaign)}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">{campaignAudienceLabel(campaign.audience)}</span>
                          <span className="metaPill">{campaignKindLabel(campaign.kind)}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <span className="metaPill">{campaignStatusLabel(campaign.status)}</span>
                          <span style={{ color: campaign.errorMessage ? '#9f1239' : '#64748b', fontSize: 12 }}>{campaign.errorMessage ?? campaign.deliveryProvider ?? '-'}</span>
                        </div>
                      </td>
                      <td>{fmt(campaign.sentAt ?? campaign.createdAt)}</td>
                      <td>
                        <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => reuseCampaign(campaign)}>
                          불러오기
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
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>발송 차단</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">검색 결과 {filteredDevices.length}</div>
              <div className="metaPill">준비 {deviceIssueSummary.ready}</div>
              <div className="metaPill">차단 {deviceIssueSummary.invalid + deviceIssueSummary.token_missing + deviceIssueSummary.notifications_off + deviceIssueSummary.inactive}</div>
            </div>
          </div>

          <div style={{ display: 'grid', gap: 8 }}>
            <div className="editorSubtabRow">
              {([
                ['blockers', `차단 (${deviceIssueSummary.invalid + deviceIssueSummary.token_missing + deviceIssueSummary.notifications_off + deviceIssueSummary.inactive})`],
                ['ready', `준비 (${deviceIssueSummary.ready})`],
                ['all', `전체 (${devices.length})`],
              ] as const).map(([value, label]) => (
                <button key={value} type="button" className={`editorSubtab ${deviceFilter === value ? 'active' : ''}`} onClick={() => setDeviceFilter(value)}>
                  {label}
                </button>
              ))}
            </div>
            <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(240px, 420px)' }}>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">기기 검색</div>
                <input className="textInput exploreSheetInput" value={deviceQuery} onChange={(event) => setDeviceQuery(event.target.value)} placeholder="기기 / 사용자 / 설치 / 버전" />
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
                    <th>기기</th>
                    <th>상태</th>
                    <th>연결</th>
                    <th>버전</th>
                    <th>최근 접속</th>
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
                            <span className="metaPill">{deviceStatusLabel(device.status)}</span>
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
                    <th>이름</th>
                    <th>전체 경로</th>
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
