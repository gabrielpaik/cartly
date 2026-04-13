'use client'

import { useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { useAdminData } from '../../lib/useAdminData'

const fallbackData = {
  carts: [],
}

export default function CartsPage() {
  const { t } = useAdminCopy()
  const [query, setQuery] = useState('')
  const res = useAdminData<{ ok: boolean; data: { carts?: any[] } }>('/admin/carts', {
    ok: true,
    data: fallbackData,
  })

  const carts = res.data?.data?.carts ?? []
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return carts
    return carts.filter((cart: any) => [cart.title, cart.userName, cart.userId, cart.id].filter(Boolean).some((value: any) => String(value).toLowerCase().includes(q)))
  }, [carts, query])

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.carts.title', 'Carts')}
        description={t('admin.carts.desc', '고객별 저장 카트 히스토리')}
      />

      <div className="card" style={{ marginBottom: 16 }}>
        <div className="sectionHeader" style={{ marginBottom: 12 }}>
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.carts.filters.title', '필터')}</h2>
            <p className="pageDesc">{t('admin.carts.filters.desc', '고객/날짜 기준으로 조회하고 같은 조건으로 다운로드')}</p>
          </div>
        </div>
        <div className="buttonRow">
          <input className="textInput" value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('admin.carts.filters.searchPlaceholder', 'user / cart')} />
          <button className="ghostBtn pageActionBtn">{t('admin.carts.filters.downloadXlsx', 'Excel(.xlsx) 다운로드')}</button>
          <button className="ghostBtn pageActionBtn">{t('admin.carts.filters.downloadCsv', 'CSV 다운로드')}</button>
        </div>
      </div>

      <div className="card">
        <div className="sectionHeader">
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.carts.history.title', '저장 카트 히스토리')}</h2>
            <p className="pageDesc">{t('admin.carts.history.desc', 'snapshot lineage와 저장 시점별 상품 구성을 함께 본다')}</p>
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
                {filtered.map((cart: any, index: number) => (
                  <tr key={cart.id ?? index}>
                    <td>{cart.title ?? cart.id ?? '-'}</td>
                    <td>{cart.userName ?? cart.userId ?? '-'}</td>
                    <td>{cart.itemCount ?? cart.totalCount ?? '-'}</td>
                    <td>{cart.totalValue ?? cart.totalPrice ?? '-'}</td>
                    <td>{cart.savedAt ?? cart.createdAt ?? '-'}</td>
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
