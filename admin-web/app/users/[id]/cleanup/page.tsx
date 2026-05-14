'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'
import { useParams } from 'next/navigation'

import PageHeader from '../../../../components/PageHeader'
import { useAdminCopy } from '../../../../components/AdminCopyProvider'
import { postJson } from '../../../../lib/api'
import { formatDate, formatNumber } from '../../../../lib/format'
import { useAdminData } from '../../../../lib/useAdminData'
import { createUserDetailFallback, isLegacyGuestUser, type UserCartDetailPayload } from '../detailShared'

type UserRow = {
  id?: string
  displayName?: string | null
  email?: string | null
  provider?: string | null
  isGuest?: boolean | null
  guestCode?: string | null
  createdAt?: string | null
  lastSeenAt?: string | null
  lastDevicePlatform?: string | null
  lastAppVersion?: string | null
  cartCount?: number | null
}

const usersFallback = {
  users: [],
}

function displayUserName(user: UserRow) {
  if (user.isGuest && user.guestCode) return `Guest#${user.guestCode}`
  if (user.displayName?.trim()) return user.displayName
  if (user.email?.trim()) return user.email
  return user.id ?? '-'
}

export default function UserCleanupPage() {
  const { t } = useAdminCopy()
  const params = useParams<{ id: string }>()
  const userId = Array.isArray(params?.id) ? params.id[0] : params?.id
  const [targetUserId, setTargetUserId] = useState('')
  const [targetQuery, setTargetQuery] = useState('')
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [busyAction, setBusyAction] = useState<'merge' | 'archive' | null>(null)

  const detailRes = useAdminData<{ ok: boolean; data: UserCartDetailPayload }>(`/admin/users/${userId}/carts`, {
    ok: true,
    data: createUserDetailFallback(userId),
  })
  const usersRes = useAdminData<{ ok: boolean; data: { users?: UserRow[] } }>('/admin/users?view=v3', {
    ok: true,
    data: usersFallback,
  })

  const payload = detailRes.data.data
  const user = payload.user
  const isLegacyGuest = isLegacyGuestUser(user)
  const totalCarts = payload.summary.totalCarts

  const candidateUsers = useMemo(() => {
    const trimmed = targetQuery.trim().toLowerCase()
    return (usersRes.data.data.users ?? []).filter((candidate) => {
      if (!candidate.id || candidate.id === user.id) return false
      if (candidate.isGuest) return false
      if (!trimmed) return true
      return [candidate.id, candidate.displayName, candidate.email, candidate.provider]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(trimmed))
    })
  }, [targetQuery, user.id, usersRes.data.data.users])

  async function reloadAll() {
    await Promise.all([detailRes.reload(), usersRes.reload()])
  }

  async function archiveLegacy() {
    if (!user.id) return
    setBusyAction('archive')
    setActionMessage(null)
    try {
      await postJson(`/admin/users/${user.id}/archive-legacy`)
      await reloadAll()
      setActionMessage(`archived ${user.id}`)
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : 'archive failed')
    } finally {
      setBusyAction(null)
    }
  }

  async function mergeLegacy() {
    if (!user.id || !targetUserId) return
    setBusyAction('merge')
    setActionMessage(null)
    try {
      await postJson(`/admin/users/${user.id}/merge-legacy`, { targetUserId })
      await reloadAll()
      setActionMessage(`merged into ${targetUserId}`)
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : 'merge failed')
    } finally {
      setBusyAction(null)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={detailRes.usingFallback || usersRes.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : detailRes.loading || usersRes.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={`${user.displayName || 'Customer'} cleanup`}
        description={t('admin.users.detail.cleanup.desc', '게스트 고객 정리, merge target 선택, archive 판단을 분리된 면에서 처리한다')}
        onRefresh={() => void reloadAll()}
        refreshing={detailRes.loading || usersRes.loading}
        inlineRefresh
        actions={(
          <>
            <Link className="ghostBtn pageActionBtn" href="/users/legacy-cleanup">Legacy queue</Link>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}`}>Profile</Link>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}/history`}>History</Link>
          </>
        )}
      />

      {detailRes.error ? <div className="loginError" style={{ marginBottom: 16 }}>{detailRes.error}</div> : null}
      {usersRes.error ? <div className="loginError" style={{ marginBottom: 16 }}>{usersRes.error}</div> : null}
      {actionMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{actionMessage}</div> : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Cleanup state</div>
          <div className="exploreSummaryValue">{isLegacyGuest ? 'legacy guest' : 'normal'}</div>
          <div className="exploreSummaryNote">guestKey {user.guestKey ?? '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Saved carts</div>
          <div className="exploreSummaryValue">{formatNumber(totalCarts)}</div>
          <div className="exploreSummaryNote">merge review basis</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Status</div>
          <div className="exploreSummaryValue">{user.status ?? '-'}</div>
          <div className="exploreSummaryNote">mergedInto {user.mergedIntoUserId ?? '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Last seen</div>
          <div className="exploreSummaryValue">{formatDate(user.lastSeenAt)}</div>
          <div className="exploreSummaryNote">platform {user.lastDevicePlatform ?? '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Archive ready</div>
          <div className="exploreSummaryValue">{isLegacyGuest && totalCarts === 0 ? 'yes' : 'no'}</div>
          <div className="exploreSummaryNote">zero carts only</div>
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Cleanup decision</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">user {user.id}</span>
              <span className="metaPill">carts {formatNumber(totalCarts)}</span>
            </div>
          </div>
          <div className="tableWrap" style={{ marginBottom: 12 }}>
            <table className="dataTable exploreDenseTable">
              <tbody>
                <tr><td>Display</td><td>{user.displayName || '-'}</td></tr>
                <tr><td>Guest code</td><td>{user.guestCode ? `Guest#${user.guestCode}` : '-'}</td></tr>
                <tr><td>Email</td><td>{user.email ?? '-'}</td></tr>
                <tr><td>Provider</td><td>{user.provider}</td></tr>
                <tr><td>Created</td><td>{formatDate(user.createdAt)}</td></tr>
                <tr><td>Last seen</td><td>{formatDate(user.lastSeenAt)}</td></tr>
                <tr><td>Merged at</td><td>{formatDate(user.mergedAt)}</td></tr>
              </tbody>
            </table>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <button className="ghostBtn pageActionBtn" disabled={!isLegacyGuest || totalCarts > 0 || busyAction !== null} onClick={() => void archiveLegacy()}>
              {busyAction === 'archive' ? 'Archiving...' : 'Archive legacy guest'}
            </button>
            <div style={{ color: '#64748b', fontSize: 12 }}>
              {totalCarts > 0 ? '저장 카트가 있으면 archive 대신 merge 판단이 먼저 필요해.' : '저장 카트가 없으면 archive 후보로 바로 처리할 수 있어.'}
            </div>
          </div>
        </div>

        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Merge target</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">members {formatNumber(candidateUsers.length)}</span>
              <span className="metaPill">selected {targetUserId || '-'}</span>
            </div>
          </div>
          <label className="field" style={{ marginBottom: 12 }}>
            <div className="exploreSheetFieldLabel">대상 사용자 검색</div>
            <input className="textInput exploreSheetInput" value={targetQuery} onChange={(event) => setTargetQuery(event.target.value)} placeholder="name / email / id" />
          </label>
          <label className="field" style={{ marginBottom: 12 }}>
            <div className="exploreSheetFieldLabel">Merge target</div>
            <select className="selectInput exploreSheetSelect" value={targetUserId} onChange={(event) => setTargetUserId(event.target.value)}>
              <option value="">선택 안 함</option>
              {candidateUsers.map((candidate) => (
                <option key={candidate.id} value={candidate.id}>{displayUserName(candidate)} · {candidate.email ?? candidate.id}</option>
              ))}
            </select>
          </label>
          <button className="ghostBtn pageActionBtn" disabled={!isLegacyGuest || !targetUserId || busyAction !== null} onClick={() => void mergeLegacy()}>
            {busyAction === 'merge' ? 'Merging...' : 'Merge legacy guest into selected user'}
          </button>
          <div className="tableWrap" style={{ marginTop: 12 }}>
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>Candidate</th>
                  <th>Email</th>
                  <th>Provider</th>
                  <th>Carts</th>
                </tr>
              </thead>
              <tbody>
                {candidateUsers.slice(0, 12).map((candidate) => (
                  <tr key={candidate.id}>
                    <td>{displayUserName(candidate)}</td>
                    <td>{candidate.email ?? '-'}</td>
                    <td>{candidate.provider ?? '-'}</td>
                    <td>{formatNumber(candidate.cartCount ?? 0)}</td>
                  </tr>
                ))}
                {candidateUsers.length === 0 ? (
                  <tr><td colSpan={4}>선택 가능한 member가 없어</td></tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}
