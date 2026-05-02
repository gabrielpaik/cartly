'use client'

import { useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson } from '../../lib/api'
import { mockPushAdmin } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type PushStatusDto = {
  enabled: boolean
  provider: string
  ready: boolean
  blockers: string[]
  firebaseProjectId: string | null
  devices: {
    total: number
    active: number
    invalid?: number
    tokenReady: number
  }
}

type PushDeviceDto = {
  id: string
  userId: string | null
  installId: string
  platform: string
  pushProvider: string | null
  hasPushToken: boolean
  notificationsEnabled: boolean
  status: string
  appVersion: string | null
  locale: string | null
  lastRegisteredAt: string | null
  lastSeenAt: string | null
  updatedAt: string | null
}

type PushCampaignDto = {
  id: string
  kind: 'notice' | 'promotion' | string
  audience: 'all' | 'members' | 'guests' | string
  status: string
  title: string
  message: string
  targetTab: 'home' | 'explore' | 'my' | null
  targetUrl: string | null
  requestedBy: string | null
  requestedBySource: string | null
  deliveryProvider: string | null
  errorMessage: string | null
  createdAt: string | null
  sentAt: string | null
}

type BroadcastResponse = {
  campaign: PushCampaignDto
  runtime: PushStatusDto
  delivery?: {
    sentCount: number
    failureCount: number
    invalidatedCount?: number
    status: string
  }
}

const PRESETS = [
  {
    label: '운영 공지',
    payload: {
      kind: 'notice' as const,
      audience: 'all' as const,
      title: 'Cartly 운영 안내',
      message: '지금 일부 기능을 점검하고 있어요. 잠시 뒤 다시 확인해 주세요.',
      targetTab: 'home' as const,
      targetUrl: '',
    },
  },
  {
    label: '영수증 등록 리마인드',
    payload: {
      kind: 'notice' as const,
      audience: 'all' as const,
      title: '영수증 등록을 잊지 마세요',
      message: '장보기가 끝났다면 저장한 카트에 영수증을 이어서 등록해 보세요.',
      targetTab: 'home' as const,
      targetUrl: '',
    },
  },
  {
    label: '혜택 알림',
    payload: {
      kind: 'promotion' as const,
      audience: 'members' as const,
      title: '지금 확인할 만한 혜택이 있어요',
      message: '탐색 탭에서 같은 구매 의도 기준으로 다시 비교해 보세요.',
      targetTab: 'explore' as const,
      targetUrl: '',
    },
  },
]

export default function PushPage() {
  const { t } = useAdminCopy()
  const statusRes = useAdminData<{ ok: boolean; data: PushStatusDto }>('/admin/push/status', {
    ok: true,
    data: mockPushAdmin.status,
  })
  const devicesRes = useAdminData<{ ok: boolean; data: { devices: PushDeviceDto[] } }>('/admin/push/devices', {
    ok: true,
    data: { devices: mockPushAdmin.devices },
  })
  const campaignsRes = useAdminData<{ ok: boolean; data: { campaigns: PushCampaignDto[] } }>('/admin/push/campaigns', {
    ok: true,
    data: { campaigns: mockPushAdmin.campaigns as PushCampaignDto[] },
  })

  const status = statusRes.data.data
  const devices = devicesRes.data.data.devices
  const campaigns = campaignsRes.data.data.campaigns

  const [kind, setKind] = useState<'notice' | 'promotion'>('notice')
  const [audience, setAudience] = useState<'all' | 'members' | 'guests'>('all')
  const [targetTab, setTargetTab] = useState<'home' | 'explore' | 'my' | ''>('home')
  const [targetUrl, setTargetUrl] = useState('')
  const [title, setTitle] = useState('')
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [sendMessage, setSendMessage] = useState<string | null>(null)

  const loading = statusRes.loading || devicesRes.loading || campaignsRes.loading
  const usingFallback = statusRes.usingFallback || devicesRes.usingFallback || campaignsRes.usingFallback
  const activeDeviceCount = status.devices.active
  const tokenReadyCount = status.devices.tokenReady
  const pushReady = status.ready && tokenReadyCount > 0

  const platformSummary = useMemo(() => {
    const counts = new Map<string, number>()
    for (const device of devices) {
      counts.set(device.platform, (counts.get(device.platform) ?? 0) + 1)
    }
    return Array.from(counts.entries())
  }, [devices])

  function applyPreset(index: number) {
    const preset = PRESETS[index]?.payload
    if (!preset) return
    setKind(preset.kind)
    setAudience(preset.audience)
    setTitle(preset.title)
    setMessage(preset.message)
    setTargetTab(preset.targetTab)
    setTargetUrl(preset.targetUrl)
  }

  async function sendPush() {
    if (!title.trim() || !message.trim()) {
      setSendMessage('제목과 본문을 먼저 넣어줘')
      return
    }

    setSending(true)
    setSendMessage(null)
    try {
      const response = await postJson<{ ok: boolean; data: BroadcastResponse }>('/admin/push/broadcast', {
        kind,
        audience,
        title: title.trim(),
        message: message.trim(),
        targetTab: targetTab || null,
        targetUrl: targetUrl.trim() || null,
      })
      const delivery = response.data.delivery
      if (delivery) {
        const invalidated = delivery.invalidatedCount ? `, stale 정리 ${delivery.invalidatedCount}` : ''
        setSendMessage(`보냈어. success ${delivery.sentCount}, fail ${delivery.failureCount}, status ${delivery.status}${invalidated}`)
      } else {
        setSendMessage(`저장했어. status ${response.data.campaign.status}`)
      }
      await Promise.allSettled([statusRes.reload(), devicesRes.reload(), campaignsRes.reload()])
    } catch (error) {
      setSendMessage(error instanceof Error ? error.message : '푸시 발송에 실패했어')
    } finally {
      setSending(false)
    }
  }

  return (
    <div>
      <PageHeader
        badge={usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.push.title', 'Push')}
        description={t('admin.push.desc', '운영 공지와 혜택 알림을 바로 보내는 운영면')}
        onRefresh={() => {
          void Promise.allSettled([statusRes.reload(), devicesRes.reload(), campaignsRes.reload()])
        }}
        refreshing={loading}
      />

      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          live push 상태를 못 읽으면 fallback으로 보여줘. 실제 발송 전에는 live badge인지 한 번 확인하는 게 안전해.
        </div>
      ) : null}

      <div className="kpiGrid">
        <StatCard label="Push runtime" value={status.ready ? 'Ready' : 'Check needed'} note={`${status.provider} · project ${status.firebaseProjectId ?? '-'}`} />
        <StatCard label="Active devices" value={String(activeDeviceCount)} note={`전체 ${status.devices.total}대 · invalid ${status.devices.invalid ?? 0}대`} />
        <StatCard label="Token ready" value={String(tokenReadyCount)} note={pushReady ? '지금 바로 발송 가능' : '토큰이 있어야 실제 전송돼'} />
        <StatCard label="Recent campaigns" value={String(campaigns.length)} note={campaigns[0]?.status ? `latest ${campaigns[0].status}` : '아직 없음'} />
      </div>

      <div className="metaRow section" style={{ marginTop: 16 }}>
        <span className="metaPill">provider {status.provider}</span>
        <span className="metaPill">firebase {status.firebaseProjectId ?? '-'}</span>
        <span className="metaPill">ready {status.ready ? 'yes' : 'no'}</span>
        <span className="metaPill">token ready {tokenReadyCount}</span>
        <span className="metaPill">invalid {status.devices.invalid ?? 0}</span>
        {platformSummary.map(([platform, count]) => (
          <span key={platform} className="metaPill">{platform} {count}</span>
        ))}
      </div>

      {!pushReady ? (
        <div className="loginError" style={{ marginTop: 16, marginBottom: 0 }}>
          지금은 실제로 받을 수 있는 토큰이 부족해. 먼저 최신 앱에서 알림 허용까지 끝나야 send가 살아나.
          {status.blockers.length > 0 ? ` (${status.blockers.join(', ')})` : ''}
        </div>
      ) : null}

      <div className="sectionGrid section" style={{ alignItems: 'start' }}>
        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>Push composer</h2>
              <p className="pageDesc" style={{ marginTop: 0, marginBottom: 0 }}>운영자가 바로 공지나 혜택 알림을 보낼 수 있는 입력면이야.</p>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 14 }}>
            {PRESETS.map((preset, index) => (
              <button key={preset.label} className="ghostBtn ghostBtnSmall" onClick={() => applyPreset(index)}>
                {preset.label}
              </button>
            ))}
          </div>

          <div style={{ display: 'grid', gap: 12 }}>
            <div className="smokeResultRow" style={{ background: '#fffafc' }}>
              <label style={{ display: 'grid', gap: 6 }}>
                <span>종류</span>
                <select value={kind} onChange={(event) => setKind(event.target.value as 'notice' | 'promotion')}>
                  <option value="notice">운영 공지</option>
                  <option value="promotion">혜택 알림</option>
                </select>
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span>대상</span>
                <select value={audience} onChange={(event) => setAudience(event.target.value as 'all' | 'members' | 'guests')}>
                  <option value="all">전체</option>
                  <option value="members">회원</option>
                  <option value="guests">게스트</option>
                </select>
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span>열릴 탭</span>
                <select value={targetTab} onChange={(event) => setTargetTab(event.target.value as 'home' | 'explore' | 'my' | '')}>
                  <option value="">없음</option>
                  <option value="home">home</option>
                  <option value="explore">explore</option>
                  <option value="my">my</option>
                </select>
              </label>
            </div>

            <label style={{ display: 'grid', gap: 6 }}>
              <span>제목</span>
              <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="예: Cartly 운영 안내" />
            </label>

            <label style={{ display: 'grid', gap: 6 }}>
              <span>본문</span>
              <textarea value={message} onChange={(event) => setMessage(event.target.value)} placeholder="예: 지금 일부 기능을 점검하고 있어요." rows={5} />
            </label>

            <label style={{ display: 'grid', gap: 6 }}>
              <span>딥링크 URL (선택)</span>
              <input value={targetUrl} onChange={(event) => setTargetUrl(event.target.value)} placeholder="https://..." />
            </label>

            <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <button className="primaryBtn" onClick={() => void sendPush()} disabled={sending}>
                {sending ? '보내는 중...' : '지금 보내기'}
              </button>
              <span className="metaPill">실제 발송은 token ready 기기만 대상</span>
            </div>

            {sendMessage ? <div className="loginError" style={{ marginBottom: 0 }}>{sendMessage}</div> : null}
          </div>
        </div>

        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>Device readiness</h2>
              <p className="pageDesc" style={{ marginTop: 0, marginBottom: 0 }}>지금 어느 기기까지 토큰 준비가 됐는지 바로 보는 카드야.</p>
            </div>
          </div>

          <div style={{ display: 'grid', gap: 10 }}>
            {devices.length === 0 ? (
              <div className="emptyState">등록된 기기가 아직 없어.</div>
            ) : (
              devices.map((device) => (
                <div key={device.id} className="smokeResultRow" style={{ padding: '12px 14px' }}>
                  <strong>{device.platform}</strong>
                  <span className="metaPill">status {device.status}</span>
                  <span className="metaPill">token {device.hasPushToken ? 'ready' : 'missing'}</span>
                  <span className="metaPill">notif {device.notificationsEnabled ? 'on' : 'off'}</span>
                  <span className="metaPill">app {device.appVersion ?? '-'}</span>
                  <span className="metaPill">locale {device.locale ?? '-'}</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      <div className="card section">
        <div className="sectionHeader">
          <div>
            <h2 className="panelTitle" style={{ marginBottom: 6 }}>Recent push activity</h2>
            <p className="pageDesc" style={{ marginTop: 0, marginBottom: 0 }}>최근 보낸 푸시와 실패 이유를 운영자가 바로 복기할 수 있게 남겨둬.</p>
          </div>
        </div>

        <div style={{ display: 'grid', gap: 10 }}>
          {campaigns.length === 0 ? (
            <div className="emptyState">아직 보낸 푸시가 없어.</div>
          ) : (
            campaigns.map((campaign) => (
              <div key={campaign.id} className="smokeResultRow" style={{ padding: '12px 14px' }}>
                <strong>{campaign.title}</strong>
                <span className="metaPill">{campaign.kind}</span>
                <span className="metaPill">{campaign.audience}</span>
                <span className="metaPill">status {campaign.status}</span>
                <span className="metaPill">sent {campaign.sentAt ?? '-'}</span>
                {campaign.targetTab ? <span className="metaPill">tab {campaign.targetTab}</span> : null}
                {campaign.errorMessage ? <div style={{ gridColumn: '1 / -1', color: '#9f1239', fontSize: 13 }}>{campaign.errorMessage}</div> : null}
                <div style={{ gridColumn: '1 / -1', color: '#475569', fontSize: 13 }}>{campaign.message}</div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
