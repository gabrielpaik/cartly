'use client'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { mockConfig } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

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
}

export default function ConfigPage() {
  const { t } = useAdminCopy()
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

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.config.title', 'Config')}
        description={t('admin.config.desc', '런타임 설정')}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
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
