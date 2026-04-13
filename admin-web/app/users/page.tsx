'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson } from '../../lib/api'
import { useAdminData } from '../../lib/useAdminData'

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

export default function UsersPage() {
  const { t } = useAdminCopy()
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [busyLegacyId, setBusyLegacyId] = useState<string | null>(null)

  const usersRes = useAdminData<{ ok: boolean; data: { users?: any[] } }>('/admin/users', {
    ok: true,
    data: usersFallback,
  })
  const legacyGuestsRes = useAdminData<{ ok: boolean; data: { summary?: Record<string, number>; users?: any[] } }>('/admin/users/legacy-guests', {
    ok: true,
    data: legacyGuestsFallback,
  })

  useEffect(() => {
    void usersRes.reload()
    void legacyGuestsRes.reload()
  }, [])

  const users = usersRes.data?.data?.users ?? []
  const legacyGuests = legacyGuestsRes.data?.data?.users ?? []
  const loading = usersRes.loading || legacyGuestsRes.loading
  const usingFallback = usersRes.usingFallback || legacyGuestsRes.usingFallback
  const error = usersRes.error ?? legacyGuestsRes.error

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

      <div className="section sectionGrid twoCol">
        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.users.legacy.title', 'Legacy guest cleanup queue')}</h2>
              <p className="pageDesc">{t('admin.users.legacy.desc', '자동 병합은 하지 않고, 운영자가 archive/merge 판단할 대상을 모아둔 목록')}</p>
            </div>
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
                  {legacyGuests.map((u: any, index: number) => (
                    <tr key={u.id ?? index}>
                      <td>{u.isGuest && u.guestCode ? `Guest#${u.guestCode}` : (u.displayName ?? u.id ?? '-')}</td>
                      <td>{u.cartCount ?? u.savedCartCount ?? '-'}</td>
                      <td>{u.lastSeenAt ?? u.lastActiveAt ?? '-'}</td>
                      <td style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                        <button className="ghostBtn" disabled={busyLegacyId === u.id} onClick={() => void archiveLegacyGuest(String(u.id))}>
                          {busyLegacyId === u.id ? t('admin.users.legacy.archiving', '처리 중...') : t('admin.users.legacy.archive', 'Archive')}
                        </button>
                        <Link className="ghostBtn" href={`/users/${u.id}`}>{t('admin.users.legacy.merge', 'Merge 판단')}</Link>
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
          <div className="tableWrap">
            <table className="dataTable">
              <thead>
                <tr>
                  <th>{t('admin.users.list.table.name', 'Name')}</th>
                  <th>{t('admin.users.list.table.email', 'Email')}</th>
                  <th>{t('admin.users.list.table.type', 'Type')}</th>
                  <th>{t('admin.users.list.table.joined', 'Joined')}</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user: any, index: number) => (
                  <tr key={user.id ?? index}>
                    <td>{user.isGuest && user.guestCode ? `Guest#${user.guestCode}` : (user.displayName ?? '-')}</td>
                    <td>{user.email ?? '-'}</td>
                    <td>{user.type ?? (user.isGuest ? t('admin.users.type.guest', 'guest') : t('admin.users.type.member', 'member'))}</td>
                    <td>{user.createdAt ?? '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}
