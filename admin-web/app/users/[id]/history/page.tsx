'use client'

import Link from 'next/link'
import { useParams } from 'next/navigation'

import PageHeader from '../../../../components/PageHeader'
import { useAdminCopy } from '../../../../components/AdminCopyProvider'
import { formatDate, formatNumber } from '../../../../lib/format'
import { useAdminData } from '../../../../lib/useAdminData'
import { createUserDetailFallback, type UserCartDetailPayload } from '../detailShared'

export default function UserHistoryPage() {
  const { t } = useAdminCopy()
  const params = useParams<{ id: string }>()
  const userId = Array.isArray(params?.id) ? params.id[0] : params?.id

  const res = useAdminData<{ ok: boolean; data: UserCartDetailPayload }>(`/admin/users/${userId}/carts`, {
    ok: true,
    data: createUserDetailFallback(userId),
  })

  const payload = res.data.data
  const user = payload.user

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={`${user.displayName || 'Customer'} history`}
        description={t('admin.users.detail.history.desc', '한 고객의 저장 이력을 날짜별 snapshot으로 본다')}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
        inlineRefresh
        actions={(
          <>
            <Link className="ghostBtn pageActionBtn" href="/users">Users</Link>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}`}>Profile</Link>
            <Link className="ghostBtn pageActionBtn" href={`/users/${user.id}/cleanup`}>Cleanup</Link>
          </>
        )}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Carts</div>
          <div className="exploreSummaryValue">{formatNumber(payload.summary.totalCarts)}</div>
          <div className="exploreSummaryNote">saved snapshots</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Items</div>
          <div className="exploreSummaryValue">{formatNumber(payload.summary.totalItems)}</div>
          <div className="exploreSummaryNote">all saved items</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Value</div>
          <div className="exploreSummaryValue">₩{formatNumber(payload.summary.totalValue)}</div>
          <div className="exploreSummaryNote">cumulative</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">First</div>
          <div className="exploreSummaryValue">{formatDate(payload.summary.firstSavedAt)}</div>
          <div className="exploreSummaryNote">first saved</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Last</div>
          <div className="exploreSummaryValue">{formatDate(payload.summary.lastSavedAt)}</div>
          <div className="exploreSummaryNote">last saved</div>
        </div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard section">
        <div className="sectionHeader exploreSheetHeader">
          <h2 className="panelTitle" style={{ marginBottom: 0 }}>Saved cart history</h2>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">carts {payload.carts.length}</span>
            <span className="metaPill">user {user.id}</span>
          </div>
        </div>

        {payload.carts.length === 0 ? (
          <div className="emptyState">아직 저장된 카트가 없어</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>저장일</th>
                  <th>Snapshot</th>
                  <th>Items</th>
                  <th>Total</th>
                  <th>Title</th>
                  <th>Preview</th>
                </tr>
              </thead>
              <tbody>
                {payload.carts.map((cart) => {
                  const preview = cart.items.slice(0, 3).map((item) => item.name).join(' · ')
                  return (
                    <tr key={cart.id}>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <strong>{cart.savedDate || '-'}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{formatDate(cart.createdAt)}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 160 }}>
                          <strong>{cart.id.slice(0, 8)}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{cart.sourceCartId ? `from ${cart.sourceCartId.slice(0, 8)}` : 'root snapshot'}</span>
                        </div>
                      </td>
                      <td>{formatNumber(cart.totalCount)}</td>
                      <td>₩{formatNumber(cart.totalPrice)}</td>
                      <td>{cart.title || '-'}</td>
                      <td>{preview || '-'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
