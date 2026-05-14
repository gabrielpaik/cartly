'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'
import * as XLSX from 'xlsx'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { formatDate, formatNumber } from '../../lib/format'
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
type SegmentPreset = 'recent7' | 'recent30' | 'visit5' | 'scan10' | 'scanLow' | 'pushReady'

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

export default function UsersPage() {
  const { t } = useAdminCopy()
  const [query, setQuery] = useState('')
  const [accountFilter, setAccountFilter] = useState<AccountFilter>('all')
  const [lastSeenWithinDays, setLastSeenWithinDays] = useState('')
  const [sessionCountMin, setSessionCountMin] = useState('')
  const [scanCountMin, setScanCountMin] = useState('')
  const [scanCountLt, setScanCountLt] = useState('')
  const [savedCartCountMin, setSavedCartCountMin] = useState('')
  const [readyPushOnly, setReadyPushOnly] = useState(false)

  const usersPath = useMemo(() => {
    const params = new URLSearchParams({
      view: 'v4',
      accountType: accountFilter,
      limit: '1000',
    })
    if (query.trim()) params.set('query', query.trim())

    const parsedLastSeenWithinDays = parseOptionalNumber(lastSeenWithinDays)
    const parsedSessionCountMin = parseOptionalNumber(sessionCountMin)
    const parsedScanCountMin = parseOptionalNumber(scanCountMin)
    const parsedScanCountLt = parseOptionalNumber(scanCountLt)
    const parsedSavedCartCountMin = parseOptionalNumber(savedCartCountMin)

    if (parsedLastSeenWithinDays !== undefined) params.set('lastSeenWithinDays', String(parsedLastSeenWithinDays))
    if (parsedSessionCountMin !== undefined) params.set('sessionCountMin', String(parsedSessionCountMin))
    if (parsedScanCountMin !== undefined) params.set('scanCountMin', String(parsedScanCountMin))
    if (parsedScanCountLt !== undefined) params.set('scanCountLt', String(parsedScanCountLt))
    if (parsedSavedCartCountMin !== undefined) params.set('savedCartCountMin', String(parsedSavedCartCountMin))
    if (readyPushOnly) params.set('readyPushOnly', 'true')

    return `/admin/users?${params.toString()}`
  }, [accountFilter, lastSeenWithinDays, query, readyPushOnly, savedCartCountMin, scanCountLt, scanCountMin, sessionCountMin])

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
    if (scanCountMin.trim()) pills.push(`scans >= ${scanCountMin.trim()}`)
    if (scanCountLt.trim()) pills.push(`scans < ${scanCountLt.trim()}`)
    if (savedCartCountMin.trim()) pills.push(`saved carts >= ${savedCartCountMin.trim()}`)
    if (readyPushOnly) pills.push('push ready only')
    return pills
  }, [accountFilter, lastSeenWithinDays, query, readyPushOnly, savedCartCountMin, scanCountLt, scanCountMin, sessionCountMin])

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
      setScanCountMin('10')
      return
    }
    if (preset === 'scanLow') {
      setScanCountLt('3')
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
    setScanCountMin('')
    setScanCountLt('')
    setSavedCartCountMin('')
    setReadyPushOnly(false)
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
        memo: `users segment | visits ${user.sessionCount ?? 0} | scans ${user.scanCount ?? 0} | carts ${savedCartCount(user)}`,
        accountType: user.isGuest ? 'guest' : 'member',
        email: user.email ?? '',
        provider: providerLabel(user),
        lastSeenAt: user.lastSeenAt ?? '',
        lastScanAt: user.lastScanAt ?? '',
        sessionCount: user.sessionCount ?? 0,
        scanCount: user.scanCount ?? 0,
        savedCartCount: savedCartCount(user),
        readyPushDeviceCount: user.readyPushDeviceCount ?? 0,
        pushDeviceCount: user.pushDeviceCount ?? 0,
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
        description={t('admin.users.desc', 'segment extraction, push audience export, guest cleanup routing')}
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
          <div className="exploreSummaryLabel">Visits</div>
          <div className="exploreSummaryValue">{formatNumber(summary?.totalSessions ?? 0)}</div>
          <div className="exploreSummaryNote">session count in segment</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Scans</div>
          <div className="exploreSummaryValue">{formatNumber(summary?.totalScans ?? 0)}</div>
          <div className="exploreSummaryNote">scan jobs in segment</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Saved carts</div>
          <div className="exploreSummaryValue">{formatNumber(summary?.totalSavedCarts ?? 0)}</div>
          <div className="exploreSummaryNote">cart history in segment</div>
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

          <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'repeat(3, minmax(220px, 1fr))' }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">검색</div>
              <input className="textInput exploreSheetInput" value={query} onChange={(event) => setQuery(event.target.value)} placeholder={t('admin.users.list.searchPlaceholder', 'name / email / id / device')} />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">최근 N일 방문</div>
              <input className="textInput exploreSheetInput" inputMode="numeric" value={lastSeenWithinDays} onChange={(event) => setLastSeenWithinDays(event.target.value)} placeholder="7 / 30 / 90" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">방문 N회 이상</div>
              <input className="textInput exploreSheetInput" inputMode="numeric" value={sessionCountMin} onChange={(event) => setSessionCountMin(event.target.value)} placeholder="5" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">스캔 N개 이상</div>
              <input className="textInput exploreSheetInput" inputMode="numeric" value={scanCountMin} onChange={(event) => setScanCountMin(event.target.value)} placeholder="10" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">스캔 N개 미만</div>
              <input className="textInput exploreSheetInput" inputMode="numeric" value={scanCountLt} onChange={(event) => setScanCountLt(event.target.value)} placeholder="3" />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">저장 카트 N개 이상</div>
              <input className="textInput exploreSheetInput" inputMode="numeric" value={savedCartCountMin} onChange={(event) => setSavedCartCountMin(event.target.value)} placeholder="1" />
            </label>
          </div>

          <div className="metaRow" style={{ marginTop: 10, alignItems: 'center' }}>
            <label style={{ display: 'inline-flex', gap: 8, alignItems: 'center', fontSize: 13, color: '#475569' }}>
              <input type="checkbox" checked={readyPushOnly} onChange={(event) => setReadyPushOnly(event.target.checked)} />
              push ready만 보기
            </label>
            <div className="metaPill">export uses userId, installId blank</div>
            <div className="metaPill">Push upload re-resolves live device state</div>
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
                  <th>Visits / Scans</th>
                  <th>Push</th>
                  <th>Device</th>
                  <th>Cleanup</th>
                  <th>Last active</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user, index) => (
                  <tr key={user.id ?? index}>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 200 }}>
                        <strong>{displayUserName(user)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.id ?? '-'}</span>
                        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                          <span className="metaPill">{userTypeLabel(user, t)}</span>
                          <span className="metaPill">{providerLabel(user)}</span>
                        </div>
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
                      <div style={{ display: 'grid', gap: 4, minWidth: 120 }}>
                        <strong>{formatNumber(user.readyPushDeviceCount ?? 0)} ready</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>devices {formatNumber(user.pushDeviceCount ?? 0)}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 160 }}>
                        <strong>{platformLabel(user.lastDevicePlatform)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.lastAppVersion ?? '-'}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.email ?? user.guestKey ?? 'no account detail'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 120 }}>
                        <strong>{cleanupLabel(user)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.isGuest ? 'guest routing' : 'no cleanup'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 160 }}>
                        <strong>{formatDate(user.lastSeenAt ?? user.lastActiveAt)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>last scan {formatDate(user.lastScanAt)}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>joined {formatDate(user.createdAt)}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', minWidth: 232 }}>
                        <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}`}>Profile</Link>
                        <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/history`}>History</Link>
                        <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/cleanup`}>Cleanup</Link>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
