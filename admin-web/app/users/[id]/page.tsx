'use client'

import Link from 'next/link'
import { useParams } from 'next/navigation'
import { useState } from 'react'

import PageHeader from '../../../components/PageHeader'
import StatCard from '../../../components/StatCard'
import { useAdminCopy } from '../../../components/AdminCopyProvider'
import { formatDate, formatNumber } from '../../../lib/format'
import { postJson } from '../../../lib/api'
import { useAdminData } from '../../../lib/useAdminData'

type CartItemDto = {
  id: string
  name: string
  price: number
  quantity: number
}

type CartDto = {
  id: string
  sourceCartId?: string | null
  title: string | null
  savedDate?: string | null
  totalPrice: number
  totalCount: number
  createdAt: string | null
  items: CartItemDto[]
}

type UserCartDetailPayload = {
  user: {
    id: string
    displayName: string
    guestCode?: string | null
    email: string | null
    provider: string
    status?: string
    isGuest: boolean
    guestKey?: string | null
    mergedIntoUserId?: string | null
    mergedAt?: string | null
    lastDevicePlatform?: string | null
    lastAppVersion?: string | null
    createdAt: string | null
    lastSeenAt: string | null
  }
  summary: {
    totalCarts: number
    totalItems: number
    totalValue: number
    firstSavedAt: string | null
    lastSavedAt: string | null
  }
  carts: CartDto[]
}

export default function UserDetailPage() {
  const { t } = useAdminCopy()
  const params = useParams<{ id: string }>()
  const userId = Array.isArray(params?.id) ? params.id[0] : params?.id
  const [mergeTargetUserId, setMergeTargetUserId] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const res = useAdminData<{ ok: boolean; data: UserCartDetailPayload }>(`/admin/users/${userId}/carts`, {
    ok: true,
    data: {
      user: {
        id: userId ?? 'usr_mock',
        displayName: 'Guest shopper',
        email: null,
        provider: 'guest',
        status: 'active',
        isGuest: true,
        guestKey: null,
        mergedIntoUserId: null,
        mergedAt: null,
        lastDevicePlatform: 'ios',
        lastAppVersion: '0.1.0',
        createdAt: '2026-03-23T00:00:00.000Z',
        lastSeenAt: '2026-03-24T00:00:00.000Z',
      },
      summary: {
        totalCarts: 2,
        totalItems: 7,
        totalValue: 90300,
        firstSavedAt: '2026-03-23T00:00:00.000Z',
        lastSavedAt: '2026-03-24T00:00:00.000Z',
      },
      carts: [
        {
          id: 'cart_002',
          sourceCartId: 'cart_001',
          title: '최근 저장본',
          savedDate: '2026-03-24',
          totalPrice: 21900,
          totalCount: 2,
          createdAt: '2026-03-24T00:00:00.000Z',
          items: [
            { id: 'item_003', name: '우유', price: 4900, quantity: 1 },
            { id: 'item_004', name: '시리얼', price: 17000, quantity: 1 },
          ],
        },
      ],
    },
  })

  const payload = res.data.data
  const user = payload.user
  const isLegacyGuest = user.isGuest && !user.guestKey && (user.status ?? 'active') === 'active'

  async function mergeLegacyGuest() {
    if (!mergeTargetUserId.trim()) {
      setErrorMessage(t('admin.users.detail.merge.targetRequired', '대상 user id를 입력해'))
      return
    }
    setBusy(true)
    setMessage(null)
    setErrorMessage(null)
    try {
      const response = await postJson<{ ok: boolean; error?: { message?: string } }>(
        `/admin/users/${user.id}/merge-legacy`,
        { targetUserId: mergeTargetUserId.trim() },
      )
      if (!response.ok) {
        throw new Error(response.error?.message || t('admin.users.detail.merge.failed', 'legacy guest merge에 실패했어'))
      }
      setMessage(t('admin.users.detail.merge.done', 'legacy guest를 대상 user로 merge했어'))
      await res.reload()
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('admin.users.detail.merge.failed', 'legacy guest merge에 실패했어'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={user.displayName || t('admin.users.detail.title', 'Customer detail')}
        description={user.isGuest ? t('admin.users.detail.desc.guest', '게스트 고객 드릴다운') : t('admin.users.detail.desc.member', '고객 저장 이력 드릴다운')}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
      />

      <div style={{ marginBottom: 16 }}>
        <Link className="ghostBtn pageActionBtn" href="/users">
          {t('admin.users.detail.back', 'Users로 돌아가기')}
        </Link>
      </div>

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {errorMessage ? <div className="loginError" style={{ marginBottom: 16 }}>{errorMessage}</div> : null}
      {message ? <div className="saveMessage" style={{ marginBottom: 16 }}>{message}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.users.detail.warning.fallbackTitle', 'Live user detail unavailable.')}</strong>{' '}
          {t('admin.users.detail.warning.fallbackBody', '지금 화면은 fallback/mock data일 수 있어서 merge 판단 전에 live runtime 상태를 같이 확인하는 편이 안전해.')}
        </div>
      ) : null}

      <div className="kpiGrid">
        <StatCard label={t('admin.users.detail.kpi.totalCarts', 'Total carts')} value={formatNumber(payload.summary.totalCarts)} note={payload.summary.firstSavedAt ? `${t('admin.users.detail.kpi.firstSaved', 'first saved')} ${formatDate(payload.summary.firstSavedAt)}` : undefined} />
        <StatCard label={t('admin.users.detail.kpi.totalItems', 'Total items')} value={formatNumber(payload.summary.totalItems)} note={t('admin.users.detail.kpi.totalItemsNote', '모든 저장 snapshot 기준 합계')} />
        <StatCard label={t('admin.users.detail.kpi.totalValue', 'Total value')} value={`₩${formatNumber(payload.summary.totalValue)}`} note={t('admin.users.detail.kpi.totalValueNote', '누적 저장 금액')} />
        <StatCard label={t('admin.users.detail.kpi.lastSaved', '최근 저장')} value={payload.summary.lastSavedAt ? formatDate(payload.summary.lastSavedAt) : '-'} note={user.lastSeenAt ? `${t('admin.users.detail.kpi.lastSeen', 'last seen')} ${formatDate(user.lastSeenAt)}` : undefined} />
      </div>

      <div className="metaRow section" style={{ marginTop: 16 }}>
        <div className="metaPill">{t('admin.users.detail.profile.provider', 'provider')} {user.provider}</div>
        <div className="metaPill">{t('admin.users.detail.profile.type', 'type')} {user.isGuest ? t('admin.users.type.guest', 'guest') : t('admin.users.type.member', 'member')}</div>
        <div className="metaPill">{t('admin.users.detail.profile.status', 'status')} {user.status ?? 'active'}</div>
        <div className="metaPill">{t('admin.users.detail.profile.platform', 'platform')} {user.lastDevicePlatform ?? '-'}</div>
        <div className="metaPill">{t('admin.users.detail.profile.appVersion', 'app version')} {user.lastAppVersion ?? '-'}</div>
      </div>

      <div className="sectionGrid twoCol section">
        <div className="card">
          <h2 className="panelTitle">{t('admin.users.detail.profile.title', 'Customer profile')}</h2>
          <div className="metaRow">
            <div className="metaPill">{t('admin.users.detail.profile.provider', 'provider')} {user.provider}</div>
            <div className="metaPill">{t('admin.users.detail.profile.type', 'type')} {user.isGuest ? t('admin.users.type.guest', 'guest') : t('admin.users.type.member', 'member')}</div>
            <div className="metaPill">{t('admin.users.detail.profile.status', 'status')} {user.status ?? 'active'}</div>
            <div className="metaPill">{t('admin.users.detail.profile.created', 'created')} {user.createdAt ? formatDate(user.createdAt) : '-'}</div>
            <div className="metaPill">{t('admin.users.detail.profile.lastSeen', 'last seen')} {user.lastSeenAt ? formatDate(user.lastSeenAt) : '-'}</div>
          </div>
          <div style={{ marginTop: 16, display: 'grid', gap: 12 }}>
            <div><strong>{t('admin.users.detail.profile.userId', 'User ID')}</strong><div className="tableSubtle">{user.id}</div></div>
            <div><strong>Guest code</strong><div className="tableSubtle">{user.guestCode ? `Guest#${user.guestCode}` : '-'}</div></div>
            <div><strong>{t('admin.users.detail.profile.email', 'Email')}</strong><div className="tableSubtle">{user.email ?? '-'}</div></div>
            <div><strong>{t('admin.users.detail.profile.guestKey', 'Guest key')}</strong><div className="tableSubtle">{user.guestKey ?? '-'}</div></div>
            <div><strong>{t('admin.users.detail.profile.mergedInto', 'Merged into')}</strong><div className="tableSubtle">{user.mergedIntoUserId ?? '-'}</div></div>
            <div><strong>{t('admin.users.detail.profile.mergedAt', 'Merged at')}</strong><div className="tableSubtle">{user.mergedAt ? formatDate(user.mergedAt) : '-'}</div></div>
            <div><strong>{t('admin.users.detail.profile.lastPlatform', 'Last platform')}</strong><div className="tableSubtle">{user.lastDevicePlatform ?? '-'}</div></div>
            <div><strong>{t('admin.users.detail.profile.lastAppVersion', 'Last app version')}</strong><div className="tableSubtle">{user.lastAppVersion ?? '-'}</div></div>
          </div>
        </div>

        <div className="card">
          <h2 className="panelTitle">{t('admin.users.detail.cleanup.title', 'Cleanup policy')}</h2>
          <p className="pageDesc" style={{ marginTop: 0, marginBottom: 14 }}>
            {isLegacyGuest
              ? t('admin.users.detail.cleanup.legacyHint', 'legacy guest 여부와 merge 대상 확인이 핵심이야. 잘못 합치면 cart lineage가 꼬일 수 있어.')
              : t('admin.users.detail.cleanup.normalHint', '현재 계정은 정상 lineage로 보이고, install/session continuity 위주로 확인하면 돼.')}
          </p>
          {isLegacyGuest ? (
            <div>
              <p className="pageDesc" style={{ marginBottom: 14 }}>
                {t('admin.users.detail.cleanup.legacyDesc', '이 사용자는 guestKey 없이 남아 있는 legacy guest야. 카트가 있으면 자동 병합하지 않고 운영자가 대상 user id를 지정해서 수동 merge해.')}
              </p>
              <div className="formGrid">
                <label>
                  <div className="fieldLabel">{t('admin.users.detail.cleanup.targetLabel', 'Target member user id')}</div>
                  <input
                    className="textInput"
                    value={mergeTargetUserId}
                    onChange={(event) => setMergeTargetUserId(event.target.value)}
                    placeholder={t('admin.users.detail.cleanup.targetPlaceholder', 'merge 대상 user id')}
                  />
                </label>
                <button className="primaryBtn" type="button" disabled={busy} onClick={() => void mergeLegacyGuest()}>
                  {busy ? t('admin.users.detail.cleanup.merging', 'Merging...') : t('admin.users.detail.cleanup.mergeAction', 'Manual merge 실행')}
                </button>
              </div>
            </div>
          ) : (
            <ul className="inlineList">
              <li>{t('admin.users.detail.cleanup.rule1', 'same install/device reuses the same guest user when a stable guest key is present')}</li>
              <li>{t('admin.users.detail.cleanup.rule2', 'guest carts stay linked to that guest user id and preserve save-by-save snapshots')}</li>
              <li>{t('admin.users.detail.cleanup.rule3', 'sign-up/login with the same install key inherits guest history into the member account')}</li>
              <li>{t('admin.users.detail.cleanup.rule4', 'legacy guests without guestKey stay manual-review 대상이다')}</li>
            </ul>
          )}
        </div>
      </div>

      <div className="section">
        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.users.detail.history.title', '지난 카트 기록')}</h2>
              <p className="pageDesc">{t('admin.users.detail.history.desc', '한 고객의 저장 이력을 날짜별 snapshot으로 본다')}</p>
            </div>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">{payload.carts.length} {t('admin.users.detail.history.carts', 'carts')}</div>
              <div className="metaPill">{t('admin.users.detail.history.firstSaved', 'first')} {payload.summary.firstSavedAt ? formatDate(payload.summary.firstSavedAt) : '-'}</div>
              <div className="metaPill">{t('admin.users.detail.history.lastSaved', 'last')} {payload.summary.lastSavedAt ? formatDate(payload.summary.lastSavedAt) : '-'}</div>
            </div>
          </div>

          {payload.carts.length === 0 ? (
            <div className="emptyState">{t('admin.users.detail.history.empty', '아직 저장된 카트가 없어')}</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>{t('admin.users.detail.history.table.savedDate', '저장일')}</th>
                    <th>{t('admin.users.detail.history.table.snapshot', 'Snapshot')}</th>
                    <th>{t('admin.users.detail.history.table.items', 'Items')}</th>
                    <th>{t('admin.users.detail.history.table.total', 'Total')}</th>
                    <th>{t('admin.users.detail.history.table.title', 'Title')}</th>
                    <th>{t('admin.users.detail.history.table.preview', 'Preview')}</th>
                  </tr>
                </thead>
                <tbody>
                  {payload.carts.map((cart) => {
                    const preview = cart.items.slice(0, 3).map((item) => item.name).join(' · ')
                    return (
                      <tr key={cart.id}>
                        <td data-label={t('admin.users.detail.history.table.savedDate', '저장일')}>
                          <div style={{ fontWeight: 700 }}>{cart.savedDate || '-'}</div>
                          <div className="tableSubtle">{formatDate(cart.createdAt)}</div>
                        </td>
                        <td data-label={t('admin.users.detail.history.table.snapshot', 'Snapshot')}>
                          <div style={{ fontWeight: 700 }}>{cart.id.slice(0, 8)}</div>
                          <div className="tableSubtle">{cart.sourceCartId ? `${t('admin.users.detail.history.table.from', 'from')} ${cart.sourceCartId.slice(0, 8)}` : t('admin.users.detail.history.table.rootSnapshot', 'root snapshot')}</div>
                        </td>
                        <td data-label={t('admin.users.detail.history.table.items', 'Items')}>{formatNumber(cart.totalCount)}</td>
                        <td data-label={t('admin.users.detail.history.table.total', 'Total')}>{`₩${formatNumber(cart.totalPrice)}`}</td>
                        <td data-label={t('admin.users.detail.history.table.title', 'Title')}>{cart.title || '-'}</td>
                        <td data-label={t('admin.users.detail.history.table.preview', 'Preview')}>{preview || '-'}</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
