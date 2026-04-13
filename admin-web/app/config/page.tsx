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

      <div className="kpiGrid">
        <StatCard label={t('admin.config.kpi.remoteScan', 'Remote Scan')} value={cfg.remoteScan ? t('admin.common.on', 'ON') : t('admin.common.off', 'OFF')} />
        <StatCard label={t('admin.config.kpi.ads', 'Ads')} value={cfg.adsEnabled ? t('admin.common.on', 'ON') : t('admin.common.off', 'OFF')} />
        <StatCard label={t('admin.config.kpi.storage', 'Storage')} value={cfg.storageWritable ? t('admin.config.kpi.storageWritable', 'Writable') : t('admin.config.kpi.storageBlocked', 'Blocked')} note={storageRootDisplay} />
        <StatCard label={t('admin.config.kpi.backendRun', 'Backend Run')} value={cfg.backendRunMode} note={cfg.serviceName ?? t('admin.config.kpi.backendRunNote', 'launchd direct backend는 비활성화')} />
        <StatCard label={t('admin.config.kpi.apiBase', 'API Base')} value={t('admin.config.kpi.apiBaseValue', 'Backend')} note={cfg.apiBase} />
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
          <h2 className="panelTitle">{t('admin.config.branding.title', '브랜딩')}</h2>
          <ul className="inlineList">
            <li>{t('admin.config.branding.logoType', 'logoType')}: {cfg.branding.logoType}</li>
            <li>{t('admin.config.branding.logoText', 'logoText')}: {cfg.branding.logoText}</li>
            <li>{t('admin.config.branding.logoImageUrl', 'logoImageUrl')}: {cfg.branding.logoImageUrl ?? '-'}</li>
            <li>{t('admin.config.branding.splashImageUrl', 'splashImageUrl')}: {cfg.branding.splashImageUrl ?? '-'}</li>
            <li>{t('admin.config.branding.assetsDir', 'brandingAssetsDir')}: {brandingAssetsDisplay}</li>
            <li>{t('admin.config.branding.adsAssetsDir', 'adsAssetsDir')}: {adsAssetsDisplay}</li>
            <li>{t('admin.config.branding.runtimeAssetsDir', 'runtimeAssetsRoot')}: {runtimeAssetsDisplay}</li>
            {cfg.legacyPathCompatibilityActive ? <li>{t('admin.config.branding.actualBrandingAssetsDir', 'actualBrandingAssetsDir')}: {brandingAssetsActual}</li> : null}
            {cfg.legacyPathCompatibilityActive ? <li>{t('admin.config.branding.actualAdsAssetsDir', 'actualAdsAssetsDir')}: {adsAssetsActual}</li> : null}
          </ul>
        </div>
      </div>
    </div>
  )
}
