'use client'

import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson } from '../../lib/api'
import { formatDate, formatNumber } from '../../lib/format'
import { useAdminData } from '../../lib/useAdminData'

type UserRow = {
  id?: string
  displayName?: string | null
  email?: string | null
  provider?: string | null
  isGuest?: boolean | null
  guestCode?: string | null
  createdAt?: string | null
  lastSeenAt?: string | null
  lastActiveAt?: string | null
  lastDevicePlatform?: string | null
  lastAppVersion?: string | null
  cartCount?: number | null
  savedCartCount?: number | null
}

type LegacySummary = {
  count?: number
  withCarts?: number
  withoutCarts?: number
}

const usersFallback = {
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
  if (!user.provider) return '-'
  return user.provider
}

function platformLabel(value: string | null | undefined) {
  if (!value) return '-'
  return value.toUpperCase()
}

function savedCartCount(user: UserRow) {
  return user.cartCount ?? user.savedCartCount ?? 0
}

export default function UsersPage() {
  const { t } = useAdminCopy()
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [busyLegacyId, setBusyLegacyId] = useState<string | null>(null)

  const usersRes = useAdminData<{ ok: boolean; data: { users?: UserRow[] } }>('/admin/users', {
    ok: true,
    data: usersFallback,
  })
  const legacyGuestsRes = useAdminData<{ ok: boolean; data: { summary?: LegacySummary; users?: UserRow[] } }>('/admin/users/legacy-guests', {
    ok: true,
    data: legacyGuestsFallback,
  })

  useEffect(() => {
    void usersRes.reload()
    void legacyGuestsRes.reload()
  }, [])

  const users = usersRes.data?.data?.users ?? []
  const legacyGuests = legacyGuestsRes.data?.data?.users ?? []
  const legacySummary = legacyGuestsRes.data?.data?.summary
  const loading = usersRes.loading || legacyGuestsRes.loading
  const usingFallback = usersRes.usingFallback || legacyGuestsRes.usingFallback
  const error = usersRes.error ?? legacyGuestsRes.error

  const memberUsers = useMemo(() => users.filter((user) => !user.isGuest), [users])
  const guestUsers = useMemo(() => users.filter((user) => Boolean(user.isGuest)), [users])
  const membersWithEmail = useMemo(() => memberUsers.filter((user) => Boolean(user.email)).length, [memberUsers])
  const legacyWithCarts = legacySummary?.withCarts ?? legacyGuests.filter((user) => savedCartCount(user) > 0).length
  const legacyWithoutCarts = legacySummary?.withoutCarts ?? Math.max(legacyGuests.length - legacyWithCarts, 0)
  const totalLegacy = legacySummary?.count ?? legacyGuests.length

  async function reloadAll() {
    await Promise.all([usersRes.reload(), legacyGuestsRes.reload()])
  }

  async function archiveLegacyGuest(id: string) {
    setBusyLegacyId(id)
    setActionMessage(null)
    try {
      await postJson(`/admin/users/${id}/archive-legacy`)
      await reloadAll()
      setActionMessage(`${id} ${t('admin.users.legacy.archived', 'archived')}`)
    } catch {
      setActionMessage(t('admin.users.legacy.archiveFailed', 'archive failed'))
    } finally {
      setBusyLegacyId(null)
    }
  }

  return (
    <div>
      <PageHeader
        badge={usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.users.title', 'Users')}
        description={t('admin.users.desc', '사용자 목록')}
        onRefresh={() => void reloadAll()}
        refreshing={loading}
      />

      {error ? <div className="loginError" style={{ marginBottom: 16 }}>{error}</div> : null}
      {actionMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{actionMessage}</div> : null}
      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.users.warning.fallbackTitle', 'Live user data unavailable.')}</strong>{' '}
          {t('admin.users.warning.fallbackBody', '지금 목록은 fallback/mock data일 수 있어서 archive 같은 운영 액션을 잠깐 막아두고 있어요.')}
          {usersRes.fallbackMessage ? ` (${usersRes.fallbackMessage})` : legacyGuestsRes.fallbackMessage ? ` (${legacyGuestsRes.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="kpiGrid">
        <StatCard label={t('admin.users.kpi.total', 'Total Users')} value={formatNumber(users.length)} note={t('admin.users.kpi.totalNote', '현재 active user 기준')} />
        <StatCard label={t('admin.users.kpi.members', 'Members')} value={formatNumber(memberUsers.length)} note={`${t('admin.users.kpi.memberEmails', 'email linked')} ${formatNumber(membersWithEmail)}`} />
        <StatCard label={t('admin.users.kpi.guests', 'Guest Profiles')} value={formatNumber(guestUsers.length)} note={t('admin.users.kpi.guestNote', '게스트 세션/프로필')} />
        <StatCard label={t('admin.users.kpi.legacyQueue', 'Legacy Queue')} value={formatNumber(totalLegacy)} note={`${t('admin.users.kpi.withCarts', 'with carts')} ${formatNumber(legacyWithCarts)}`} />
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.users.legacy.title', 'Legacy guest cleanup queue')}</h2>
              <p className="pageDesc">{t('admin.users.legacy.desc', '자동 병합은 하지 않고, 운영자가 archive/merge 판단할 대상을 모아둔 목록')}</p>
            </div>
          </div>

          <div className="metaRow" style={{ marginBottom: 16 }}>
            <span className="metaPill">{t('admin.users.legacy.summary.total', 'total')} {formatNumber(totalLegacy)}</span>
            <span className="metaPill">{t('admin.users.legacy.summary.withCarts', 'with carts')} {formatNumber(legacyWithCarts)}</span>
            <span className="metaPill">{t('admin.users.legacy.summary.withoutCarts', 'without carts')} {formatNumber(legacyWithoutCarts)}</span>
          </div>

          {legacyGuests.length === 0 ? (
            <div className="emptyState">{t('admin.users.legacy.empty', '정리할 legacy guest가 없어')}</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>{t('admin.users.legacy.table.guest', 'Guest')}</th>
                    <th>{t('admin.users.legacy.table.savedCarts', '저장 카트 수')}</th>
                    <th>{t('admin.users.legacy.table.lastActive', 'Last active')}</th>
                    <th>{t('admin.users.legacy.table.action', 'Action')}</th>
                  </tr>
                </thead>
                <tbody>
                  {legacyGuests.map((user, index) => (
                    <tr key={user.id ?? index}>
                      <td data-label={t('admin.users.legacy.table.guest', 'Guest')}>
                        <div>
                          <div style={{ fontWeight: 800 }}>{displayUserName(user)}</div>
                          <div className="tableSubtle">{user.id ?? '-'}</div>
                        </div>
                      </td>
                      <td data-label={t('admin.users.legacy.table.savedCarts', '저장 카트 수')}>
                        <div>
                          <div style={{ fontWeight: 800 }}>{formatNumber(savedCartCount(user))}</div>
                          <div className="tableSubtle">{savedCartCount(user) > 0 ? t('admin.users.legacy.hasCartHint', '보관 중인 saved cart 있음') : t('admin.users.legacy.noCartHint', '저장 카트 없음')}</div>
                        </div>
                      </td>
                      <td data-label={t('admin.users.legacy.table.lastActive', 'Last active')}>
                        <div>
                          <div style={{ fontWeight: 800 }}>{formatDate(user.lastSeenAt ?? user.lastActiveAt)}</div>
                          <div className="tableSubtle">{platformLabel(user.lastDevicePlatform)}</div>
                        </div>
                      </td>
                      <td data-label={t('admin.users.legacy.table.action', 'Action')}>
                        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                          <button className="ghostBtn ghostBtnSmall" disabled={usingFallback || busyLegacyId === user.id} onClick={() => void archiveLegacyGuest(String(user.id))}>
                            {busyLegacyId === user.id ? t('admin.users.legacy.archiving', '처리 중...') : t('admin.users.legacy.archive', 'Archive')}
                          </button>
                          <Link className="ghostBtn ghostBtnSmall" href={`/users/${user.id}`}>{t('admin.users.legacy.merge', 'Merge 판단')}</Link>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.users.list.title', 'Users')}</h2>
              <p className="pageDesc">{t('admin.users.list.desc', 'Current user list')}</p>
            </div>
          </div>

          <div className="metaRow" style={{ marginBottom: 16 }}>
            <span className="metaPill">{t('admin.users.summary.members', 'members')} {formatNumber(memberUsers.length)}</span>
            <span className="metaPill">{t('admin.users.summary.guests', 'guests')} {formatNumber(guestUsers.length)}</span>
            <span className="metaPill">{t('admin.users.summary.emailLinked', 'email linked')} {formatNumber(membersWithEmail)}</span>
          </div>

          {users.length === 0 ? (
            <div className="emptyState">{t('admin.users.list.empty', '아직 표시할 사용자가 없어')}</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>{t('admin.users.list.table.name', 'Name')}</th>
                    <th>{t('admin.users.list.table.account', 'Account')}</th>
                    <th>{t('admin.users.list.table.device', 'Device')}</th>
                    <th>{t('admin.users.list.table.lastActive', 'Last active')}</th>
                    <th>{t('admin.users.list.table.joined', 'Joined')}</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((user, index) => (
                    <tr key={user.id ?? index}>
                      <td data-label={t('admin.users.list.table.name', 'Name')}>
                        <div>
                          <div style={{ fontWeight: 800 }}>{displayUserName(user)}</div>
                          <div className="tableSubtle">{user.id ?? '-'}</div>
                        </div>
                      </td>
                      <td data-label={t('admin.users.list.table.account', 'Account')}>
                        <div>
                          <span className={`badge ${user.isGuest ? 'amber' : 'blue'}`}>{userTypeLabel(user, t)}</span>
                          <div className="tableSubtle" style={{ marginTop: 6 }}>{providerLabel(user)}{user.email ? ` · ${user.email}` : ''}</div>
                        </div>
                      </td>
                      <td data-label={t('admin.users.list.table.device', 'Device')}>
                        <div>
                          <div style={{ fontWeight: 800 }}>{platformLabel(user.lastDevicePlatform)}</div>
                          <div className="tableSubtle">{user.lastAppVersion ?? '-'}</div>
                        </div>
                      </td>
                      <td data-label={t('admin.users.list.table.lastActive', 'Last active')}>
                        <div>
                          <div style={{ fontWeight: 800 }}>{formatDate(user.lastSeenAt)}</div>
                          <div className="tableSubtle">{user.lastSeenAt ? t('admin.users.list.lastSeenHint', '최근 활동 시각') : t('admin.users.list.noActivity', '활동 기록 없음')}</div>
                        </div>
                      </td>
                      <td data-label={t('admin.users.list.table.joined', 'Joined')}>
                        <div>
                          <div style={{ fontWeight: 800 }}>{formatDate(user.createdAt)}</div>
                          <div className="tableSubtle">{t('admin.users.list.joinedHint', '가입/생성 시각')}</div>
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
    </div>
  )
}
