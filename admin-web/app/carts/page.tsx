'use client'

import { useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson } from '../../lib/api'
import { CATEGORY_CLEAR_VALUE, LARGE_CATEGORY_OPTIONS } from '../../lib/categoryOptions'
import { formatDate, formatNumber } from '../../lib/format'
import { mockCarts } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type CartItemCategoryMeta = {
  naverLargeCategory?: string | null
  naverCategoryPath?: string | null
  categorySource?: string | null
}

type CartItemRow = {
  id?: string
  name?: string | null
  price?: number | null
  quantity?: number | null
  source?: string | null
  scanResultId?: string | null
  categoryMeta?: CartItemCategoryMeta | null
}

type CartReceiptStatus = {
  receiptId?: string | null
  receiptStatus?: string | null
  merchantName?: string | null
  hasReceipt?: boolean | null
  imageAvailable?: boolean | null
  imagePathLabel?: string | null
  purchasedAt?: string | null
  currency?: string | null
  subtotal?: number | null
  tax?: number | null
  totalAmount?: number | null
  totalDiscountAmount?: number | null
  errorMessage?: string | null
  rawText?: string | null
  updatedAt?: string | null
  completedAt?: string | null
}

type CartRow = {
  id?: string
  title?: string | null
  status?: string | null
  userId?: string | null
  userName?: string | null
  totalValue?: number | null
  totalPrice?: number | null
  itemCount?: number | null
  totalCount?: number | null
  savedAt?: string | null
  savedDate?: string | null
  createdAt?: string | null
  updatedAt?: string | null
  deletedAt?: string | null
  sourceCartId?: string | null
  expiresAt?: string | null
  isExpired?: boolean | null
  retentionExtensionCount?: number | null
  canExtendRetention?: boolean | null
  receiptStatus?: CartReceiptStatus | null
  items?: CartItemRow[] | null
  user?: {
    id?: string | null
    displayName?: string | null
    email?: string | null
    isGuest?: boolean | null
    provider?: string | null
    guestCode?: string | null
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

type CartInsightRow = {
  label: string
  count: number
  category?: string | null
}

type CategoryUpdateResponse = {
  ok: boolean
  data?: { updated?: number; category?: string | null }
  error?: { message?: string }
}

type UserTypeFilter = 'all' | 'member' | 'guest' | 'anonymous'

type FilteredCartItemRow = {
  cartId: string
  cartTitle: string
  savedAtLabel: string
  merchantLabel: string
  item: CartItemRow
}

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

function cartUserTypeKey(cart: CartRow): UserTypeFilter {
  if (!cart.user && !cart.userId) return 'anonymous'
  if (cart.user?.isGuest) return 'guest'
  return 'member'
}

function cartUserType(cart: CartRow, t: (key: string, fallback?: string) => string) {
  const key = cartUserTypeKey(cart)
  if (key === 'anonymous') return t('admin.carts.userType.anonymous', 'anonymous')
  if (key === 'guest') return t('admin.carts.userType.guest', 'guest')
  return t('admin.carts.userType.member', 'member')
}

function cartSavedDateKey(cart: CartRow) {
  return (cart.savedDate ?? cart.savedAt ?? cart.createdAt ?? '').slice(0, 10)
}

function cartSavedLabel(cart: CartRow) {
  return formatDate(cart.savedAt ?? cart.createdAt ?? cart.savedDate)
}

function merchantGroupLabel(merchantName?: string | null) {
  const raw = merchantName?.trim()
  if (!raw) return '-'
  const normalized = raw.replace(/\s+/g, ' ').trim()
  const upper = normalized.toUpperCase()

  if (normalized.includes('코스트코') || upper.includes('COSTCO')) return '코스트코'
  if (normalized.includes('이마트 트레이더스') || upper.includes('TRADERS')) return '이마트 트레이더스'
  if (normalized.includes('이마트24')) return '이마트24'
  if (normalized.includes('이마트')) return '이마트'
  if (normalized.includes('홈플러스 익스프레스')) return '홈플러스 익스프레스'
  if (normalized.includes('홈플러스')) return '홈플러스'
  if (normalized.includes('롯데마트 맥스') || upper.includes('MAXX')) return '롯데마트 맥스'
  if (normalized.includes('롯데마트')) return '롯데마트'
  if (normalized.includes('GS더프레시') || upper.includes('GS THE FRESH') || normalized.includes('GS프레시')) return 'GS더프레시'
  if (upper.includes('GS25')) return 'GS25'
  if (normalized.includes('하나로마트')) return '하나로마트'
  if (normalized.includes('메가마트')) return '메가마트'
  if (normalized.includes('노브랜드')) return '노브랜드'
  if (normalized.includes('세븐일레븐')) return '세븐일레븐'
  if (normalized.includes('씨유') || /(^|\s)CU(\s|$)/.test(upper)) return 'CU'

  return normalized
    .replace(/\s*\([^)]*점\)$/u, '')
    .replace(/\s+[가-힣A-Za-z0-9ㆍ·.-]+점$/u, '')
    .trim() || normalized
}

function receiptLabel(cart: CartRow) {
  const receipt = cart.receiptStatus
  if (!receipt?.hasReceipt) return '-'
  return [merchantGroupLabel(receipt.merchantName), receipt.receiptStatus].filter(Boolean).join(' · ') || 'receipt'
}

function receiptImageSrc(cartId: string) {
  return `/api/cartly-admin/admin/carts/${cartId}/receipt-image`
}

function itemCategoryLabel(item?: CartItemRow | null) {
  return item?.categoryMeta?.naverLargeCategory?.trim() || '미분류'
}

export default function CartsPage() {
  const { t } = useAdminCopy()
  const [query, setQuery] = useState('')
  const [userType, setUserType] = useState<UserTypeFilter>('all')
  const [savedDateFrom, setSavedDateFrom] = useState('')
  const [savedDateTo, setSavedDateTo] = useState('')
  const [selectedCartId, setSelectedCartId] = useState<string | null>(null)
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [selectedItemIds, setSelectedItemIds] = useState<string[]>([])
  const [bulkCategory, setBulkCategory] = useState('')
  const [rowCategoryDrafts, setRowCategoryDrafts] = useState<Record<string, string>>({})
  const [savingCategories, setSavingCategories] = useState(false)

  const res = useAdminData<{ ok: boolean; data: { summary?: CartSummary; carts?: CartRow[] } }>('/admin/carts?view=v5', {
    ok: true,
    data: fallbackData,
  })

  const summary = res.data?.data?.summary ?? fallbackData.summary
  const carts = res.data?.data?.carts ?? []
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return carts.filter((cart) => {
      const matchesQuery = !q || [
        cart.title,
        cart.userName,
        cart.userId,
        cart.id,
        cart.sourceCartId,
        cart.user?.displayName,
        cart.user?.email,
        cart.receiptStatus?.merchantName,
        ...(cart.items ?? []).map((item) => item.name),
      ].filter(Boolean).some((value) => String(value).toLowerCase().includes(q))
      const type = cartUserTypeKey(cart)
      const matchesType = userType === 'all' ? true : type === userType
      const savedDate = cartSavedDateKey(cart)
      const matchesDateFrom = !savedDateFrom || !savedDate || savedDate >= savedDateFrom
      const matchesDateTo = !savedDateTo || !savedDate || savedDate <= savedDateTo
      return matchesQuery && matchesType && matchesDateFrom && matchesDateTo
    })
  }, [carts, query, savedDateFrom, savedDateTo, userType])

  const exportQuery = useMemo(() => {
    const params = new URLSearchParams()
    if (query.trim()) params.set('query', query.trim())
    if (userType !== 'all') params.set('userType', userType)
    if (savedDateFrom) params.set('savedDateFrom', savedDateFrom)
    if (savedDateTo) params.set('savedDateTo', savedDateTo)
    const text = params.toString()
    return text ? `?${text}` : ''
  }, [query, savedDateFrom, savedDateTo, userType])

  const filterButtons: Array<[UserTypeFilter, string]> = [
    ['all', `${t('admin.carts.filters.type.all', 'All')} (${formatNumber(summary.totalCarts ?? filtered.length)})`],
    ['member', `${t('admin.carts.filters.type.member', 'Members')} (${formatNumber(summary.memberCarts ?? 0)})`],
    ['guest', `${t('admin.carts.filters.type.guest', 'Guests')} (${formatNumber(summary.guestCarts ?? 0)})`],
    ['anonymous', `${t('admin.carts.filters.type.anonymous', 'Anonymous')} (${formatNumber(summary.anonymousCarts ?? 0)})`],
  ]

  const selectedCart = useMemo(() => filtered.find((cart) => cart.id === selectedCartId) ?? carts.find((cart) => cart.id === selectedCartId) ?? null, [carts, filtered, selectedCartId])

  const filteredItems = useMemo<FilteredCartItemRow[]>(() => {
    return filtered.flatMap((cart) => (cart.items ?? []).map((item) => ({
      cartId: cart.id ?? '-',
      cartTitle: cartTitle(cart),
      savedAtLabel: cartSavedLabel(cart),
      merchantLabel: merchantGroupLabel(cart.receiptStatus?.merchantName),
      item,
    })))
  }, [filtered])

  const cartInsights = useMemo(() => {
    const productCounts = new Map<string, { label: string; count: number; category: string }>()
    const categoryCounts = new Map<string, number>()
    const merchantCounts = new Map<string, number>()

    for (const cart of filtered) {
      const merchantGroup = merchantGroupLabel(cart.receiptStatus?.merchantName)
      if (merchantGroup !== '-') {
        merchantCounts.set(merchantGroup, (merchantCounts.get(merchantGroup) ?? 0) + 1)
      }
      for (const item of cart.items ?? []) {
        const label = item.name?.trim()
        if (!label) continue
        const quantity = Math.max(item.quantity ?? 1, 1)
        const category = itemCategoryLabel(item)
        categoryCounts.set(category, (categoryCounts.get(category) ?? 0) + quantity)
        const key = label.toLowerCase()
        const existing = productCounts.get(key)
        if (existing) {
          existing.count += quantity
        } else {
          productCounts.set(key, { label, count: quantity, category })
        }
      }
    }

    const topCategories: CartInsightRow[] = Array.from(categoryCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([label, count]) => ({ label, count }))

    const topMerchants: CartInsightRow[] = Array.from(merchantCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([label, count]) => ({ label, count }))

    const topProducts: CartInsightRow[] = Array.from(productCounts.values())
      .sort((a, b) => b.count - a.count)
      .slice(0, 8)
      .map((row) => ({ label: row.label, count: row.count, category: row.category }))

    return {
      itemCount: filtered.reduce((sum, cart) => sum + (cart.items ?? []).reduce((itemSum, item) => itemSum + Math.max(item.quantity ?? 1, 1), 0), 0),
      receiptCount: filtered.filter((cart) => merchantGroupLabel(cart.receiptStatus?.merchantName) !== '-').length,
      topCategories,
      topMerchants,
      topProducts,
    }
  }, [filtered])

  function toggleItemSelection(itemId: string) {
    setSelectedItemIds((current) => current.includes(itemId) ? current.filter((id) => id !== itemId) : [...current, itemId])
  }

  async function saveItemCategories(itemIds: string[], categoryDraft: string) {
    if (res.usingFallback) {
      setActionMessage('fallback/mock 상태에서는 카테고리 수정이 안 돼')
      return
    }
    if (!itemIds.length) {
      setActionMessage('먼저 수정할 item을 선택해줘')
      return
    }
    if (!categoryDraft) {
      setActionMessage('적용할 카테고리를 먼저 골라줘')
      return
    }
    setSavingCategories(true)
    setActionMessage(null)
    try {
      const nextCategory = categoryDraft === CATEGORY_CLEAR_VALUE ? null : categoryDraft
      const result = await postJson<CategoryUpdateResponse>('/admin/cart-items/category', {
        itemIds,
        category: nextCategory,
      })
      if (!result.ok) {
        throw new Error(result.error?.message || 'cart item 카테고리 저장 실패')
      }
      setActionMessage(nextCategory ? `${itemIds.length}건 item 카테고리를 ${nextCategory}로 바꿨어` : `${itemIds.length}건 item 카테고리를 자동 추론으로 되돌렸어`)
      setSelectedItemIds([])
      setBulkCategory('')
      setRowCategoryDrafts({})
      await res.reload()
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : 'cart item 카테고리 저장 실패')
    } finally {
      setSavingCategories(false)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.carts.title', 'Carts')}
        description={t('admin.carts.desc', 'saved cart lineage and operator history')}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
        inlineRefresh
        actions={(
          <>
            <a className="ghostBtn pageActionBtn" href={`/api/cartly-admin/admin/carts/export.xlsx${exportQuery}`}>Excel</a>
            <a className="ghostBtn pageActionBtn" href={`/api/cartly-admin/admin/carts/export.csv${exportQuery}`}>CSV</a>
          </>
        )}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {actionMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{actionMessage}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.carts.warning.fallbackTitle', 'Live cart data unavailable.')}</strong>{' '}
          {t('admin.carts.warning.fallbackBody', '지금 목록은 fallback/mock data일 수 있어서 실제 저장 카트 현황과 다를 수 있어요.')}
          {res.fallbackMessage ? ` (${res.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Carts</div>
          <div className="exploreSummaryValue">{formatNumber(summary.totalCarts ?? filtered.length)}</div>
          <div className="exploreSummaryNote">filtered {formatNumber(filtered.length)}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Members</div>
          <div className="exploreSummaryValue">{formatNumber(summary.memberCarts ?? 0)}</div>
          <div className="exploreSummaryNote">guests {formatNumber(summary.guestCarts ?? 0)}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Anonymous</div>
          <div className="exploreSummaryValue">{formatNumber(summary.anonymousCarts ?? 0)}</div>
          <div className="exploreSummaryNote">no linked user</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Avg value</div>
          <div className="exploreSummaryValue">{formatWon(summary.avgCartValue ?? 0)}</div>
          <div className="exploreSummaryNote">saved cart total</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Avg items</div>
          <div className="exploreSummaryValue">{String(summary.avgItemCount ?? 0)}</div>
          <div className="exploreSummaryNote">items per cart</div>
        </div>
      </div>

      <div className="section sectionGrid twoCol" style={{ marginTop: 8 }}>
        <div className="card exploreDenseCard exploreSheetCard" style={{ gridColumn: '1 / -1' }}>
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Insights</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">carts {formatNumber(filtered.length)}</div>
              <div className="metaPill">receipts {formatNumber(cartInsights.receiptCount)}</div>
              <div className="metaPill">items {formatNumber(cartInsights.itemCount)}</div>
            </div>
          </div>
          <div className="scanInsightsGrid">
            <section className="scanInsightsPane">
              <div className="scanInsightsPaneTitle">Top 마트</div>
              <div className="scanInsightsList">
                {cartInsights.topMerchants.map((row) => (
                  <div className="scanInsightsRow" key={`cart-merchant-${row.label}`}>
                    <div className="scanInsightsLabelCell" title={row.label}>{row.label}</div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
              </div>
            </section>
            <section className="scanInsightsPane">
              <div className="scanInsightsPaneTitle">Top 대카테고리</div>
              <div className="scanInsightsList">
                {cartInsights.topCategories.map((row) => (
                  <div className="scanInsightsRow" key={`cart-category-${row.label}`}>
                    <div className="scanInsightsLabelCell" title={row.label}>{row.label}</div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
              </div>
            </section>
            <section className="scanInsightsPane" style={{ gridColumn: 'span 2' }}>
              <div className="scanInsightsPaneTitle">Top 최종 상품</div>
              <div className="scanInsightsList">
                {cartInsights.topProducts.map((row) => (
                  <div className="scanInsightsRow scanInsightsRowProducts" key={`cart-product-${row.label}`}>
                    <div className="scanInsightsLabelBlock">
                      <div className="scanInsightsLabelCell" title={row.label}>{row.label}</div>
                      <div className="scanInsightsMetaCell" title={row.category ?? '-'}>{row.category ?? '-'}</div>
                    </div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
              </div>
            </section>
          </div>
        </div>
      </div>

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Filter</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">type {userType}</div>
              <div className="metaPill">query {query.trim() || '-'}</div>
              <div className="metaPill">dblclick detail</div>
            </div>
          </div>
          <div className="editorSubtabRow">
            {filterButtons.map(([key, label]) => (
              <button key={key} type="button" className={`editorSubtab ${userType === key ? 'active' : ''}`} onClick={() => setUserType(key)}>
                {label}
              </button>
            ))}
          </div>
          <div className="exploreSheetFilterGrid" style={{ gridTemplateColumns: 'minmax(220px, 1fr) 140px 140px' }}>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">검색</div>
              <input className="textInput exploreSheetInput" value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('admin.carts.filters.searchPlaceholder', 'user / cart / merchant / item')} />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">저장일 시작</div>
              <input className="textInput exploreSheetInput" type="date" value={savedDateFrom} onChange={(e) => setSavedDateFrom(e.target.value)} />
            </label>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">저장일 종료</div>
              <input className="textInput exploreSheetInput" type="date" value={savedDateTo} onChange={(e) => setSavedDateTo(e.target.value)} />
            </label>
          </div>
        </div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard section">
        <div className="sectionHeader exploreSheetHeader">
          <h2 className="panelTitle" style={{ marginBottom: 0 }}>Category Ops</h2>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">visible items {formatNumber(filteredItems.length)}</span>
            <span className="metaPill">selected {formatNumber(selectedItemIds.length)}</span>
            <span className="metaPill">filtered carts 기준</span>
          </div>
        </div>
        <div style={{ display: 'grid', gap: 8, marginBottom: 10, gridTemplateColumns: 'auto auto minmax(180px, 240px) auto', alignItems: 'end' }}>
          <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setSelectedItemIds(filteredItems.map((row) => row.item.id).filter((value): value is string => Boolean(value)))} disabled={!filteredItems.length || savingCategories}>보이는 item 전체 선택</button>
          <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setSelectedItemIds([])} disabled={!selectedItemIds.length || savingCategories}>선택 해제</button>
          <label className="field" style={{ margin: 0 }}>
            <div className="exploreSheetFieldLabel">선택 카테고리</div>
            <select className="textInput exploreSheetInput" value={bulkCategory} onChange={(event) => setBulkCategory(event.target.value)} disabled={savingCategories}>
              <option value="">카테고리 선택</option>
              <option value={CATEGORY_CLEAR_VALUE}>자동 추론으로 복귀</option>
              {LARGE_CATEGORY_OPTIONS.map((option) => (
                <option key={option} value={option}>{option}</option>
              ))}
            </select>
          </label>
          <button type="button" className="ghostBtn pageActionBtn" onClick={() => void saveItemCategories(selectedItemIds, bulkCategory)} disabled={!selectedItemIds.length || !bulkCategory || savingCategories}>
            {savingCategories ? '저장중...' : `선택 ${selectedItemIds.length}건 적용`}
          </button>
        </div>
        {filteredItems.length === 0 ? (
          <div className="emptyState">현재 필터 기준으로 수정할 item이 없어</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th style={{ width: 44 }}>선택</th>
                  <th>상품</th>
                  <th>현재 카테고리</th>
                  <th>수정</th>
                  <th>Cart</th>
                  <th>마트</th>
                  <th>수량</th>
                  <th>가격</th>
                  <th>저장 시각</th>
                </tr>
              </thead>
              <tbody>
                {filteredItems.map((row, index) => {
                  const itemId = row.item.id ?? `item-${index}`
                  const rowDraft = rowCategoryDrafts[itemId] ?? (row.item.categoryMeta?.categorySource === 'admin-override-v1' ? row.item.categoryMeta?.naverLargeCategory ?? CATEGORY_CLEAR_VALUE : CATEGORY_CLEAR_VALUE)
                  return (
                    <tr key={itemId}>
                      <td>{row.item.id ? <input type="checkbox" checked={selectedItemIds.includes(row.item.id)} onChange={() => toggleItemSelection(row.item.id!)} /> : '-'}</td>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 220 }}>
                          <strong>{row.item.name ?? '-'}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{row.item.id ?? '-'}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{row.item.scanResultId ?? '-'}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <strong>{itemCategoryLabel(row.item)}</strong>
                          <span className="metaPill">{row.item.categoryMeta?.categorySource ?? '-'}</span>
                        </div>
                      </td>
                      <td>
                        {row.item.id ? (
                          <div style={{ display: 'grid', gap: 6, minWidth: 180 }}>
                            <select className="textInput exploreSheetInput" value={rowDraft} onChange={(event) => setRowCategoryDrafts((current) => ({ ...current, [itemId]: event.target.value }))} disabled={savingCategories}>
                              <option value={CATEGORY_CLEAR_VALUE}>자동 추론</option>
                              {LARGE_CATEGORY_OPTIONS.map((option) => (
                                <option key={option} value={option}>{option}</option>
                              ))}
                            </select>
                            <button className="ghostBtn ghostBtnSmall" type="button" onClick={() => void saveItemCategories([row.item.id!], rowDraft)} disabled={savingCategories}>적용</button>
                          </div>
                        ) : '-'}
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                          <strong>{row.cartTitle}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{row.cartId}</span>
                        </div>
                      </td>
                      <td>{row.merchantLabel}</td>
                      <td>{formatNumber(row.item.quantity ?? 0)}</td>
                      <td>{formatWon(row.item.price ?? 0)}</td>
                      <td>{row.savedAtLabel}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="card exploreDenseCard exploreSheetCard section">
        <div className="sectionHeader exploreSheetHeader">
          <h2 className="panelTitle" style={{ marginBottom: 0 }}>{t('admin.carts.history.title', '저장 카트 히스토리')}</h2>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">filtered {formatNumber(filtered.length)}</span>
            <span className="metaPill">range {savedDateFrom || '-'} ~ {savedDateTo || '-'}</span>
          </div>
        </div>
        {filtered.length === 0 ? (
          <div className="emptyState">{t('admin.carts.history.empty', '조건에 맞는 저장 카트가 없어')}</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>{t('admin.carts.history.table.cart', 'Cart')}</th>
                  <th>{t('admin.carts.history.table.user', 'User')}</th>
                  <th>Receipt</th>
                  <th>{t('admin.carts.history.table.items', 'Items')}</th>
                  <th>{t('admin.carts.history.table.total', 'Total')}</th>
                  <th>Lineage</th>
                  <th>{t('admin.carts.history.table.savedAt', '저장 시각')}</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((cart, index) => (
                  <tr key={cart.id ?? index} onDoubleClick={() => setSelectedCartId(cart.id ?? null)} style={{ cursor: 'pointer', background: selectedCart?.id === cart.id ? 'rgba(102, 126, 234, 0.08)' : undefined }}>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                        <strong>{cartTitle(cart)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{cart.id ?? '-'}</span>
                        <span className="metaPill">{cart.status ?? 'saved'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 180 }}>
                        <strong>{cartUserLabel(cart, t)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{cartUserType(cart, t)}{cart.user?.provider ? ` · ${cart.user.provider}` : ''}</span>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{cart.user?.email ?? cart.userId ?? '-'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 160 }}>
                        <strong>{receiptLabel(cart)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{cart.receiptStatus?.receiptId ?? '-'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4 }}>
                        <strong>{formatNumber(cart.itemCount ?? cart.totalCount ?? cart.items?.length ?? 0)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{(cart.items ?? []).slice(0, 2).map((item) => item.name).filter(Boolean).join(', ') || '-'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4 }}>
                        <strong>{formatWon(cart.totalValue ?? cart.totalPrice ?? 0)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{t('admin.carts.history.totalHint', '저장 시점 총액')}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4, minWidth: 140 }}>
                        <strong>{cart.sourceCartId ?? '-'}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>retain {cart.retentionExtensionCount ?? 0}</span>
                        {cart.isExpired ? <span className="metaPill">expired</span> : null}
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'grid', gap: 4 }}>
                        <strong>{cartSavedLabel(cart)}</strong>
                        <span style={{ color: '#64748b', fontSize: 12 }}>{cart.savedDate ?? cartSavedDateKey(cart) ?? '-'}</span>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {selectedCart ? (
        <div className="confirmOverlay" onClick={() => setSelectedCartId(null)}>
          <div className="confirmDialog" style={{ width: 'min(1040px, 100%)' }} onClick={(event) => event.stopPropagation()}>
            <div className="sectionHeader" style={{ marginBottom: 0 }}>
              <div>
                <div className="confirmTitle">Cart detail</div>
              </div>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">{selectedCart.status ?? 'saved'}</span>
                <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setSelectedCartId(null)}>닫기</button>
              </div>
            </div>

            <div style={{ display: 'grid', gap: 12 }}>
              <div className="tableWrap">
                <table className="dataTable exploreDenseTable">
                  <tbody>
                    <tr><td>Cart ID</td><td>{selectedCart.id ?? '-'}</td></tr>
                    <tr><td>제목</td><td>{cartTitle(selectedCart)}</td></tr>
                    <tr><td>고객</td><td>{cartUserLabel(selectedCart, t)}</td></tr>
                    <tr><td>유형</td><td>{cartUserType(selectedCart, t)}</td></tr>
                    <tr><td>이메일 / ID</td><td>{selectedCart.user?.email ?? selectedCart.userId ?? '-'}</td></tr>
                    <tr><td>총 상품 수</td><td>{formatNumber(selectedCart.itemCount ?? selectedCart.totalCount ?? selectedCart.items?.length ?? 0)}</td></tr>
                    <tr><td>총액</td><td>{formatWon(selectedCart.totalValue ?? selectedCart.totalPrice ?? 0)}</td></tr>
                    <tr><td>source cart</td><td>{selectedCart.sourceCartId ?? '-'}</td></tr>
                    <tr><td>저장일</td><td>{selectedCart.savedDate ?? cartSavedDateKey(selectedCart) ?? '-'}</td></tr>
                    <tr><td>저장 시각</td><td>{cartSavedLabel(selectedCart)}</td></tr>
                    <tr><td>업데이트</td><td>{formatDate(selectedCart.updatedAt)}</td></tr>
                    <tr><td>만료</td><td>{formatDate(selectedCart.expiresAt)}{selectedCart.isExpired ? ' · expired' : ''}</td></tr>
                    <tr><td>retention 연장</td><td>{selectedCart.retentionExtensionCount ?? 0}</td></tr>
                    <tr><td>영수증</td><td>{receiptLabel(selectedCart)}</td></tr>
                    <tr><td>영수증 ID</td><td>{selectedCart.receiptStatus?.receiptId ?? '-'}</td></tr>
                  </tbody>
                </table>
              </div>

              {selectedCart.receiptStatus?.hasReceipt ? (
                <div className="card exploreDenseCard exploreSheetCard" style={{ padding: 12 }}>
                  <div className="sectionHeader exploreSheetHeader">
                    <h2 className="panelTitle" style={{ marginBottom: 0 }}>영수증 인증</h2>
                    <div className="metaRow" style={{ marginTop: 0 }}>
                      <span className="metaPill">{selectedCart.receiptStatus.receiptStatus ?? '-'}</span>
                      {selectedCart.receiptStatus.completedAt ? <span className="metaPill">verified</span> : null}
                    </div>
                  </div>
                  <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'minmax(240px, 320px) minmax(0, 1fr)' }}>
                    <div className="card exploreDenseCard" style={{ padding: 12 }}>
                      {selectedCart.id && selectedCart.receiptStatus.imageAvailable ? (
                        <img src={receiptImageSrc(selectedCart.id)} alt={selectedCart.receiptStatus.imagePathLabel ?? selectedCart.receiptStatus.receiptId ?? 'receipt'} style={{ width: '100%', maxHeight: 420, objectFit: 'contain', borderRadius: 10, background: '#f8fafc', border: '1px solid rgba(15, 23, 42, 0.08)' }} />
                      ) : (
                        <div className="emptyState" style={{ minHeight: 220 }}>영수증 이미지 없음</div>
                      )}
                      {selectedCart.receiptStatus.imagePathLabel ? <div style={{ marginTop: 8, color: '#64748b', fontSize: 12 }}>{selectedCart.receiptStatus.imagePathLabel}</div> : null}
                    </div>
                    <div className="tableWrap">
                      <table className="dataTable exploreDenseTable">
                        <tbody>
                          <tr><td>Receipt ID</td><td>{selectedCart.receiptStatus.receiptId ?? '-'}</td></tr>
                          <tr><td>상태</td><td>{selectedCart.receiptStatus.receiptStatus ?? '-'}</td></tr>
                          <tr><td>마트 구분</td><td>{merchantGroupLabel(selectedCart.receiptStatus.merchantName)}</td></tr>
                          <tr><td>원문 마트명</td><td>{selectedCart.receiptStatus.merchantName ?? '-'}</td></tr>
                          <tr><td>구매 시각</td><td>{formatDate(selectedCart.receiptStatus.purchasedAt)}</td></tr>
                          <tr><td>Subtotal</td><td>{selectedCart.receiptStatus.subtotal != null ? formatWon(selectedCart.receiptStatus.subtotal) : '-'}</td></tr>
                          <tr><td>Tax</td><td>{selectedCart.receiptStatus.tax != null ? formatWon(selectedCart.receiptStatus.tax) : '-'}</td></tr>
                          <tr><td>Total</td><td>{selectedCart.receiptStatus.totalAmount != null ? formatWon(selectedCart.receiptStatus.totalAmount) : '-'}</td></tr>
                          <tr><td>Discount</td><td>{selectedCart.receiptStatus.totalDiscountAmount != null ? formatWon(selectedCart.receiptStatus.totalDiscountAmount) : '-'}</td></tr>
                          <tr><td>완료 시각</td><td>{formatDate(selectedCart.receiptStatus.completedAt ?? selectedCart.receiptStatus.updatedAt)}</td></tr>
                          <tr><td>Error</td><td style={{ whiteSpace: 'pre-wrap' }}>{selectedCart.receiptStatus.errorMessage ?? '-'}</td></tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                  {selectedCart.receiptStatus.rawText ? (
                    <details style={{ marginTop: 10 }}>
                      <summary style={{ cursor: 'pointer', fontWeight: 700 }}>receipt raw text</summary>
                      <pre style={{ marginTop: 8, padding: 12, background: '#f8fafc', borderRadius: 10, overflowX: 'auto', fontSize: 12, lineHeight: 1.45, whiteSpace: 'pre-wrap' }}>{selectedCart.receiptStatus.rawText}</pre>
                    </details>
                  ) : null}
                </div>
              ) : null}

              <div className="card exploreDenseCard exploreSheetCard" style={{ padding: 12 }}>
                <div className="sectionHeader exploreSheetHeader">
                  <h2 className="panelTitle" style={{ marginBottom: 0 }}>Items</h2>
                  <span className="metaPill">{formatNumber(selectedCart.items?.length ?? 0)}</span>
                </div>
                {selectedCart.items?.length ? (
                  <div className="tableWrap">
                    <table className="dataTable exploreDenseTable">
                      <thead>
                        <tr>
                          <th>상품</th>
                          <th>카테고리</th>
                          <th>수량</th>
                          <th>가격</th>
                          <th>합계</th>
                          <th>source</th>
                          <th>scan job</th>
                        </tr>
                      </thead>
                      <tbody>
                        {selectedCart.items.map((item, index) => (
                          <tr key={item.id ?? index}>
                            <td>
                              <div style={{ display: 'grid', gap: 4 }}>
                                <strong>{item.name ?? '-'}</strong>
                                <span style={{ color: '#64748b', fontSize: 12 }}>{item.id ?? '-'}</span>
                              </div>
                            </td>
                            <td>{itemCategoryLabel(item)}</td>
                            <td>{formatNumber(item.quantity ?? 0)}</td>
                            <td>{formatWon(item.price ?? 0)}</td>
                            <td>{formatWon((item.price ?? 0) * (item.quantity ?? 0))}</td>
                            <td>{item.source ?? '-'}</td>
                            <td>{item.scanResultId ?? '-'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <div className="emptyState">item 없음</div>
                )}
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
