'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'

import PageHeader from '../../../components/PageHeader'
import { useAdminCopy } from '../../../components/AdminCopyProvider'
import { postJson } from '../../../lib/api'
import { formatDate, formatNumber } from '../../../lib/format'
import { useAdminData } from '../../../lib/useAdminData'

type UserRow = {
  id?: string
  displayName?: string | null
  guestCode?: string | null
  createdAt?: string | null
  lastSeenAt?: string | null
  lastActiveAt?: string | null
  lastDevicePlatform?: string | null
  lastAppVersion?: string | null
  cartCount?: number | null
  sessionCount?: number | null
}

type LegacySummary = {
  count?: number
  withCarts?: number
  withoutCarts?: number
}

type LegacyFilter = 'all' | 'with-carts' | 'without-carts'

const legacyGuestsFallback = {
  summary: {
    count: 0,
    withCarts: 0,
    withoutCarts: 0,
  },
  users: [],
}

function displayUserName(user: UserRow) {
  if (user.guestCode) return `Guest#${user.guestCode}`
  if (user.displayName?.trim()) return user.displayName
  return user.id ?? '-'
}

function platformLabel(value: string | null | undefined) {
  return value?.trim() ? value.toUpperCase() : '-'
}

function savedCartCount(user: UserRow) {
  return user.cartCount ?? 0
}

export default function LegacyCleanupPage() {
  const { t } = useAdminCopy()
  const [query, setQuery] = useState('')
  const [legacyFilter, setLegacyFilter] = useState<LegacyFilter>('all')
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [busyLegacyId, setBusyLegacyId] = useState<string | null>(null)

  const legacyGuestsRes = useAdminData<{ ok: boolean; data: { summary?: LegacySummary; users?: UserRow[] } }>('/admin/users/legacy-guests?view=v3', {
    ok: true,
    data: legacyGuestsFallback,
  })

  const legacyGuests = legacyGuestsRes.data?.data?.users ?? []
  const legacySummary = legacyGuestsRes.data?.data?.summary
  const legacyWithCarts = legacySummary?.withCarts ?? legacyGuests.filter((user) => savedCartCount(user) > 0).length
  const legacyWithoutCarts = legacySummary?.withoutCarts ?? Math.max(legacyGuests.length - legacyWithCarts, 0)
  const totalLegacy = legacySummary?.count ?? legacyGuests.length

  const filteredLegacyGuests = useMemo(() => {
    const trimmed = query.trim().toLowerCase()
    return legacyGuests.filter((user) => {
      const carts = savedCartCount(user)
      const matchesLegacy = legacyFilter === 'all' ? true : legacyFilter === 'with-carts' ? carts > 0 : carts === 0
      const matchesQuery = !trimmed || [
        user.id,
        user.displayName,
        user.guestCode,
        user.lastDevicePlatform,
      ].filter(Boolean).some((value) => String(value).toLowerCase().includes(trimmed))
      return matchesLegacy && matchesQuery
    })
  }, [legacyFilter, legacyGuests, query])

  const legacyFilterButtons: Array<[LegacyFilter, string]> = [
    ['all', `전체 (${formatNumber(totalLegacy)})`],
    ['with-carts', `카트 있음 (${formatNumber(legacyWithCarts)})`],
    ['without-carts', `카트 없음 (${formatNumber(legacyWithoutCarts)})`],
  ]

  async function archiveLegacyGuest(id: string) {
    setBusyLegacyId(id)
    setActionMessage(null)
    try {
      await postJson(`/admin/users/${id}/archive-legacy`)
      await legacyGuestsRes.reload()
      setActionMessage(`${id} 보관 완료`)
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : t('admin.users.legacy.archiveFailed', 'archive failed'))
    } finally {
      setBusyLegacyId(null)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={legacyGuestsRes.usingFallback ? t('admin.common.badge.fallback', '대체 데이터') : legacyGuestsRes.loading ? t('admin.common.badge.loading', '불러오는 중...') : t('admin.common.badge.live', '실데이터')}
        title="레거시 비회원 정리"
        description="고객 화면과 분리된 정리 대기열"
        onRefresh={() => void legacyGuestsRes.reload()}
        refreshing={legacyGuestsRes.loading}
        inlineRefresh
        actions={(
          <Link className="ghostBtn pageActionBtn" href="/users">고객</Link>
        )}
      />

      {legacyGuestsRes.error ? <div className="loginError" style={{ marginBottom: 16 }}>{legacyGuestsRes.error}</div> : null}
      {actionMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{actionMessage}</div> : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">대기열</div>
          <div className="exploreSummaryValue">{formatNumber(totalLegacy)}</div>
          <div className="exploreSummaryNote">레거시 비회원</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">카트 있음</div>
          <div className="exploreSummaryValue">{formatNumber(legacyWithCarts)}</div>
          <div className="exploreSummaryNote">통합 검토 우선</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">카트 없음</div>
          <div className="exploreSummaryValue">{formatNumber(legacyWithoutCarts)}</div>
          <div className="exploreSummaryNote">보관 후보</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">조회</div>
          <div className="exploreSummaryValue">{formatNumber(filteredLegacyGuests.length)}</div>
          <div className="exploreSummaryNote">현재 대기열 기준</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">검색</div>
          <div className="exploreSummaryValue">{query.trim() || '-'}</div>
          <div className="exploreSummaryNote">검색어</div>
        </div>
      </div>

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>조회 조건</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">대기열 {legacyFilter}</div>
              <div className="metaPill">검색 {query.trim() || '-'}</div>
            </div>
          </div>
          <div className="editorSubtabRow">
            {legacyFilterButtons.map(([key, label]) => (
              <button key={key} type="button" className={`editorSubtab ${legacyFilter === key ? 'active' : ''}`} onClick={() => setLegacyFilter(key)}>
                {label}
              </button>
            ))}
          </div>
          <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(220px, 1fr)' }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">검색</div>
              <input className="textInput exploreSheetInput" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="비회원 코드 / ID / 기기" />
            </label>
          </div>
        </div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard section">
        <div className="sectionHeader exploreSheetHeader">
          <h2 className="panelTitle" style={{ marginBottom: 0 }}>정리 대기열</h2>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">조회 {formatNumber(filteredLegacyGuests.length)}</span>
            <span className="metaPill">카트 있음 {formatNumber(legacyWithCarts)}</span>
            <span className="metaPill">카트 없음 {formatNumber(legacyWithoutCarts)}</span>
          </div>
        </div>
        {filteredLegacyGuests.length === 0 ? (
          <div className="emptyState">정리 대상 비회원 없음</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>비회원</th>
                  <th>저장 카트</th>
                  <th>방문</th>
                  <th>최근 방문</th>
                  <th>동작</th>
                </tr>
              </thead>
              <tbody>
                {filteredLegacyGuests.map((user, index) => (
                  <tr key={user.id ?? index}>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                        <strong>{displayUserName(user)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{user.id ?? '-'}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{platformLabel(user.lastDevicePlatform)} · {user.lastAppVersion ?? '-'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4 }}>
                        <strong>{formatNumber(savedCartCount(user))}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{savedCartCount(user) > 0 ? '통합 검토 필요' : '보관 후보'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4 }}>
                        <strong>{formatNumber(user.sessionCount ?? 0)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>방문 수</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4 }}>
                        <strong>{formatDate(user.lastSeenAt ?? user.lastActiveAt)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{formatDate(user.createdAt)}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', minWidth: 236 }}>
                        <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/cleanup`}>정리</Link>
                        <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/history`}>이력</Link>
                        <button className="ghostBtn ghostBtnSmall" disabled={legacyGuestsRes.usingFallback || busyLegacyId === user.id || savedCartCount(user) > 0} onClick={() => void archiveLegacyGuest(String(user.id))}>
                          {busyLegacyId === user.id ? '처리 중...' : '보관'}
                        </button>
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
