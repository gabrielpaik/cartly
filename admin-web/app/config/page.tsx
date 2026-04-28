'use client'

import { useEffect, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { fetchJsonSafe, putJson } from '../../lib/api'
import { mockConfig } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type SmokeResult = {
  key: string
  label: string
  url: string
  status: number | null
  ok: boolean
  durationMs: number
  error?: string
}

type SmokeHistoryEntry = {
  checkedAt: string
  ok: boolean
  failureCount: number
  results: SmokeResult[]
}

type SmokeDto = {
  ok: boolean
  checkedAt: string
  results: SmokeResult[]
  history?: SmokeHistoryEntry[]
}

type CoupangRuntimeChange = {
  changedAt: string
  configSource: string
  enabledOverride: boolean | null
  effectiveEnabled: boolean
  operatorNote: string
}

type ConfigDto = {
  remoteScan: boolean
  adsEnabled: boolean
  serviceName?: string
  storageRoot: string
  storageRootDisplay?: string
  storageRootActual?: string
  storageWritable: boolean
  storagePaths: Record<string, string>
  storageErrors: string[]
  backendRunMode: string
  runtimeAssetsRoot: string
  runtimeAssetsRootDisplay?: string
  runtimeAssetsRootActual?: string
  brandingAssetsDir: string
  brandingAssetsDirDisplay?: string
  brandingAssetsDirActual?: string
  adsAssetsDir: string
  adsAssetsDirDisplay?: string
  adsAssetsDirActual?: string
  legacyPathCompatibilityActive?: boolean
  apiBase: string
  branding: {
    logoType: string
    logoText: string
    logoImageUrl: string | null
    splashImageUrl: string | null
  }
  publicSite: {
    dynamicLandingEnabled: boolean
    landingRoutes: string[]
    privacyRoutes: string[]
    assetsRoutePrefix: string
  }
  coupangPartners: {
    enabled: boolean
    envEnabled: boolean
    enabledOverride: boolean | null
    configSource: string
    accessKeyConfigured: boolean
    secretKeyConfigured: boolean
    affiliateReady: boolean
    operatorNote: string
    recentChanges: CoupangRuntimeChange[]
    updatedAt: string | null
  }
  smoke: SmokeDto
  smokeHistory?: SmokeHistoryEntry[]
}

export default function ConfigPage() {
  const { t } = useAdminCopy()
  const [savingCoupang, setSavingCoupang] = useState(false)
  const [runtimeMessage, setRuntimeMessage] = useState<string | null>(null)
  const [coupangNoteDraft, setCoupangNoteDraft] = useState('')
  const [smoke, setSmoke] = useState<SmokeDto>(mockConfig.smoke)
  const [smokeLoading, setSmokeLoading] = useState(false)
  const [smokeMessage, setSmokeMessage] = useState<string | null>(null)
  const res = useAdminData<{ ok: boolean; data: ConfigDto }>('/admin/config', {
    ok: true,
    data: mockConfig,
  })
  const cfg = res.data.data
  const storageRootDisplay = cfg.storageRootDisplay ?? cfg.storageRoot
  const storageRootActual = cfg.storageRootActual ?? cfg.storageRoot
  const runtimeAssetsDisplay = cfg.runtimeAssetsRootDisplay ?? cfg.runtimeAssetsRoot
  const runtimeAssetsActual = cfg.runtimeAssetsRootActual ?? cfg.runtimeAssetsRoot
  const brandingAssetsDisplay = cfg.brandingAssetsDirDisplay ?? cfg.brandingAssetsDir
  const brandingAssetsActual = cfg.brandingAssetsDirActual ?? cfg.brandingAssetsDir
  const adsAssetsDisplay = cfg.adsAssetsDirDisplay ?? cfg.adsAssetsDir
  const adsAssetsActual = cfg.adsAssetsDirActual ?? cfg.adsAssetsDir
  const storageErrorCount = cfg.storageErrors.length
  const pathCompatibility = cfg.legacyPathCompatibilityActive ? t('admin.config.compat.on', '호환 경로 유지 중') : t('admin.config.compat.off', '호환 경로 없음')
  const startupModeNote =
    cfg.backendRunMode === 'terminal-login-session'
      ? t('admin.config.runtime.startupNote', 'login-session supervisor 기준으로 부팅/로그인 후 따라 켜져야 해')
      : t('admin.config.runtime.startupNoteUnexpected', '예상한 login-session runtime 모드와 다를 수 있어 확인이 필요해')

  useEffect(() => {
    setCoupangNoteDraft(cfg.coupangPartners.operatorNote || '')
  }, [cfg.coupangPartners.operatorNote])

  async function loadSmoke() {
    setSmokeLoading(true)
    setSmokeMessage(null)
    try {
      const response = await fetchJsonSafe<SmokeDto>('/api/ops/smoke', mockConfig.smoke)
      setSmoke(response.data)
      if (response.usingFallback) {
        setSmokeMessage(response.fallbackMessage ?? 'Smoke 결과를 live로 불러오지 못했어')
      }
    } catch (error) {
      setSmokeMessage(error instanceof Error ? error.message : 'Smoke 결과를 불러오지 못했어')
    } finally {
      setSmokeLoading(false)
    }
  }

  useEffect(() => {
    void loadSmoke()
  }, [])

  useEffect(() => {
    if ((smoke.history?.length ?? 0) > 0) {
      return
    }
    if ((cfg.smokeHistory?.length ?? 0) > 0) {
      setSmoke((current) => ({ ...current, history: cfg.smokeHistory }))
    }
  }, [cfg.smokeHistory, smoke.history])

  async function saveCoupangOverride(enabledOverride: boolean | null) {
    setSavingCoupang(true)
    setRuntimeMessage(null)
    try {
      await putJson<{ ok: boolean; data: ConfigDto['coupangPartners'] }>('/admin/config/coupang-partners', {
        enabledOverride,
        operatorNote: coupangNoteDraft,
      })
      setRuntimeMessage(enabledOverride === null ? 'Coupang admin override를 해제했어' : `Coupang admin override를 ${enabledOverride ? 'ON' : 'OFF'}으로 저장했어`)
      setCoupangNoteDraft('')
      await res.reload()
    } catch (error) {
      setRuntimeMessage(error instanceof Error ? error.message : 'Coupang runtime 설정 저장에 실패했어')
    } finally {
      setSavingCoupang(false)
    }
  }

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.config.title', 'Config')}
        description={t('admin.config.desc', '런타임 설정')}
        onRefresh={() => {
          void Promise.allSettled([res.reload(), loadSmoke()])
        }}
        refreshing={res.loading || smokeLoading}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.config.warning.fallbackTitle', 'Live config unavailable.')}</strong>{' '}
          {t('admin.config.warning.fallbackBody', '지금 보이는 설정은 fallback/mock data일 수 있어서 실제 runtime 상태와 다를 수 있어요.')}
          {res.fallbackMessage ? ` (${res.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="kpiGrid">
        <StatCard label={t('admin.config.kpi.remoteScan', 'Remote Scan')} value={cfg.remoteScan ? t('admin.common.on', 'ON') : t('admin.common.off', 'OFF')} note={t('admin.config.kpi.remoteScanNote', 'remote scan API 사용 여부')} />
        <StatCard label={t('admin.config.kpi.ads', 'Ads')} value={cfg.adsEnabled ? t('admin.common.on', 'ON') : t('admin.common.off', 'OFF')} note={t('admin.config.kpi.adsNote', '광고 슬롯 활성화 여부')} />
        <StatCard label={t('admin.config.kpi.storage', 'Storage')} value={cfg.storageWritable ? t('admin.config.kpi.storageWritable', 'Writable') : t('admin.config.kpi.storageBlocked', 'Blocked')} note={storageRootDisplay} />
        <StatCard label={t('admin.config.kpi.runtimeStartup', 'Runtime Startup')} value={cfg.backendRunMode} note={startupModeNote} />
        <StatCard label={t('admin.config.kpi.pathCompatibility', 'Path Compatibility')} value={pathCompatibility} note={cfg.legacyPathCompatibilityActive ? storageRootActual : t('admin.config.compat.noteClean', 'rename 이후 clean path 상태')} />
      </div>

      <div className="metaRow section" style={{ marginTop: 16 }}>
        <span className="metaPill">{t('admin.config.meta.apiBase', 'api base')} {cfg.apiBase}</span>
        <span className="metaPill">{t('admin.config.meta.storageErrors', 'storage errors')} {storageErrorCount}</span>
        <span className="metaPill">{t('admin.config.meta.logoMode', 'logo mode')} {cfg.branding.logoType}</span>
        <span className="metaPill">{t('admin.config.meta.logoText', 'logo text')} {cfg.branding.logoText}</span>
        <span className="metaPill">public site {cfg.publicSite.dynamicLandingEnabled ? 'dynamic' : 'static'}</span>
        <span className="metaPill">coupang {cfg.coupangPartners.enabled ? 'enabled' : 'disabled'}</span>
        <span className="metaPill">smoke {smoke.ok ? 'ok' : 'check needed'}</span>
      </div>

      <div className="opsSignalGrid section" style={{ marginTop: 16 }}>
        <div className="opsSignalCard" style={{ borderColor: cfg.storageWritable ? 'rgba(34,197,94,0.18)' : 'rgba(225,29,72,0.22)', background: cfg.storageWritable ? 'rgba(240,253,244,0.7)' : 'rgba(255,241,242,0.82)' }}>
          <div className="opsSignalLabel">Storage</div>
          <div className="opsSignalValue">{cfg.storageWritable ? 'Writable' : 'Blocked'}</div>
          <div className="opsSignalHint">{storageErrorCount === 0 ? storageRootDisplay : `${storageErrorCount}개 경고 · ${storageRootDisplay}`}</div>
        </div>
        <div className="opsSignalCard" style={{ borderColor: cfg.publicSite.dynamicLandingEnabled ? 'rgba(34,197,94,0.18)' : 'rgba(245,158,11,0.24)', background: cfg.publicSite.dynamicLandingEnabled ? 'rgba(240,253,244,0.7)' : 'rgba(255,247,237,0.9)' }}>
          <div className="opsSignalLabel">Public landing</div>
          <div className="opsSignalValue">{cfg.publicSite.dynamicLandingEnabled ? 'Dynamic' : 'Static'}</div>
          <div className="opsSignalHint">landing {cfg.publicSite.landingRoutes.join(', ')} · privacy {cfg.publicSite.privacyRoutes.join(', ')}</div>
        </div>
        <div className="opsSignalCard" style={{ borderColor: cfg.coupangPartners.affiliateReady ? 'rgba(34,197,94,0.18)' : 'rgba(245,158,11,0.24)', background: cfg.coupangPartners.affiliateReady ? 'rgba(240,253,244,0.7)' : 'rgba(255,247,237,0.9)' }}>
          <div className="opsSignalLabel">Coupang runtime</div>
          <div className="opsSignalValue">{cfg.coupangPartners.enabled ? 'Enabled' : 'Disabled'}</div>
          <div className="opsSignalHint">affiliate {cfg.coupangPartners.affiliateReady ? 'ready' : 'not ready'} · source {cfg.coupangPartners.configSource}</div>
        </div>
      </div>

      <div className="sectionGrid section">
        <div className={`card ${smoke.ok ? 'successCard' : 'warnCard'}`}>
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>Operator smoke</h2>
              <p className="pageDesc" style={{ marginTop: 0, marginBottom: 0 }}>공개면, API, admin 진입점을 한 번에 확인하는 운영 점검 카드야.</p>
            </div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
              <span className="metaPill">checkedAt {smoke.checkedAt}</span>
              <button className="ghostBtn ghostBtnSmall" onClick={() => void loadSmoke()} disabled={smokeLoading}>
                {smokeLoading ? 'Checking...' : 'Run smoke'}
              </button>
            </div>
          </div>
          {smokeMessage ? <div className="loginError" style={{ marginBottom: 12 }}>{smokeMessage}</div> : null}
          <div style={{ display: 'grid', gap: 10 }}>
            {smoke.results.map((result) => (
              <div
                key={result.key}
                className="smokeResultRow"
                style={{
                  padding: '10px 12px',
                  borderRadius: 14,
                  border: `1px solid ${result.ok ? 'rgba(34,197,94,0.2)' : 'rgba(225,29,72,0.2)'}`,
                  background: result.ok ? 'rgba(240,253,244,0.75)' : 'rgba(255,241,242,0.8)',
                }}
              >
                <strong>{result.label}</strong>
                <span className="metaPill">status {result.status ?? '-'}</span>
                <span className="metaPill">{result.durationMs}ms</span>
                <a href={result.url} target="_blank" rel="noreferrer" style={{ color: '#2563eb', overflow: 'hidden', textOverflow: 'ellipsis' }}>{result.url}</a>
                <span style={{ fontWeight: 700, color: result.ok ? '#166534' : '#be123c' }}>{result.ok ? 'OK' : (result.error ?? 'CHECK')}</span>
              </div>
            ))}
          </div>

          <div style={{ display: 'grid', gap: 10, marginTop: 16 }}>
            <div className="previewSubtitle">최근 smoke 기록</div>
            {(smoke.history?.length ?? 0) === 0 ? (
              <div className="metaPill">아직 저장된 smoke 기록이 없어</div>
            ) : (
              smoke.history?.map((entry, index) => {
                const failed = entry.results.filter((result) => !result.ok)
                return (
                  <div
                    key={`${entry.checkedAt}-${index}`}
                    style={{
                      display: 'grid',
                      gap: 8,
                      padding: '10px 12px',
                      borderRadius: 14,
                      border: `1px solid ${entry.ok ? 'rgba(34,197,94,0.16)' : 'rgba(245,158,11,0.24)'}`,
                      background: entry.ok ? '#fff' : 'rgba(255,247,237,0.92)',
                    }}
                  >
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      <span className="metaPill">{entry.checkedAt}</span>
                      <span className="metaPill">result {entry.ok ? 'ok' : 'check needed'}</span>
                      <span className="metaPill">failed {entry.failureCount}</span>
                    </div>
                    <div style={{ color: '#334155', fontSize: 13, fontWeight: 600 }}>
                      {failed.length === 0
                        ? '모든 점검 대상이 정상 응답했어'
                        : failed.map((result) => `${result.label} (${result.status ?? 'ERR'}${result.error ? `, ${result.error}` : ''})`).join(' · ')}
                    </div>
                  </div>
                )
              })
            )}
          </div>
        </div>
      </div>

      <div className="sectionGrid twoCol section">
        <div className={`card ${cfg.storageWritable ? 'successCard' : 'warnCard'}`}>
          <h2 className="panelTitle">{t('admin.config.storage.title', 'Storage health')}</h2>
          <ul className="inlineList">
            <li>{t('admin.config.storage.root', 'storageRoot')}: {storageRootDisplay}</li>
            <li>{t('admin.config.storage.writable', 'storageWritable')}: {String(cfg.storageWritable)}</li>
            <li>{t('admin.config.storage.input', 'input')}: {cfg.storagePaths.input ?? '-'}</li>
            <li>{t('admin.config.storage.feedbackLogs', 'feedbackLogs')}: {cfg.storagePaths.feedbackLogs ?? '-'}</li>
            <li>{t('admin.config.storage.failureLogs', 'failureLogs')}: {cfg.storagePaths.failureLogs ?? '-'}</li>
            <li>{t('admin.config.storage.failed', 'failed')}: {cfg.storagePaths.failed ?? '-'}</li>
            <li>{t('admin.config.storage.errors', 'errors')}: {cfg.storageErrors.length === 0 ? t('admin.common.none', 'none') : cfg.storageErrors.join(' | ')}</li>
            {cfg.legacyPathCompatibilityActive ? <li>{t('admin.config.storage.actualRoot', 'actualStorageRoot')}: {storageRootActual}</li> : null}
            {cfg.legacyPathCompatibilityActive ? <li>{t('admin.config.storage.actualRuntimeAssets', 'actualRuntimeAssetsRoot')}: {runtimeAssetsActual}</li> : null}
          </ul>
        </div>

        <div className="card successCard">
          <h2 className="panelTitle">{t('admin.config.runtime.title', 'Runtime & startup')}</h2>
          <ul className="inlineList">
            <li>{t('admin.config.runtime.backendRunMode', 'backendRunMode')}: {cfg.backendRunMode}</li>
            <li>{t('admin.config.runtime.serviceName', 'serviceName')}: {cfg.serviceName ?? '-'}</li>
            <li>{t('admin.config.runtime.apiBase', 'apiBase')}: {cfg.apiBase}</li>
            <li>{t('admin.config.runtime.pathCompatibility', 'pathCompatibility')}: {pathCompatibility}</li>
            <li>{t('admin.config.runtime.runtimeAssets', 'runtimeAssetsRoot')}: {runtimeAssetsDisplay}</li>
            <li>{t('admin.config.runtime.brandingAssets', 'brandingAssetsDir')}: {brandingAssetsDisplay}</li>
            <li>{t('admin.config.runtime.adsAssets', 'adsAssetsDir')}: {adsAssetsDisplay}</li>
            {cfg.legacyPathCompatibilityActive ? <li>{t('admin.config.runtime.actualBrandingAssets', 'actualBrandingAssetsDir')}: {brandingAssetsActual}</li> : null}
            {cfg.legacyPathCompatibilityActive ? <li>{t('admin.config.runtime.actualAdsAssets', 'actualAdsAssetsDir')}: {adsAssetsActual}</li> : null}
          </ul>
        </div>
      </div>

      <div className="sectionGrid twoCol section">
        <div className="card">
          <h2 className="panelTitle">{t('admin.config.branding.title', '브랜딩')}</h2>
          <ul className="inlineList">
            <li>{t('admin.config.branding.logoType', 'logoType')}: {cfg.branding.logoType}</li>
            <li>{t('admin.config.branding.logoText', 'logoText')}: {cfg.branding.logoText}</li>
            <li>{t('admin.config.branding.logoImageUrl', 'logoImageUrl')}: {cfg.branding.logoImageUrl ?? '-'}</li>
            <li>{t('admin.config.branding.splashImageUrl', 'splashImageUrl')}: {cfg.branding.splashImageUrl ?? '-'}</li>
            <li>{t('admin.config.branding.assetsDir', 'brandingAssetsDir')}: {brandingAssetsDisplay}</li>
            <li>{t('admin.config.branding.adsAssetsDir', 'adsAssetsDir')}: {adsAssetsDisplay}</li>
            <li>{t('admin.config.branding.runtimeAssetsDir', 'runtimeAssetsRoot')}: {runtimeAssetsDisplay}</li>
          </ul>
        </div>

        <div className="card successCard">
          <h2 className="panelTitle">Public landing</h2>
          <ul className="inlineList">
            <li>mode: {cfg.publicSite.dynamicLandingEnabled ? 'dynamic app-config' : 'static'}</li>
            <li>landing routes: {cfg.publicSite.landingRoutes.join(', ')}</li>
            <li>privacy routes: {cfg.publicSite.privacyRoutes.join(', ')}</li>
            <li>branding assets: {cfg.publicSite.assetsRoutePrefix}</li>
            <li>운영 기준: 공개 랜딩/프라이버시는 admin content 수정값을 즉시 반영하는 단일 surface로 본다</li>
          </ul>
        </div>
      </div>

      <div className="sectionGrid twoCol section">
        <div className={`card ${cfg.coupangPartners.affiliateReady ? 'successCard' : 'warnCard'}`}>
          <h2 className="panelTitle">Coupang runtime</h2>
          <ul className="inlineList">
            <li>effective enabled: {String(cfg.coupangPartners.enabled)}</li>
            <li>env enabled default: {String(cfg.coupangPartners.envEnabled)}</li>
            <li>admin override: {cfg.coupangPartners.enabledOverride === null ? 'none' : String(cfg.coupangPartners.enabledOverride)}</li>
            <li>config source: {cfg.coupangPartners.configSource}</li>
            <li>access key configured: {String(cfg.coupangPartners.accessKeyConfigured)}</li>
            <li>secret key configured: {String(cfg.coupangPartners.secretKeyConfigured)}</li>
            <li>affiliate ready: {String(cfg.coupangPartners.affiliateReady)}</li>
            <li>last updated: {cfg.coupangPartners.updatedAt ?? '-'}</li>
          </ul>
          <label className="field" style={{ marginTop: 12 }}>
            <div className="fieldLabel">운영 메모</div>
            <textarea
              className="textInput"
              rows={3}
              value={coupangNoteDraft}
              onChange={(e) => setCoupangNoteDraft(e.target.value)}
              placeholder="예: 쿠팡 답변 전까지 강제 OFF 유지, 키 수령 후 smoke test 예정"
            />
          </label>
          <div className="previewSubtitle" style={{ marginTop: 8 }}>
            마지막 메모: {cfg.coupangPartners.operatorNote || '없음'}
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 12 }}>
             <button className="ghostBtn ghostBtnSmall" onClick={() => setCoupangNoteDraft(cfg.coupangPartners.operatorNote || '')} disabled={savingCoupang}>메모 되돌리기</button>
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 12 }}>
            <button className="button" onClick={() => void saveCoupangOverride(true)} disabled={savingCoupang}>Force ON</button>
            <button className="button secondary" onClick={() => void saveCoupangOverride(false)} disabled={savingCoupang}>Force OFF</button>
            <button className="button secondary" onClick={() => void saveCoupangOverride(null)} disabled={savingCoupang}>Use env default</button>
          </div>
          {runtimeMessage ? <div className="loginError" style={{ marginTop: 12 }}>{runtimeMessage}</div> : null}

          <div style={{ display: 'grid', gap: 10, marginTop: 16 }}>
            <div className="previewSubtitle">최근 변경 이력</div>
            {cfg.coupangPartners.recentChanges.length === 0 ? (
              <div className="metaPill">아직 변경 이력이 없어</div>
            ) : (
              cfg.coupangPartners.recentChanges.map((change, index) => (
                <div
                  key={`${change.changedAt}-${index}`}
                  style={{
                    display: 'grid',
                    gap: 6,
                    padding: '10px 12px',
                    borderRadius: 14,
                    border: '1px solid rgba(15,23,42,0.08)',
                    background: '#fff',
                  }}
                >
                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <span className="metaPill">{change.changedAt}</span>
                    <span className="metaPill">source {change.configSource}</span>
                    <span className="metaPill">override {change.enabledOverride === null ? 'none' : String(change.enabledOverride)}</span>
                    <span className="metaPill">effective {String(change.effectiveEnabled)}</span>
                  </div>
                  <div style={{ color: '#334155' }}>{change.operatorNote || '메모 없음'}</div>
                </div>
              ))
            )}
          </div>
        </div>

        <div className={`card ${cfg.storageWritable ? 'successCard' : 'warnCard'}`}>
          <h2 className="panelTitle">{t('admin.config.operator.title', 'Operator notes')}</h2>
          <ul className="inlineList">
            <li>{startupModeNote}</li>
            <li>{cfg.storageWritable ? t('admin.config.operator.storageHealthy', '지금 storageWritable=true 라서 NAS write 경로는 정상으로 보인다') : t('admin.config.operator.storageUnhealthy', 'storageWritable=false 면 scan/job 저장 전부 흔들릴 수 있어 먼저 runtime/storage를 봐야 해')}</li>
            <li>{cfg.legacyPathCompatibilityActive ? t('admin.config.operator.compatEnabled', 'rename 잔재 호환 경로가 아직 살아 있어서 display path와 actual path가 다를 수 있어') : t('admin.config.operator.compatDisabled', '호환 경로 없이 clean path 상태로 보인다')}</li>
            <li>{t('admin.config.operator.recoveryHint', '이상 징후가 있으면 partial restart보다 canonical runtime refresh 기준으로 복구하는 편이 안전해')}</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
