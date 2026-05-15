'use client'

import Link from 'next/link'
import { useParams } from 'next/navigation'

import PageHeader from '../../../components/PageHeader'
import { useAdminCopy } from '../../../components/AdminCopyProvider'
import { formatDate, formatNumber } from '../../../lib/format'
import { useAdminData } from '../../../lib/useAdminData'
import { createUserDetailFallback, isLegacyGuestUser, type UserCartDetailPayload } from './detailShared'

function toneForLifecycle(stage?: string | null) {
  if (!stage) return '#475569'
  if (stage.includes('legacy')) return '#9f1239'
  if (stage.includes('dormant')) return '#92400e'
  if (stage.includes('core')) return '#1d4ed8'
  if (stage.includes('new')) return '#0f766e'
  return '#475569'
}

function toneForReachability(state?: string | null) {
  if (state === 'push_ready') return '#166534'
  if (state === 'push_blocked') return '#92400e'
  if (state === 'unreachable') return '#9f1239'
  return '#475569'
}

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
          <div className="exploreSummaryLabel">Lifecycle</div>
          <div className="exploreSummaryValue" style={{ color: toneForLifecycle(payload.lifecycle.lifecycleStage) }}>{payload.lifecycle.lifecycleLabel}</div>
          <div className="exploreSummaryNote">{payload.lifecycle.operatorActionLabel}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Reachability</div>
          <div className="exploreSummaryValue" style={{ color: toneForReachability(payload.push.reachabilityState) }}>{payload.push.reachabilityLabel}</div>
          <div className="exploreSummaryNote">{formatNumber(payload.summary.readyPushDeviceCount)} ready / {formatNumber(payload.summary.pushDeviceCount)} devices</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Visits / Scans</div>
          <div className="exploreSummaryValue">{formatNumber(payload.summary.totalSessions)} / {formatNumber(payload.summary.totalScans)}</div>
          <div className="exploreSummaryNote">feedback {formatNumber(payload.scan.acceptedFeedbackCount)} accepted</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Saved carts</div>
          <div className="exploreSummaryValue">{formatNumber(payload.summary.totalCarts)}</div>
          <div className="exploreSummaryNote">items {formatNumber(payload.summary.totalItems)} · ₩{formatNumber(payload.summary.totalValue)}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Last active</div>
          <div className="exploreSummaryValue">{formatDate(payload.activity.lastActivityAt ?? user.lastSeenAt)}</div>
          <div className="exploreSummaryNote">type {payload.activity.lastActivityType ?? 'seen'}</div>
        </div>
      </div>

      <div className="metaRow compactMetaRow section" style={{ marginTop: 8 }}>
        <span className="metaPill">user {user.id}</span>
        <span className="metaPill">status {user.status ?? 'active'}</span>
        <span className="metaPill">{payload.lifecycle.lifecycleStage}</span>
        <span className="metaPill">{payload.push.reachabilityState}</span>
        <span className="metaPill">{payload.lifecycle.operatorAction}</span>
        {isLegacyGuest ? <span className="metaPill">legacy guest review</span> : null}
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Profile</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">customer DB</span>
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
                <tr><td>Current region</td><td>{payload.regions.currentLabel ?? '-'}</td></tr>
                <tr><td>Region captured</td><td>{formatDate(payload.regions.currentCapturedAt)}</td></tr>
                <tr><td>Platform</td><td>{user.lastDevicePlatform ?? '-'}</td></tr>
                <tr><td>App version</td><td>{user.lastAppVersion ?? '-'}</td></tr>
              </tbody>
            </table>
          </div>
        </div>

        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Operator context</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">next action</span>
            </div>
          </div>
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <tbody>
                <tr><td>Lifecycle</td><td>{payload.lifecycle.lifecycleLabel}</td></tr>
                <tr><td>Reachability</td><td>{payload.push.reachabilityLabel}</td></tr>
                <tr><td>Operator action</td><td>{payload.lifecycle.operatorActionLabel}</td></tr>
                <tr><td>Days since seen</td><td>{payload.lifecycle.daysSinceSeen ?? '-'}</td></tr>
                <tr><td>Days since created</td><td>{payload.lifecycle.daysSinceCreated ?? '-'}</td></tr>
                <tr><td>Last activity</td><td>{payload.activity.lastActivityType ?? '-'} · {formatDate(payload.activity.lastActivityAt)}</td></tr>
                <tr><td>First saved</td><td>{formatDate(payload.summary.firstSavedAt)}</td></tr>
                <tr><td>Last saved</td><td>{formatDate(payload.summary.lastSavedAt)}</td></tr>
                <tr><td>Scan feedback</td><td>{formatNumber(payload.scan.acceptedFeedbackCount)} / {formatNumber(payload.scan.feedbackCount)}</td></tr>
                <tr><td>Failures</td><td>{formatNumber(payload.scan.failureCount)}</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Region activity</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">profiles {formatNumber(payload.regions.profileCount)}</span>
            </div>
          </div>
          <div className="tableWrap" style={{ marginBottom: 12 }}>
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>Region</th>
                  <th>Visits</th>
                  <th>Days</th>
                  <th>Last seen</th>
                </tr>
              </thead>
              <tbody>
                {payload.regions.profiles.length === 0 ? (
                  <tr><td colSpan={4}>지역 활동 프로필이 아직 없어</td></tr>
                ) : payload.regions.profiles.map((row) => (
                  <tr key={row.regionKey}>
                    <td>{row.label ?? row.regionKey}</td>
                    <td>{formatNumber(row.visitCount)}</td>
                    <td>{formatNumber(row.activeDayCount)}</td>
                    <td>{formatDate(row.lastSeenAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>At</th>
                  <th>Source</th>
                  <th>Region</th>
                </tr>
              </thead>
              <tbody>
                {payload.regions.recentEvents.length === 0 ? (
                  <tr><td colSpan={3}>최근 지역 이벤트가 아직 없어</td></tr>
                ) : payload.regions.recentEvents.map((row) => (
                  <tr key={row.id}>
                    <td>{formatDate(row.capturedAt)}</td>
                    <td>{row.source ?? '-'}</td>
                    <td>{row.label ?? row.regionKey}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Recent activity</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">timeline {formatNumber(payload.activity.timeline.length)}</span>
            </div>
          </div>
          {payload.activity.timeline.length === 0 ? (
            <div className="emptyState">최근 activity가 없어</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable exploreDenseTable">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>At</th>
                    <th>Title</th>
                    <th>Note</th>
                  </tr>
                </thead>
                <tbody>
                  {payload.activity.timeline.map((item, index) => (
                    <tr key={`${item.kind}-${item.at}-${index}`}>
                      <td>{item.kind}</td>
                      <td>{formatDate(item.at)}</td>
                      <td>{item.title}</td>
                      <td>{item.note ?? '-'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Push reachability</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">devices {formatNumber(payload.push.deviceCount)}</span>
              <span className="metaPill">ready {formatNumber(payload.push.readyDeviceCount)}</span>
            </div>
          </div>
          {payload.push.devices.length === 0 ? (
            <div className="emptyState">등록된 device가 없어</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable exploreDenseTable">
                <thead>
                  <tr>
                    <th>Platform</th>
                    <th>Provider</th>
                    <th>State</th>
                    <th>Version</th>
                    <th>Last seen</th>
                  </tr>
                </thead>
                <tbody>
                  {payload.push.devices.map((device) => (
                    <tr key={device.id}>
                      <td>{device.platform ?? '-'}</td>
                      <td>{device.provider ?? '-'}</td>
                      <td>{device.isReady ? 'ready' : device.notificationsEnabled ? 'token only' : 'blocked'}</td>
                      <td>{device.appVersion ?? '-'}</td>
                      <td>{formatDate(device.lastSeenAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Scan summary</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">recent {formatNumber(payload.scan.recent.length)}</span>
            </div>
          </div>
          <div className="tableWrap" style={{ marginBottom: 12 }}>
            <table className="dataTable exploreDenseTable">
              <tbody>
                <tr><td>Total scans</td><td>{formatNumber(payload.scan.totalScans)}</td></tr>
                <tr><td>Feedback accepted</td><td>{formatNumber(payload.scan.acceptedFeedbackCount)} / {formatNumber(payload.scan.feedbackCount)}</td></tr>
                <tr><td>Failure logs</td><td>{formatNumber(payload.scan.failureCount)}</td></tr>
                <tr><td>Last scan</td><td>{formatDate(payload.scan.lastScanAt)}</td></tr>
                <tr><td>Latest failure</td><td>{payload.scan.latestFailure.errorCode ?? payload.scan.latestFailure.stage ?? '-'}</td></tr>
              </tbody>
            </table>
          </div>
          <div className="metaRow" style={{ marginTop: 0, marginBottom: 12 }}>
            {payload.scan.statusSummary.map((row) => (
              <span key={row.status} className="metaPill">{row.status} {formatNumber(row.count)}</span>
            ))}
          </div>
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Created</th>
                  <th>Finished</th>
                  <th>Error</th>
                </tr>
              </thead>
              <tbody>
                {payload.scan.recent.map((scan) => (
                  <tr key={scan.id}>
                    <td>{scan.status}</td>
                    <td>{formatDate(scan.createdAt)}</td>
                    <td>{formatDate(scan.finishedAt)}</td>
                    <td>{scan.errorCode ?? scan.errorMessage ?? '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card exploreDenseCard exploreSheetCard">
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Saved carts</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">history {formatNumber(payload.carts.length)}</span>
            </div>
          </div>
          {payload.carts.length === 0 ? (
            <div className="emptyState">저장 카트가 없어</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable exploreDenseTable">
                <thead>
                  <tr>
                    <th>Saved</th>
                    <th>Title</th>
                    <th>Items</th>
                    <th>Total</th>
                  </tr>
                </thead>
                <tbody>
                  {payload.carts.slice(0, 10).map((cart) => (
                    <tr key={cart.id}>
                      <td>{formatDate(cart.createdAt)}</td>
                      <td>{cart.title ?? cart.id}</td>
                      <td>{formatNumber(cart.totalCount)}</td>
                      <td>₩{formatNumber(cart.totalPrice)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      <div className="card exploreDenseCard exploreSheetCard section">
        <div className="sectionHeader exploreSheetHeader">
          <h2 className="panelTitle" style={{ marginBottom: 0 }}>Event summary</h2>
          <div className="metaRow" style={{ marginTop: 0 }}>
            <span className="metaPill">top event groups {formatNumber(payload.activity.eventSummary.length)}</span>
          </div>
        </div>
        {payload.activity.eventSummary.length === 0 ? (
          <div className="emptyState">집계된 app event가 없어</div>
        ) : (
          <div className="tableWrap">
            <table className="dataTable exploreDenseTable">
              <thead>
                <tr>
                  <th>Event</th>
                  <th>Screen</th>
                  <th>Count</th>
                </tr>
              </thead>
              <tbody>
                {payload.activity.eventSummary.map((row, index) => (
                  <tr key={`${row.eventName}-${row.screenName}-${index}`}>
                    <td>{row.eventName}</td>
                    <td>{row.screenName ?? '-'}</td>
                    <td>{formatNumber(row.count)}</td>
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
