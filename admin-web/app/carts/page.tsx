'use client'

import { useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { formatDate, formatNumber } from '../../lib/format'
import { mockCarts } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type CartRow = {
  id?: string
  title?: string | null
  userId?: string | null
  userName?: string | null
  totalValue?: number | null
  totalPrice?: number | null
  itemCount?: number | null
  totalCount?: number | null
  savedAt?: string | null
  createdAt?: string | null
  sourceCartId?: string | null
  user?: {
    id?: string | null
    displayName?: string | null
    email?: string | null
    isGuest?: boolean | null
    provider?: string | null
  } | null
}

type CartSummary = {
  totalCarts?: number
  memberCarts?: number
  guestCarts?: number
  anonymousCarts?: number
  avgCartValue?: number
  avgItemCount?: number
}

type UserTypeFilter = 'all' | 'member' | 'guest' | 'anonymous'

const fallbackData = mockCarts

function formatWon(value: number | null | undefined) {
  return `${formatNumber(value ?? 0)}원`
}

function cartTitle(cart: CartRow) {
  return cart.title?.trim() || cart.id || '-'
}

function cartUserLabel(cart: CartRow, t: (key: string, fallback?: string) => string) {
  if (cart.user?.displayName) return cart.user.displayName
  if (cart.userName) return cart.userName
  if (cart.user?.email) return cart.user.email
  if (cart.user?.isGuest) return t('admin.carts.user.guest', 'Guest')
  if (cart.userId) return cart.userId
  return t('admin.carts.user.anonymous', 'Anonymous')
}

function cartUserType(cart: CartRow, t: (key: string, fallback?: string) => string) {
  if (!cart.user && !cart.userId) return t('admin.carts.userType.anonymous', 'anonymous')
  if (cart.user?.isGuest) return t('admin.carts.userType.guest', 'guest')
  return t('admin.carts.userType.member', 'member')
}

export default function CartsPage() {
  const { t } = useAdminCopy()
  const [query, setQuery] = useState('')
  const [userType, setUserType] = useState<UserTypeFilter>('all')

  const res = useAdminData<{ ok: boolean; data: { summary?: CartSummary; carts?: CartRow[] } }>('/admin/carts', {
    ok: true,
    data: fallbackData,
  })

  const summary = res.data?.data?.summary ?? fallbackData.summary
  const carts = res.data?.data?.carts ?? []
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return carts.filter((cart) => {
      const matchesQuery = !q || [cart.title, cart.userName, cart.userId, cart.id, cart.user?.displayName, cart.user?.email].filter(Boolean).some((value) => String(value).toLowerCase().includes(q))
      const type = !cart.user && !cart.userId ? 'anonymous' : cart.user?.isGuest ? 'guest' : 'member'
      const matchesType = userType === 'all' ? true : type === userType
      return matchesQuery && matchesType
    })
  }, [carts, query, userType])

  const exportQuery = useMemo(() => {
    const params = new URLSearchParams()
    if (query.trim()) params.set('query', query.trim())
    if (userType !== 'all') params.set('userType', userType)
    const text = params.toString()
    return text ? `?${text}` : ''
  }, [query, userType])

  const filterButtons: Array<[UserTypeFilter, string]> = [
    ['all', `${t('admin.carts.filters.type.all', 'All')} (${formatNumber(summary.totalCarts ?? filtered.length)})`],
    ['member', `${t('admin.carts.filters.type.member', 'Members')} (${formatNumber(summary.memberCarts ?? 0)})`],
    ['guest', `${t('admin.carts.filters.type.guest', 'Guests')} (${formatNumber(summary.guestCarts ?? 0)})`],
    ['anonymous', `${t('admin.carts.filters.type.anonymous', 'Anonymous')} (${formatNumber(summary.anonymousCarts ?? 0)})`],
  ]

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.carts.title', 'Carts')}
        description={t('admin.carts.desc', '고객별 저장 카트 히스토리')}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.carts.warning.fallbackTitle', 'Live cart data unavailable.')}</strong>{' '}
          {t('admin.carts.warning.fallbackBody', '지금 목록은 fallback/mock data일 수 있어서 실제 저장 카트 현황과 다를 수 있어요.')}
          {res.fallbackMessage ? ` (${res.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="kpiGrid">
        <StatCard label={t('admin.carts.kpi.total', 'Total Carts')} value={formatNumber(summary.totalCarts ?? filtered.length)} note={t('admin.carts.kpi.totalNote', '현재 필터 기준 저장 카트')} />
        <StatCard label={t('admin.carts.kpi.memberGuest', 'Member / Guest')} value={`${formatNumber(summary.memberCarts ?? 0)} / ${formatNumber(summary.guestCarts ?? 0)}`} note={`${t('admin.carts.kpi.anonymous', 'anonymous')} ${formatNumber(summary.anonymousCarts ?? 0)}`} />
        <StatCard label={t('admin.carts.kpi.avgValue', 'Avg Cart Value')} value={formatWon(summary.avgCartValue ?? 0)} note={t('admin.carts.kpi.avgValueNote', '평균 저장 금액')} />
        <StatCard label={t('admin.carts.kpi.avgItems', 'Avg Item Count')} value={String(summary.avgItemCount ?? 0)} note={t('admin.carts.kpi.avgItemsNote', '카트당 평균 상품 수')} />
      </div>

      <div className="card section" style={{ marginBottom: 16 }}>
        <div className="sectionHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.carts.filters.title', '필터')}</h2>
            <p className="pageDesc">{t('admin.carts.filters.desc', '고객/카트 기준으로 조회하고 같은 조건으로 다운로드')}</p>
          </div>
        </div>

        <div className="buttonRow" style={{ flexWrap: 'wrap', marginTop: 0, marginBottom: 16 }}>
          <input className="textInput" value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('admin.carts.filters.searchPlaceholder', 'user / cart')} />
          <a className="ghostBtn pageActionBtn" href={`/api/cartly-admin/admin/carts/export.xlsx${exportQuery}`}>{t('admin.carts.filters.downloadXlsx', 'Excel(.xlsx) 다운로드')}</a>
          <a className="ghostBtn pageActionBtn" href={`/api/cartly-admin/admin/carts/export.csv${exportQuery}`}>{t('admin.carts.filters.downloadCsv', 'CSV 다운로드')}</a>
        </div>

        <div className="buttonRow" style={{ flexWrap: 'wrap', marginTop: 0 }}>
          {filterButtons.map(([key, label]) => (
            <button key={key} className={userType === key ? 'primaryBtn pageActionBtn' : 'ghostBtn pageActionBtn'} type="button" onClick={() => setUserType(key)}>
              {label}
            </button>
          ))}
        </div>
      </div>

      <div className="card">
        <div className="sectionHeader">
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.carts.history.title', '저장 카트 히스토리')}</h2>
            <p className="pageDesc">{t('admin.carts.history.desc', 'snapshot lineage와 저장 시점별 상품 구성을 함께 본다')}</p>
          </div>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">{t('admin.carts.history.filtered', 'filtered')} {formatNumber(filtered.length)}</span>
            <span className="metaPill">{t('admin.carts.history.query', 'query')} {query.trim() || '-'}</span>
          </div>
        </div>
        {filtered.length === 0 ? (
          <div className="emptyState">{t('admin.carts.history.empty', '조건에 맞는 저장 카트가 없어')}</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable">
              <thead>
                <tr>
                  <th>{t('admin.carts.history.table.cart', 'Cart')}</th>
                  <th>{t('admin.carts.history.table.user', 'User')}</th>
                  <th>{t('admin.carts.history.table.items', 'Items')}</th>
                  <th>{t('admin.carts.history.table.total', 'Total')}</th>
                  <th>{t('admin.carts.history.table.savedAt', '저장 시각')}</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((cart, index) => (
                  <tr key={cart.id ?? index}>
                    <td data-label={t('admin.carts.history.table.cart', 'Cart')}>
                      <div>
                        <div style={{ fontWeight: 800 }}>{cartTitle(cart)}</div>
                        <div className="tableSubtle">{cart.id ?? '-'}</div>
                        {cart.sourceCartId ? <div className="tableSubtle">source {cart.sourceCartId}</div> : null}
                      </div>
                    </td>
                    <td data-label={t('admin.carts.history.table.user', 'User')}>
                      <div>
                        <div style={{ fontWeight: 800 }}>{cartUserLabel(cart, t)}</div>
                        <div className="tableSubtle">{cartUserType(cart, t)}{cart.user?.email ? ` · ${cart.user.email}` : ''}</div>
                      </div>
                    </td>
                    <td data-label={t('admin.carts.history.table.items', 'Items')}>
                      <div>
                        <div style={{ fontWeight: 800 }}>{formatNumber(cart.itemCount ?? cart.totalCount ?? 0)}</div>
                        <div className="tableSubtle">{t('admin.carts.history.itemsHint', '저장된 상품 수')}</div>
                      </div>
                    </td>
                    <td data-label={t('admin.carts.history.table.total', 'Total')}>
                      <div>
                        <div style={{ fontWeight: 800 }}>{formatWon(cart.totalValue ?? cart.totalPrice ?? 0)}</div>
                        <div className="tableSubtle">{t('admin.carts.history.totalHint', '저장 시점 총액')}</div>
                      </div>
                    </td>
                    <td data-label={t('admin.carts.history.table.savedAt', '저장 시각')}>
                      <div>
                        <div style={{ fontWeight: 800 }}>{formatDate(cart.savedAt ?? cart.createdAt)}</div>
                        <div className="tableSubtle">{t('admin.carts.history.savedHint', 'saved / created timestamp')}</div>
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
