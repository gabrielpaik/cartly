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
    ['all', `All (${formatNumber(totalLegacy)})`],
    ['with-carts', `With carts (${formatNumber(legacyWithCarts)})`],
    ['without-carts', `Without carts (${formatNumber(legacyWithoutCarts)})`],
  ]

  async function archiveLegacyGuest(id: string) {
    setBusyLegacyId(id)
    setActionMessage(null)
    try {
      await postJson(`/admin/users/${id}/archive-legacy`)
      await legacyGuestsRes.reload()
      setActionMessage(`${id} archived`)
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : t('admin.users.legacy.archiveFailed', 'archive failed'))
    } finally {
      setBusyLegacyId(null)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={legacyGuestsRes.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : legacyGuestsRes.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title="Legacy guest cleanup"
        description="Users 본면과 분리된 cleanup queue"
        onRefresh={() => void legacyGuestsRes.reload()}
        refreshing={legacyGuestsRes.loading}
        inlineRefresh
        actions={(
          <Link className="ghostBtn pageActionBtn" href="/users">Users</Link>
        )}
      />

      {legacyGuestsRes.error ? <div className="loginError" style={{ marginBottom: 16 }}>{legacyGuestsRes.error}</div> : null}
      {actionMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{actionMessage}</div> : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Queue</div>
          <div className="exploreSummaryValue">{formatNumber(totalLegacy)}</div>
          <div className="exploreSummaryNote">legacy guests</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">With carts</div>
          <div className="exploreSummaryValue">{formatNumber(legacyWithCarts)}</div>
          <div className="exploreSummaryNote">merge review first</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Without carts</div>
          <div className="exploreSummaryValue">{formatNumber(legacyWithoutCarts)}</div>
          <div className="exploreSummaryNote">archive candidate</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Filtered</div>
          <div className="exploreSummaryValue">{formatNumber(filteredLegacyGuests.length)}</div>
          <div className="exploreSummaryNote">current queue view</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Search</div>
          <div className="exploreSummaryValue">{query.trim() || '-'}</div>
          <div className="exploreSummaryNote">query</div>
        </div>
      </div>

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Filter</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">queue {legacyFilter}</div>
              <div className="metaPill">query {query.trim() || '-'}</div>
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
              <input className="textInput exploreSheetInput" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="guest code / id / device" />
            </label>
          </div>
        </div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard section">
        <div className="sectionHeader exploreSheetHeader">
          <h2 className="panelTitle" style={{ marginBottom: 0 }}>Legacy queue</h2>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">filtered {formatNumber(filteredLegacyGuests.length)}</span>
            <span className="metaPill">with carts {formatNumber(legacyWithCarts)}</span>
            <span className="metaPill">without carts {formatNumber(legacyWithoutCarts)}</span>
          </div>
        </div>
        {filteredLegacyGuests.length === 0 ? (
          <div className="emptyState">정리할 legacy guest가 없어</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>Guest</th>
                  <th>Saved carts</th>
                  <th>Sessions</th>
                  <th>Last active</th>
                  <th>Action</th>
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
                        <span style={{ color: '#64748b', fontSize: 12 }}>{savedCartCount(user) > 0 ? 'merge review needed' : 'archive candidate'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4 }}>
                        <strong>{formatNumber(user.sessionCount ?? 0)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>sessions</span>
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
                        <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/cleanup`}>Cleanup</Link>
                        <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}/history`}>History</Link>
                        <button className="ghostBtn ghostBtnSmall" disabled={legacyGuestsRes.usingFallback || busyLegacyId === user.id || savedCartCount(user) > 0} onClick={() => void archiveLegacyGuest(String(user.id))}>
                          {busyLegacyId === user.id ? '처리 중...' : 'Archive'}
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
