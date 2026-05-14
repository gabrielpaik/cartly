'use client'

import Link from 'next/link'
import { useParams } from 'next/navigation'

import PageHeader from '../../../components/PageHeader'
import { useAdminCopy } from '../../../components/AdminCopyProvider'
import { formatDate, formatNumber } from '../../../lib/format'
import { useAdminData } from '../../../lib/useAdminData'
import { createUserDetailFallback, isLegacyGuestUser, type UserCartDetailPayload } from './detailShared'

export default function UserDetailPage() {
  const { t } = useAdminCopy()
  const params = useParams<{ id: string }>()
  const userId = Array.isArray(params?.id) ? params.id[0] : params?.id

  const res = useAdminData<{ ok: boolean; data: UserCartDetailPayload }>(`/admin/users/${userId}/carts`, {
    ok: true,
    data: createUserDetailFallback(userId),
  })

  const payload = res.data.data
  const user = payload.user
  const isLegacyGuest = isLegacyGuestUser(user)

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={user.displayName || t('admin.users.detail.title', 'Customer detail')}
        description={user.isGuest ? '게스트 고객 프로필 드릴다운' : '고객 프로필 드릴다운'}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
        inlineRefresh
        actions={(
          <>
            <Link className="ghostBtn pageActionBtn" href="/users">Users</Link>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}/history`}>Saved history</Link>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}/cleanup`}>Cleanup</Link>
          </>
        )}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.users.detail.warning.fallbackTitle', 'Live user detail unavailable.')}</strong>{' '}
          {t('admin.users.detail.warning.fallbackBody', '지금 화면은 fallback/mock data일 수 있어서 merge 판단 전에 live runtime 상태를 같이 확인하는 편이 안전해.')}
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Type</div>
          <div className="exploreSummaryValue">{user.isGuest ? 'guest' : 'member'}</div>
          <div className="exploreSummaryNote">provider {user.provider}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Saved carts</div>
          <div className="exploreSummaryValue">{formatNumber(payload.summary.totalCarts)}</div>
          <div className="exploreSummaryNote">items {formatNumber(payload.summary.totalItems)}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Total value</div>
          <div className="exploreSummaryValue">₩{formatNumber(payload.summary.totalValue)}</div>
          <div className="exploreSummaryNote">saved snapshots</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Last seen</div>
          <div className="exploreSummaryValue">{formatDate(user.lastSeenAt)}</div>
          <div className="exploreSummaryNote">platform {user.lastDevicePlatform ?? '-'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Cleanup</div>
          <div className="exploreSummaryValue">{isLegacyGuest ? 'review' : 'normal'}</div>
          <div className="exploreSummaryNote">guestKey {user.guestKey ?? '-'}</div>
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Profile</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">user {user.id}</span>
              <span className="metaPill">status {user.status ?? 'active'}</span>
            </div>
          </div>
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <tbody>
                <tr><td>User ID</td><td>{user.id}</td></tr>
                <tr><td>Display</td><td>{user.displayName || '-'}</td></tr>
                <tr><td>Guest code</td><td>{user.guestCode ? `Guest#${user.guestCode}` : '-'}</td></tr>
                <tr><td>Email</td><td>{user.email ?? '-'}</td></tr>
                <tr><td>Provider</td><td>{user.provider}</td></tr>
                <tr><td>Type</td><td>{user.isGuest ? 'guest' : 'member'}</td></tr>
                <tr><td>Guest key</td><td>{user.guestKey ?? '-'}</td></tr>
                <tr><td>Merged into</td><td>{user.mergedIntoUserId ?? '-'}</td></tr>
                <tr><td>Merged at</td><td>{formatDate(user.mergedAt)}</td></tr>
                <tr><td>Created</td><td>{formatDate(user.createdAt)}</td></tr>
                <tr><td>Last seen</td><td>{formatDate(user.lastSeenAt)}</td></tr>
                <tr><td>Platform</td><td>{user.lastDevicePlatform ?? '-'}</td></tr>
                <tr><td>App version</td><td>{user.lastAppVersion ?? '-'}</td></tr>
              </tbody>
            </table>
          </div>
        </div>

        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Drilldowns</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">separated views</span>
            </div>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}/history`}>고객 저장 이력 드릴다운</Link>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}/cleanup`}>게스트 고객 정리 / merge 드릴다운</Link>
          </div>
          <div className="tableWrap" style={{ marginTop: 12 }}>
            <table className="dataTable exploreDenseTable">
              <tbody>
                <tr><td>First saved</td><td>{formatDate(payload.summary.firstSavedAt)}</td></tr>
                <tr><td>Last saved</td><td>{formatDate(payload.summary.lastSavedAt)}</td></tr>
                <tr><td>Total carts</td><td>{formatNumber(payload.summary.totalCarts)}</td></tr>
                <tr><td>Total items</td><td>{formatNumber(payload.summary.totalItems)}</td></tr>
                <tr><td>Total value</td><td>₩{formatNumber(payload.summary.totalValue)}</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}
