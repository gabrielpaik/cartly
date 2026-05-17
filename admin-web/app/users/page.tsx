'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'
import * as XLSX from 'xlsx'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { formatDate, formatNumber } from '../../lib/format'
import { KOREA_CITIES, buildRegionKey, regionOptionsForLevel, regionSummaryFromKeys, type RegionLevel } from '../../lib/koreaRegions'
import { useAdminData } from '../../lib/useAdminData'

type UserRow = {
  id?: string
  displayName?: string | null
  email?: string | null
  provider?: string | null
  isGuest?: boolean | null
  guestCode?: string | null
  guestKey?: string | null
  createdAt?: string | null
  lastSeenAt?: string | null
  lastActiveAt?: string | null
  lastActivityAt?: string | null
  lastActivityType?: string | null
  lastDevicePlatform?: string | null
  lastAppVersion?: string | null
  cartCount?: number | null
  savedCartCount?: number | null
  sessionCount?: number | null
  scanCount?: number | null
  pushDeviceCount?: number | null
  readyPushDeviceCount?: number | null
  lastSavedAt?: string | null
  lastScanAt?: string | null
  status?: string | null
  mergedIntoUserId?: string | null
  lifecycleStage?: string | null
  lifecycleLabel?: string | null
  reachabilityState?: string | null
  reachabilityLabel?: string | null
  operatorAction?: string | null
  operatorActionLabel?: string | null
  daysSinceSeen?: number | null
  daysSinceCreated?: number | null
  primaryRegionKey?: string | null
  primaryRegionLabel?: string | null
  topRegionLabels?: string[] | null
  topRegionSummary?: string | null
  regionActivityCount?: number | null
  recentRegionCount30d?: number | null
  hasHousehold?: boolean | null
  householdId?: string | null
  householdName?: string | null
  householdRole?: string | null
  householdMemberCount?: number | null
  householdJoinedAt?: string | null
}

type KoreaRegionOption = {
  key: string
  label: string
  fullLabel: string
  cityName?: string | null
  districtName?: string | null
  neighborhoodName?: string | null
}

type UsersSummary = {
  filteredUsers?: number
  members?: number
  guests?: number
  readyPushUsers?: number
  totalSessions?: number
  totalScans?: number
  totalSavedCarts?: number
}

type LegacySummary = {
  count?: number
  withCarts?: number
  withoutCarts?: number
}

type AccountFilter = 'all' | 'member' | 'guest'
type ScanFilterOperator = 'gte' | 'lt'
type SegmentPreset = 'recent7' | 'recent30' | 'visit5' | 'scan10' | 'scanLow' | 'pushReady'
type RegionSegmentMode = 'none' | 'recent' | 'frequent' | 'primary'

const usersFallback = {
  summary: {
    filteredUsers: 0,
    members: 0,
    guests: 0,
    readyPushUsers: 0,
    totalSessions: 0,
    totalScans: 0,
    totalSavedCarts: 0,
  },
  users: [],
}

const legacyGuestsFallback = {
  summary: {
    count: 0,
    withCarts: 0,
    withoutCarts: 0,
  },
  users: [],
}

function displayUserName(user: UserRow) {
  if (user.isGuest && user.guestCode) return `Guest#${user.guestCode}`
  if (user.displayName?.trim()) return user.displayName
  if (user.email?.trim()) return user.email
  return user.id ?? '-'
}

function userTypeLabel(user: UserRow, t: (key: string, fallback?: string) => string) {
  return user.isGuest ? t('admin.users.type.guest', 'guest') : t('admin.users.type.member', 'member')
}

function providerLabel(user: UserRow) {
  if (user.isGuest) return 'guest'
  return user.provider?.trim() || '-'
}

function platformLabel(value: string | null | undefined) {
  return value?.trim() ? value.toUpperCase() : '-'
}

function savedCartCount(user: UserRow) {
  return user.savedCartCount ?? user.cartCount ?? 0
}

function cleanupLabel(user: UserRow) {
  if (!user.isGuest) return 'member'
  if (user.guestKey?.trim()) return 'normal guest'
  return savedCartCount(user) > 0 ? 'merge review' : 'archive candidate'
}

function parseOptionalNumber(value: string) {
  const trimmed = value.trim()
  if (!trimmed) return undefined
  const parsed = Number(trimmed)
  return Number.isFinite(parsed) ? Math.max(0, Math.floor(parsed)) : undefined
}

function regionFilterSummary(mode: RegionSegmentMode, keys: string[]) {
  if (mode === 'none') return '전체지역'
  if (keys.length === 0) return '지역 미선택'
  return regionSummaryFromKeys(keys)
}

function lifecycleTone(stage: string | null | undefined) {
  if (!stage) return '#475569'
  if (stage.includes('dormant')) return '#92400e'
  if (stage.includes('legacy')) return '#9f1239'
  if (stage.includes('core')) return '#1d4ed8'
  if (stage.includes('new')) return '#0f766e'
  return '#475569'
}

function reachabilityTone(state: string | null | undefined) {
  if (state === 'push_ready') return '#166534'
  if (state === 'push_blocked') return '#92400e'
  if (state === 'unreachable') return '#9f1239'
  return '#475569'
}

export default function UsersPage() {
  const { t } = useAdminCopy()
  const [query, setQuery] = useState('')
  const [accountFilter, setAccountFilter] = useState<AccountFilter>('all')
  const [lastSeenWithinDays, setLastSeenWithinDays] = useState('')
  const [sessionCountMin, setSessionCountMin] = useState('')
  const [scanFilterOperator, setScanFilterOperator] = useState<ScanFilterOperator>('gte')
  const [scanFilterValue, setScanFilterValue] = useState('')
  const [savedCartCountMin, setSavedCartCountMin] = useState('')
  const [readyPushOnly, setReadyPushOnly] = useState(false)
  const [regionSegmentMode, setRegionSegmentMode] = useState<RegionSegmentMode>('none')
  const [regionLevel, setRegionLevel] = useState<Exclude<RegionLevel, 'all'>>('district')
  const [selectedRegionKeys, setSelectedRegionKeys] = useState<string[]>([])
  const [regionRecentWithinDays, setRegionRecentWithinDays] = useState('30')
  const [regionVisitCountMin, setRegionVisitCountMin] = useState('3')
  const [regionPickerOpen, setRegionPickerOpen] = useState(false)
  const [regionPickerDraftKeys, setRegionPickerDraftKeys] = useState<string[]>([])
  const [regionPickerCity, setRegionPickerCity] = useState('')
  const [regionPickerDistrict, setRegionPickerDistrict] = useState('')

  const districtOptions = useMemo(() => (regionPickerCity ? regionOptionsForLevel('district', regionPickerCity) as KoreaRegionOption[] : []), [regionPickerCity])
  const neighborhoodOptions = useMemo(() => (regionPickerCity ? regionOptionsForLevel('neighborhood', regionPickerCity, regionPickerDistrict) as KoreaRegionOption[] : []), [regionPickerCity, regionPickerDistrict])
  const pickerOptions = useMemo(() => {
    if (regionLevel === 'city') return KOREA_CITIES as KoreaRegionOption[]
    if (regionLevel === 'district') return districtOptions
    return neighborhoodOptions
  }, [districtOptions, neighborhoodOptions, regionLevel])

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

  const usersPath = useMemo(() => {
    const params = new URLSearchParams({
      view: 'v4',
      accountType: accountFilter,
      limit: '1000',
    })
    if (query.trim()) params.set('query', query.trim())

    const parsedLastSeenWithinDays = parseOptionalNumber(lastSeenWithinDays)
    const parsedSessionCountMin = parseOptionalNumber(sessionCountMin)
    const parsedScanFilterValue = parseOptionalNumber(scanFilterValue)
    const parsedSavedCartCountMin = parseOptionalNumber(savedCartCountMin)

    if (parsedLastSeenWithinDays !== undefined) params.set('lastSeenWithinDays', String(parsedLastSeenWithinDays))
    if (parsedSessionCountMin !== undefined) params.set('sessionCountMin', String(parsedSessionCountMin))
    if (parsedScanFilterValue !== undefined) {
      if (scanFilterOperator === 'gte') {
        params.set('scanCountMin', String(parsedScanFilterValue))
      } else {
        params.set('scanCountLt', String(parsedScanFilterValue))
      }
    }
    if (parsedSavedCartCountMin !== undefined) params.set('savedCartCountMin', String(parsedSavedCartCountMin))
    if (readyPushOnly) params.set('readyPushOnly', 'true')
    if (regionSegmentMode !== 'none') {
      params.set('regionSegmentMode', regionSegmentMode)
      if (selectedRegionKeys.length > 0) params.set('regionKeys', selectedRegionKeys.join(','))
      if (regionSegmentMode === 'recent') {
        const parsedRegionRecentWithinDays = parseOptionalNumber(regionRecentWithinDays)
        if (parsedRegionRecentWithinDays !== undefined) params.set('regionRecentWithinDays', String(parsedRegionRecentWithinDays))
      }
      if (regionSegmentMode === 'frequent') {
        const parsedRegionVisitCountMin = parseOptionalNumber(regionVisitCountMin)
        if (parsedRegionVisitCountMin !== undefined) params.set('regionVisitCountMin', String(parsedRegionVisitCountMin))
      }
    }

    return `/admin/users?${params.toString()}`
  }, [accountFilter, lastSeenWithinDays, query, readyPushOnly, regionRecentWithinDays, regionSegmentMode, regionVisitCountMin, savedCartCountMin, scanFilterOperator, scanFilterValue, selectedRegionKeys, sessionCountMin])

  const usersRes = useAdminData<{ ok: boolean; data: { summary?: UsersSummary; users?: UserRow[] } }>(usersPath, {
    ok: true,
    data: usersFallback,
  })
  const legacyGuestsRes = useAdminData<{ ok: boolean; data: { summary?: LegacySummary; users?: UserRow[] } }>('/admin/users/legacy-guests?view=v2', {
    ok: true,
    data: legacyGuestsFallback,
  })

  const users = usersRes.data?.data?.users ?? []
  const summary = usersRes.data?.data?.summary
  const legacySummary = legacyGuestsRes.data?.data?.summary
  const loading = usersRes.loading || legacyGuestsRes.loading
  const usingFallback = usersRes.usingFallback || legacyGuestsRes.usingFallback
  const error = usersRes.error ?? legacyGuestsRes.error

  const memberUsers = useMemo(() => users.filter((user) => !user.isGuest), [users])
  const guestUsers = useMemo(() => users.filter((user) => Boolean(user.isGuest)), [users])
  const membersWithEmail = useMemo(() => memberUsers.filter((user) => Boolean(user.email)).length, [memberUsers])
  const guestUsersWithCarts = useMemo(() => guestUsers.filter((user) => savedCartCount(user) > 0).length, [guestUsers])
  const readyPushUsers = summary?.readyPushUsers ?? users.filter((user) => (user.readyPushDeviceCount ?? 0) > 0).length
  const pushBlockedUsers = useMemo(() => users.filter((user) => user.reachabilityState === 'push_blocked').length, [users])
  const dormantUsers = useMemo(() => users.filter((user) => (user.lifecycleStage ?? '').includes('dormant')).length, [users])
  const mergeReviewUsers = useMemo(() => users.filter((user) => user.operatorAction === 'merge_review').length, [users])

  const totalLegacy = legacySummary?.count ?? 0
  const legacyWithCarts = legacySummary?.withCarts ?? 0

  const accountFilterButtons: Array<[AccountFilter, string]> = [
    ['all', `All (${formatNumber(summary?.filteredUsers ?? users.length)})`],
    ['member', `Members (${formatNumber(summary?.members ?? memberUsers.length)})`],
    ['guest', `Guests (${formatNumber(summary?.guests ?? guestUsers.length)})`],
  ]

  const activeFilterPills = useMemo(() => {
    const pills = [
      `account ${accountFilter}`,
      `query ${query.trim() || '-'}`,
    ]
    if (lastSeenWithinDays.trim()) pills.push(`seen ${lastSeenWithinDays.trim()}d`)
    if (sessionCountMin.trim()) pills.push(`visits >= ${sessionCountMin.trim()}`)
    if (scanFilterValue.trim()) pills.push(`scans ${scanFilterOperator === 'gte' ? '>=' : '<'} ${scanFilterValue.trim()}`)
    if (savedCartCountMin.trim()) pills.push(`saved carts >= ${savedCartCountMin.trim()}`)
    if (readyPushOnly) pills.push('push ready only')
    if (regionSegmentMode !== 'none') {
      pills.push(`activity ${regionSegmentMode}`)
      pills.push(`region ${regionFilterSummary(regionSegmentMode, selectedRegionKeys)}`)
      if (regionSegmentMode === 'recent') pills.push(`recent ${regionRecentWithinDays.trim() || '30'}d`)
      if (regionSegmentMode === 'frequent') pills.push(`visits >= ${regionVisitCountMin.trim() || '3'}`)
    }
    return pills
  }, [accountFilter, lastSeenWithinDays, query, readyPushOnly, regionRecentWithinDays, regionSegmentMode, regionVisitCountMin, savedCartCountMin, scanFilterOperator, scanFilterValue, selectedRegionKeys, sessionCountMin])

  function applyPreset(preset: SegmentPreset) {
    if (preset === 'recent7') {
      setLastSeenWithinDays('7')
      return
    }
    if (preset === 'recent30') {
      setLastSeenWithinDays('30')
      return
    }
    if (preset === 'visit5') {
      setSessionCountMin('5')
      return
    }
    if (preset === 'scan10') {
      setScanFilterOperator('gte')
      setScanFilterValue('10')
      return
    }
    if (preset === 'scanLow') {
      setScanFilterOperator('lt')
      setScanFilterValue('3')
      return
    }
    if (preset === 'pushReady') {
      setReadyPushOnly(true)
    }
  }

  function resetFilters() {
    setQuery('')
    setAccountFilter('all')
    setLastSeenWithinDays('')
    setSessionCountMin('')
    setScanFilterOperator('gte')
    setScanFilterValue('')
    setSavedCartCountMin('')
    setReadyPushOnly(false)
    setRegionSegmentMode('none')
    setSelectedRegionKeys([])
    setRegionRecentWithinDays('30')
    setRegionVisitCountMin('3')
  }

  function downloadPushAudienceSheet() {
    const workbook = XLSX.utils.book_new()
    const exportedAt = new Date().toISOString()
    const summarySheet = XLSX.utils.aoa_to_sheet([
      ['Cartly Users segment export'],
      ['exportedAt', exportedAt],
      ['filteredUsers', summary?.filteredUsers ?? users.length],
      ['readyPushUsers', readyPushUsers],
      ['filters', activeFilterPills.join(' | ')],
      [],
      ['guide'],
      ['upload this file in Push > 직접 업로드'],
      ['userId is the primary key, installId stays blank by default'],
      ['backend re-resolves ready devices from live state during preview/send'],
    ])
    const audienceSheet = XLSX.utils.json_to_sheet(
      users.map((user) => ({
        userId: user.id ?? '',
        installId: '',
        name: displayUserName(user),
        memo: `users segment | ${user.lifecycleLabel ?? '-'} | region ${user.topRegionSummary ?? user.primaryRegionLabel ?? '-'} | visits ${user.sessionCount ?? 0} | scans ${user.scanCount ?? 0} | carts ${savedCartCount(user)}`,
        accountType: user.isGuest ? 'guest' : 'member',
        lifecycleStage: user.lifecycleStage ?? '',
        reachabilityState: user.reachabilityState ?? '',
        operatorAction: user.operatorAction ?? '',
        email: user.email ?? '',
        provider: providerLabel(user),
        lastSeenAt: user.lastSeenAt ?? '',
        lastScanAt: user.lastScanAt ?? '',
        sessionCount: user.sessionCount ?? 0,
        scanCount: user.scanCount ?? 0,
        savedCartCount: savedCartCount(user),
        readyPushDeviceCount: user.readyPushDeviceCount ?? 0,
        pushDeviceCount: user.pushDeviceCount ?? 0,
        primaryRegionLabel: user.primaryRegionLabel ?? '',
        topRegionSummary: user.topRegionSummary ?? '',
        regionActivityCount: user.regionActivityCount ?? 0,
        recentRegionCount30d: user.recentRegionCount30d ?? 0,
        householdRole: user.householdRole ?? '',
        householdName: user.householdName ?? '',
        householdMemberCount: user.householdMemberCount ?? 0,
        lastDevicePlatform: user.lastDevicePlatform ?? '',
        lastAppVersion: user.lastAppVersion ?? '',
      }))
    )
    XLSX.utils.book_append_sheet(workbook, summarySheet, 'summary')
    XLSX.utils.book_append_sheet(workbook, audienceSheet, 'audience')
    XLSX.writeFile(workbook, `cartly-users-segment-${exportedAt.slice(0, 10)}.xlsx`)
  }

  async function reloadAll() {
    await Promise.all([usersRes.reload(), legacyGuestsRes.reload()])
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.users.title', 'Users')}
        description={t('admin.users.desc', 'customer DB, segmentation, push audience export, guest cleanup routing')}
        onRefresh={() => void reloadAll()}
        refreshing={loading}
        inlineRefresh
        actions={(
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button type="button" className="pageActionBtn" onClick={downloadPushAudienceSheet} disabled={users.length === 0}>
              Export for Push
            </button>
            <Link className="ghostBtn pageActionBtn" href="/users/legacy-cleanup">Legacy cleanup</Link>
          </div>
        )}
      />

      {error ? <div className="loginError" style={{ marginBottom: 16 }}>{error}</div> : null}
      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.users.warning.fallbackTitle', 'Live user data unavailable.')}</strong>{' '}
          {t('admin.users.warning.fallbackBody', '지금 목록은 fallback/mock data일 수 있어서 live runtime 확인 전에는 운영 판단을 보수적으로 하는 편이 안전해.')}
          {usersRes.fallbackMessage ? ` (${usersRes.fallbackMessage})` : legacyGuestsRes.fallbackMessage ? ` (${legacyGuestsRes.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Filtered</div>
          <div className="exploreSummaryValue">{formatNumber(summary?.filteredUsers ?? users.length)}</div>
          <div className="exploreSummaryNote">current segment rows</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Ready push</div>
          <div className="exploreSummaryValue">{formatNumber(readyPushUsers)}</div>
          <div className="exploreSummaryNote">live device ready</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Push blocked</div>
          <div className="exploreSummaryValue">{formatNumber(pushBlockedUsers)}</div>
          <div className="exploreSummaryNote">device exists, reachability blocked</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Dormant</div>
          <div className="exploreSummaryValue">{formatNumber(dormantUsers)}</div>
          <div className="exploreSummaryNote">customer reactivation candidates</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Merge review</div>
          <div className="exploreSummaryValue">{formatNumber(mergeReviewUsers)}</div>
          <div className="exploreSummaryNote">legacy guests with carts</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Legacy queue</div>
          <div className="exploreSummaryValue">{formatNumber(totalLegacy)}</div>
          <div className="exploreSummaryNote">with carts {formatNumber(legacyWithCarts)}</div>
        </div>
      </div>

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Segment filters</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              {activeFilterPills.map((pill) => (
                <div key={pill} className="metaPill">{pill}</div>
              ))}
              <Link className="metaPill" href="/users/legacy-cleanup">legacy queue {formatNumber(totalLegacy)}</Link>
            </div>
          </div>

          <div className="editorSubtabRow">
            {accountFilterButtons.map(([key, label]) => (
              <button key={key} type="button" className={`editorSubtab ${accountFilter === key ? 'active' : ''}`} onClick={() => setAccountFilter(key)}>
                {label}
              </button>
            ))}
          </div>

          <div className="editorSubtabRow" style={{ marginTop: 8 }}>
            <button type="button" className="editorSubtab" onClick={() => applyPreset('recent7')}>최근 7일</button>
            <button type="button" className="editorSubtab" onClick={() => applyPreset('recent30')}>최근 30일</button>
            <button type="button" className="editorSubtab" onClick={() => applyPreset('visit5')}>방문 5회+</button>
            <button type="button" className="editorSubtab" onClick={() => applyPreset('scan10')}>스캔 10개+</button>
            <button type="button" className="editorSubtab" onClick={() => applyPreset('scanLow')}>스캔 3개 미만</button>
            <button type="button" className="editorSubtab" onClick={() => applyPreset('pushReady')}>push ready</button>
            <button type="button" className="ghostBtn ghostBtnSmall" onClick={resetFilters}>Reset</button>
          </div>

          <div className="exploreSheetFilterGrid compactFilterGrid" style={{ gridTemplateColumns: 'minmax(240px, 1.5fr) repeat(5, minmax(130px, 0.8fr)) minmax(200px, 1.2fr) minmax(200px, 1.1fr)' }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">검색</div>
              <input className="textInput exploreSheetInput" value={query} onChange={(event) => setQuery(event.target.value)} placeholder={t('admin.users.list.searchPlaceholder', 'name / email / id / device')} />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">최근 방문</div>
              <select className="textInput exploreSheetInput" value={lastSeenWithinDays} onChange={(event) => setLastSeenWithinDays(event.target.value)}>
                <option value="">전체</option>
                <option value="7">7일 이내</option>
                <option value="30">30일 이내</option>
                <option value="90">90일 이내</option>
                <option value="180">180일 이내</option>
              </select>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">방문수</div>
              <input className="textInput exploreSheetInput" inputMode="numeric" value={sessionCountMin} onChange={(event) => setSessionCountMin(event.target.value)} placeholder=">= 5" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">스캔수</div>
              <div className="compactInlineField">
                <select className="textInput exploreSheetInput compactInlineSelect" value={scanFilterOperator} onChange={(event) => setScanFilterOperator(event.target.value as ScanFilterOperator)}>
                  <option value="gte">이상</option>
                  <option value="lt">미만</option>
                </select>
                <input className="textInput exploreSheetInput compactInlineInput" inputMode="numeric" value={scanFilterValue} onChange={(event) => setScanFilterValue(event.target.value)} placeholder="10" />
              </div>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">저장 카트</div>
              <input className="textInput exploreSheetInput" inputMode="numeric" value={savedCartCountMin} onChange={(event) => setSavedCartCountMin(event.target.value)} placeholder=">= 1" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">푸시 가능</div>
              <div className="compactToggleCard">
                <input type="checkbox" checked={readyPushOnly} onChange={(event) => setReadyPushOnly(event.target.checked)} />
                <span>ready device만</span>
              </div>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">지역 세그먼트</div>
              <select className="textInput exploreSheetInput" value={regionSegmentMode} onChange={(event) => setRegionSegmentMode(event.target.value as RegionSegmentMode)}>
                <option value="none">안씀</option>
                <option value="recent">최근 방문</option>
                <option value="frequent">자주 방문</option>
                <option value="primary">대표 활동지역</option>
              </select>
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">지역 선택</div>
              <button type="button" className="ghostBtn ghostBtnSmall" style={{ justifyContent: 'flex-start', width: '100%' }} onClick={openRegionPicker}>
                {regionFilterSummary(regionSegmentMode, selectedRegionKeys)}
              </button>
            </label>
          </div>

          {regionSegmentMode !== 'none' ? (
            <div className="exploreSheetFilterGrid compactFilterGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(180px, 0.9fr))' }}>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">지역단위</div>
                <select className="textInput exploreSheetInput" value={regionLevel} onChange={(event) => setRegionLevel(event.target.value as Exclude<RegionLevel, 'all'>)}>
                  <option value="city">시/도</option>
                  <option value="district">구/군/시</option>
                  <option value="neighborhood">동/읍/면</option>
                </select>
              </label>
              <label className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">{regionSegmentMode === 'recent' ? '최근 기준일' : regionSegmentMode === 'frequent' ? '최소 방문수' : '기준'}</div>
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
                  <div className="compactToggleCard"><span>최다 방문 기준</span></div>
                )}
              </label>
              <div className="field" style={{ margin: 0 }}>
                <div className="exploreSheetFieldLabel">선택 요약</div>
                <div className="compactToggleCard"><span>{regionSummaryFromKeys(selectedRegionKeys)}</span></div>
              </div>
            </div>
          ) : null}

          <div className="metaRow" style={{ marginTop: 10, alignItems: 'center' }}>
            <div className="metaPill">export uses userId, installId blank</div>
            <div className="metaPill">Push upload re-resolves live device state</div>
            <div className="metaPill">customer state is derived from live metrics</div>
          </div>
        </div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard section">
        <div className="sectionHeader exploreSheetHeader">
          <h2 className="panelTitle" style={{ marginBottom: 0 }}>Segment result</h2>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">rows {formatNumber(summary?.filteredUsers ?? users.length)}</span>
            <span className="metaPill">members {formatNumber(summary?.members ?? memberUsers.length)}</span>
            <span className="metaPill">guests {formatNumber(summary?.guests ?? guestUsers.length)}</span>
            <span className="metaPill">members with email {formatNumber(membersWithEmail)}</span>
            <span className="metaPill">guest carts {formatNumber(guestUsersWithCarts)}</span>
          </div>
        </div>
        {users.length === 0 ? (
          <div className="emptyState">조건에 맞는 user가 없어</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Lifecycle</th>
                  <th>Visits / Scans</th>
                  <th>Reachability</th>
                  <th>Region activity</th>
                  <th>Device / Identity</th>
                  <th>Last active</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user, index) => (
                  <tr key={user.id ?? index}>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 220 }}>
                        <strong>{displayUserName(user)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.id ?? '-'}</span>
                        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                          <span className="metaPill">{userTypeLabel(user, t)}</span>
                          <span className="metaPill">{providerLabel(user)}</span>
                          {user.hasHousehold ? (
                            <span className="metaPill">share {user.householdRole ?? 'member'} · {formatNumber(user.householdMemberCount ?? 0)}</span>
                          ) : (
                            <span className="metaPill">solo</span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                        <strong style={{ color: lifecycleTone(user.lifecycleStage) }}>{user.lifecycleLabel ?? cleanupLabel(user)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.operatorActionLabel ?? 'monitor'}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>joined {formatDate(user.createdAt)}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 160 }}>
                        <strong>visits {formatNumber(user.sessionCount ?? 0)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>scans {formatNumber(user.scanCount ?? 0)}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>saved carts {formatNumber(savedCartCount(user))}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 170 }}>
                        <strong style={{ color: reachabilityTone(user.reachabilityState) }}>{user.reachabilityLabel ?? 'reachability -'}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{formatNumber(user.readyPushDeviceCount ?? 0)} ready / {formatNumber(user.pushDeviceCount ?? 0)} devices</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>action {user.operatorAction ?? '-'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 190 }}>
                        <strong>{user.primaryRegionLabel ?? user.topRegionSummary ?? '-'}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.topRegionSummary ?? '활동지역 없음'}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>regions {formatNumber(user.regionActivityCount ?? 0)} · recent30 {formatNumber(user.recentRegionCount30d ?? 0)}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 170 }}>
                        <strong>{platformLabel(user.lastDevicePlatform)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.lastAppVersion ?? '-'}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.email ?? user.guestKey ?? 'no account detail'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 160 }}>
                        <strong>{formatDate(user.lastActivityAt ?? user.lastSeenAt ?? user.lastActiveAt)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>type {user.lastActivityType ?? 'seen'}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>last scan {formatDate(user.lastScanAt)}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 8, minWidth: 240 }}>
                        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                          <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}`}>Profile</Link>
                          <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/history`}>History</Link>
                          <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/cleanup`}>Cleanup</Link>
                        </div>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.operatorActionLabel ?? 'monitor'}</span>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {regionPickerOpen ? (
        <div className="sheetModalBackdrop" onClick={() => setRegionPickerOpen(false)}>
          <div className="sheetModalCard" style={{ width: 'min(960px, calc(100vw - 32px))' }} onClick={(event) => event.stopPropagation()}>
            <div className="sectionHeader exploreSheetHeader">
              <h2 className="panelTitle" style={{ marginBottom: 0 }}>활동지역 선택</h2>
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
                <div className="compactToggleCard"><span>{regionSummaryFromKeys(regionPickerDraftKeys)}</span></div>
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
