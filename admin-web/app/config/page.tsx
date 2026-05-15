'use client'

import { Suspense, useEffect, useState } from 'react'
import { useSearchParams } from 'next/navigation'

import PageHeader from '../../components/PageHeader'
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

type RuntimeCategoryGroup = {
  id: string
  label: string
  keywords: string[]
}

type RuntimeSettingsDto = {
  receiptReminderDelayMinutes: number
  myPageInsightsEnabled: boolean
  myPageSummaryMonths: number
  myPageTopCategoriesCount: number
  myPageTopItemsCount: number
  myPageSectionOrder: string[]
  myPageCategoryGroups: RuntimeCategoryGroup[]
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
  runtimeSettings: RuntimeSettingsDto
  smoke: SmokeDto
  smokeHistory?: SmokeHistoryEntry[]
}

function ConfigPageInner() {
  const { t } = useAdminCopy()
  const searchParams = useSearchParams()
  const [savingCoupang, setSavingCoupang] = useState(false)
  const [savingRuntime, setSavingRuntime] = useState(false)
  const [runtimeMessage, setRuntimeMessage] = useState<string | null>(null)
  const [coupangNoteDraft, setCoupangNoteDraft] = useState('')
  const [runtimeDraft, setRuntimeDraft] = useState<RuntimeSettingsDto>(mockConfig.runtimeSettings)
  const [sectionOrderDraft, setSectionOrderDraft] = useState('')
  const [categoryGroupsDraft, setCategoryGroupsDraft] = useState('')
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
  const noteDirty = coupangNoteDraft !== (cfg.coupangPartners.operatorNote || '')
  const pathCompatibility = cfg.legacyPathCompatibilityActive ? t('admin.config.compat.on', '이전 경로 호환 유지 중') : t('admin.config.compat.off', '이전 경로 호환 없음')
  const runtimeModeLabel = cfg.backendRunMode === 'terminal-login-session' || cfg.backendRunMode === 'terminal-login-session-supervised'
    ? '로그인 연동 기동'
    : cfg.backendRunMode
  const startupModeNote =
    cfg.backendRunMode === 'terminal-login-session' || cfg.backendRunMode === 'terminal-login-session-supervised'
      ? t('admin.config.runtime.startupNote', '이 머신에 로그인된 세션을 따라 서비스가 올라오는 구조야')
      : t('admin.config.runtime.startupNoteUnexpected', '예상한 로그인 세션 기동 방식과 달라서 확인이 필요해')
  const paneParam = searchParams.get('pane')
  const activePane = paneParam === 'overview' || paneParam === 'smoke' || paneParam === 'runtime' || paneParam === 'my-page' || paneParam === 'coupang'
    ? paneParam
    : 'overview'
  const configPaneOptions = [
    { id: 'overview', label: '전체 상태' },
    { id: 'smoke', label: '운영 점검' },
    { id: 'runtime', label: '저장소 / 기동' },
    { id: 'my-page', label: '마이페이지' },
    { id: 'coupang', label: '제휴 연동' },
  ] as const
  const activePaneLabel = configPaneOptions.find((pane) => pane.id === activePane)?.label ?? activePane

  useEffect(() => {
    setCoupangNoteDraft(cfg.coupangPartners.operatorNote || '')
  }, [cfg.coupangPartners.operatorNote])

  useEffect(() => {
    setRuntimeDraft(cfg.runtimeSettings)
    setSectionOrderDraft(cfg.runtimeSettings.myPageSectionOrder.join(', '))
    setCategoryGroupsDraft(JSON.stringify(cfg.runtimeSettings.myPageCategoryGroups, null, 2))
  }, [cfg.runtimeSettings])

  async function loadSmoke() {
    setSmokeLoading(true)
    setSmokeMessage(null)
    try {
      const response = await fetchJsonSafe<SmokeDto>('/api/ops/smoke', mockConfig.smoke)
      setSmoke(response.data)
      if (response.usingFallback) {
        setSmokeMessage(response.fallbackMessage ?? '운영 점검 결과를 실시간으로 가져오지 못했어')
      }
    } catch (error) {
      setSmokeMessage(error instanceof Error ? error.message : '운영 점검 결과를 불러오지 못했어')
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

  async function saveRuntimeSettings() {
    setSavingRuntime(true)
    setRuntimeMessage(null)
    try {
      const parsedGroups = JSON.parse(categoryGroupsDraft) as RuntimeCategoryGroup[]
      const parsedSectionOrder = sectionOrderDraft
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean)
      await putJson<{ ok: boolean; data: RuntimeSettingsDto }>('/admin/config/runtime-settings', {
        ...runtimeDraft,
        myPageSectionOrder: parsedSectionOrder,
        myPageCategoryGroups: parsedGroups,
      })
      setRuntimeMessage('마이페이지 요약 운영값을 저장했어')
      await res.reload()
    } catch (error) {
      setRuntimeMessage(error instanceof Error ? error.message : '마이페이지 요약 운영값 저장에 실패했어')
    } finally {
      setSavingRuntime(false)
    }
  }

  async function saveCoupangOverride(enabledOverride: boolean | null) {
    setSavingCoupang(true)
    setRuntimeMessage(null)
    try {
      await putJson<{ ok: boolean; data: ConfigDto['coupangPartners'] }>('/admin/config/coupang-partners', {
        enabledOverride,
        operatorNote: coupangNoteDraft,
      })
      setRuntimeMessage(enabledOverride === null ? '쿠팡 강제 설정을 해제했어' : `쿠팡 강제 설정을 ${enabledOverride ? '켜짐' : '꺼짐'}으로 저장했어`)
      setCoupangNoteDraft('')
      await res.reload()
    } catch (error) {
      setRuntimeMessage(error instanceof Error ? error.message : '쿠팡 연동 설정 저장에 실패했어')
    } finally {
      setSavingCoupang(false)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', '대체 데이터') : res.loading ? t('admin.common.badge.loading', '불러오는 중') : t('admin.common.badge.live', '실시간')}
        title={t('admin.config.title', 'System')}
        description={t('admin.config.desc', '운영 상태와 앱 동작 기준')}
        onRefresh={() => {
          void Promise.allSettled([res.reload(), loadSmoke()])
        }}
        refreshing={res.loading || smokeLoading}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.config.warning.fallbackTitle', '실시간 System 상태를 불러오지 못했어.')}</strong>{' '}
          {t('admin.config.warning.fallbackBody', '지금 보이는 값은 대체 데이터일 수 있어서 실제 운영 상태와 다를 수 있어요.')}
          {res.fallbackMessage ? ` (${res.fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="metaRow section" style={{ marginTop: 8, marginBottom: 12 }}>
        <span className="metaPill">화면 {activePaneLabel}</span>
        <span className="metaPill">기동 {runtimeModeLabel}</span>
        <span className="metaPill">저장공간 {cfg.storageWritable ? '정상' : '확인 필요'}</span>
        <span className="metaPill">운영 점검 {smoke.ok ? '정상' : '재확인'}</span>
      </div>

      <div className="metaRow section" style={{ marginTop: 0, marginBottom: 12 }}>
        <span className="metaPill">현재 {activePaneLabel}</span>
        <span className="metaPill">점검 {smoke.results.length}개</span>
      </div>

      {activePane === 'overview' ? (
        <>
      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">원격 스캔</div>
          <div className="exploreSummaryValue">{cfg.remoteScan ? 'ON' : 'OFF'}</div>
          <div className="exploreSummaryNote">기기 대신 서버 쪽 판독 경로 사용</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">광고 노출</div>
          <div className="exploreSummaryValue">{cfg.adsEnabled ? 'ON' : 'OFF'}</div>
          <div className="exploreSummaryNote">앱 광고 slot 운영 여부</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">저장 공간</div>
          <div className="exploreSummaryValue">{cfg.storageWritable ? '정상' : '막힘'}</div>
          <div className="exploreSummaryNote">{storageRootDisplay}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">기동 방식</div>
          <div className="exploreSummaryValue">{runtimeModeLabel}</div>
          <div className="exploreSummaryNote">{startupModeNote}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">이전 경로 호환</div>
          <div className="exploreSummaryValue">{cfg.legacyPathCompatibilityActive ? '유지 중' : '정리됨'}</div>
          <div className="exploreSummaryNote">{cfg.legacyPathCompatibilityActive ? storageRootActual : t('admin.config.compat.noteClean', '이전 이름 의존 없이 정리된 상태')}</div>
        </div>
      </div>

      <div className="metaRow section" style={{ marginTop: 8 }}>
        <span className="metaPill">API {cfg.apiBase}</span>
        <span className="metaPill">저장공간 경고 {storageErrorCount}</span>
        <span className="metaPill">로고 방식 {cfg.branding.logoType}</span>
        <span className="metaPill">로고 문구 {cfg.branding.logoText}</span>
        <span className="metaPill">공개 랜딩 {cfg.publicSite.dynamicLandingEnabled ? '동적' : '정적'}</span>
        <span className="metaPill">쿠팡 연동 {cfg.coupangPartners.enabled ? '켜짐' : '꺼짐'}</span>
        <span className="metaPill">운영 점검 {smoke.ok ? '정상' : '재확인'}</span>
      </div>

      <div className="opsSignalGrid section configCompactSignalGrid" style={{ marginTop: 12 }}>
        <div className="opsSignalCard" style={{ borderColor: cfg.storageWritable ? 'rgba(34,197,94,0.18)' : 'rgba(225,29,72,0.22)', background: cfg.storageWritable ? 'rgba(240,253,244,0.7)' : 'rgba(255,241,242,0.82)' }}>
          <div className="opsSignalLabel">저장 공간</div>
          <div className="opsSignalValue">{cfg.storageWritable ? '정상' : '막힘'}</div>
          <div className="opsSignalHint">{storageErrorCount === 0 ? storageRootDisplay : `${storageErrorCount}개 경고 · ${storageRootDisplay}`}</div>
        </div>
        <div className="opsSignalCard" style={{ borderColor: cfg.publicSite.dynamicLandingEnabled ? 'rgba(34,197,94,0.18)' : 'rgba(245,158,11,0.24)', background: cfg.publicSite.dynamicLandingEnabled ? 'rgba(240,253,244,0.7)' : 'rgba(255,247,237,0.9)' }}>
          <div className="opsSignalLabel">공개 랜딩</div>
          <div className="opsSignalValue">{cfg.publicSite.dynamicLandingEnabled ? '동적' : '정적'}</div>
          <div className="opsSignalHint">랜딩 {cfg.publicSite.landingRoutes.join(', ')} · 약관 {cfg.publicSite.privacyRoutes.join(', ')}</div>
        </div>
        <div className="opsSignalCard" style={{ borderColor: cfg.coupangPartners.affiliateReady ? 'rgba(34,197,94,0.18)' : 'rgba(245,158,11,0.24)', background: cfg.coupangPartners.affiliateReady ? 'rgba(240,253,244,0.7)' : 'rgba(255,247,237,0.9)' }}>
          <div className="opsSignalLabel">쿠팡 제휴</div>
          <div className="opsSignalValue">{cfg.coupangPartners.enabled ? '켜짐' : '꺼짐'}</div>
          <div className="opsSignalHint">제휴 준비 {cfg.coupangPartners.affiliateReady ? '완료' : '미완료'} · 기준 {cfg.coupangPartners.configSource}</div>
        </div>
      </div>

      </>
      ) : null}

      {activePane === 'smoke' ? (
      <div className="sectionGrid section">
        <div className={`card exploreDenseCard exploreSheetCard configPaneCard ${smoke.ok ? 'successCard' : 'warnCard'}`}>
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 10 }}>
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 0 }}>운영 점검</h2>
            </div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
              <span className="metaPill">점검 시각 {smoke.checkedAt}</span>
              <button className="ghostBtn ghostBtnSmall" onClick={() => void loadSmoke()} disabled={smokeLoading}>
                {smokeLoading ? '점검중...' : '점검 다시 실행'}
              </button>
            </div>
          </div>
          {smokeMessage ? <div className="loginError" style={{ marginBottom: 12 }}>{smokeMessage}</div> : null}
          <div className="configSmokeGrid">
            {smoke.results.map((result) => (
              <div
                key={result.key}
                className="smokeResultRow configSmokeRow"
                style={{
                  border: `1px solid ${result.ok ? 'rgba(34,197,94,0.2)' : 'rgba(225,29,72,0.2)'}`,
                  background: result.ok ? 'rgba(240,253,244,0.75)' : 'rgba(255,241,242,0.8)',
                }}
              >
                <strong>{result.label}</strong>
                <span className="metaPill">응답 {result.status ?? '-'}</span>
                <span className="metaPill">{result.durationMs}ms</span>
                <a href={result.url} target="_blank" rel="noreferrer" style={{ color: '#2563eb', overflow: 'hidden', textOverflow: 'ellipsis' }}>{result.url}</a>
                <span style={{ fontWeight: 700, color: result.ok ? '#166534' : '#be123c' }}>{result.ok ? '정상' : (result.error ?? '확인 필요')}</span>
              </div>
            ))}
          </div>

          <div className="configHistoryStack">
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">기록 {smoke.history?.length ?? 0}개</span>            </div>
            {(smoke.history?.length ?? 0) === 0 ? (
              <div className="metaPill">아직 저장된 smoke 기록이 없어</div>
            ) : (
              smoke.history?.map((entry, index) => {
                const failed = entry.results.filter((result) => !result.ok)
                return (
                  <div
                    key={`${entry.checkedAt}-${index}`}
                    className="configHistoryCard"
                    style={{
                      border: `1px solid ${entry.ok ? 'rgba(34,197,94,0.16)' : 'rgba(245,158,11,0.24)'}`,
                      background: entry.ok ? '#fff' : 'rgba(255,247,237,0.92)',
                    }}
                  >
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      <span className="metaPill">{entry.checkedAt}</span>
                      <span className="metaPill">결과 {entry.ok ? '정상' : '재확인'}</span>
                      <span className="metaPill">실패 {entry.failureCount}</span>                    </div>
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
      ) : null}

      {activePane === 'runtime' ? (
      <div className="sectionGrid twoCol section configTwoColSection">
        <div className={`card exploreDenseCard exploreSheetCard configPaneCard ${cfg.storageWritable ? 'successCard' : 'warnCard'}`}>
          <h2 className="panelTitle">{t('admin.config.storage.title', '저장 공간 상태')}</h2>
          <div className="tableWrap">
            <table className="dataTable">
              <tbody>
                <tr><th>항목</th><th>현재값</th></tr>
                <tr><td>{t('admin.config.storage.root', '기준 저장 루트')}</td><td>{storageRootDisplay}</td></tr>
                <tr><td>{t('admin.config.storage.writable', '쓰기 가능')}</td><td>{cfg.storageWritable ? '예' : '아니오'}</td></tr>
                <tr><td>{t('admin.config.storage.input', '입력 보관')}</td><td>{cfg.storagePaths.input ?? '-'}</td></tr>
                <tr><td>{t('admin.config.storage.feedbackLogs', '피드백 로그')}</td><td>{cfg.storagePaths.feedbackLogs ?? '-'}</td></tr>
                <tr><td>{t('admin.config.storage.failureLogs', '실패 로그')}</td><td>{cfg.storagePaths.failureLogs ?? '-'}</td></tr>
                <tr><td>{t('admin.config.storage.failed', '실패 보관함')}</td><td>{cfg.storagePaths.failed ?? '-'}</td></tr>
                <tr><td>{t('admin.config.storage.errors', '저장 공간 경고')}</td><td>{cfg.storageErrors.length === 0 ? t('admin.common.none', '없음') : cfg.storageErrors.join(' | ')}</td></tr>
                {cfg.legacyPathCompatibilityActive ? <tr><td>{t('admin.config.storage.actualRoot', '실제 저장 루트')}</td><td>{storageRootActual}</td></tr> : null}
                {cfg.legacyPathCompatibilityActive ? <tr><td>{t('admin.config.storage.actualRuntimeAssets', '실제 런타임 자산 루트')}</td><td>{runtimeAssetsActual}</td></tr> : null}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card exploreDenseCard exploreSheetCard configPaneCard successCard">
          <h2 className="panelTitle">{t('admin.config.runtime.title', '기동 / 자산 경로')}</h2>
          <div className="tableWrap">
            <table className="dataTable">
              <tbody>
                <tr><th>항목</th><th>현재값</th></tr>
                <tr><td>{t('admin.config.runtime.backendRunMode', '기동 방식')}</td><td>{runtimeModeLabel}</td></tr>
                <tr><td>{t('admin.config.runtime.serviceName', '서비스 이름')}</td><td>{cfg.serviceName ?? '-'}</td></tr>
                <tr><td>{t('admin.config.runtime.apiBase', 'API 기준 주소')}</td><td>{cfg.apiBase}</td></tr>
                <tr><td>{t('admin.config.runtime.pathCompatibility', '이전 경로 호환')}</td><td>{pathCompatibility}</td></tr>
                <tr><td>{t('admin.config.runtime.runtimeAssets', '런타임 자산 루트')}</td><td>{runtimeAssetsDisplay}</td></tr>
                <tr><td>{t('admin.config.runtime.brandingAssets', '브랜딩 자산 폴더')}</td><td>{brandingAssetsDisplay}</td></tr>
                <tr><td>{t('admin.config.runtime.adsAssets', '광고 자산 폴더')}</td><td>{adsAssetsDisplay}</td></tr>
                {cfg.legacyPathCompatibilityActive ? <tr><td>{t('admin.config.runtime.actualBrandingAssets', '실제 브랜딩 자산 폴더')}</td><td>{brandingAssetsActual}</td></tr> : null}
                {cfg.legacyPathCompatibilityActive ? <tr><td>{t('admin.config.runtime.actualAdsAssets', '실제 광고 자산 폴더')}</td><td>{adsAssetsActual}</td></tr> : null}
              </tbody>
            </table>
          </div>
        </div>
      </div>
      ) : null}

      {activePane === 'my-page' ? (
      <div className="sectionGrid twoCol section configTwoColSection">
        <div className="card exploreDenseCard exploreSheetCard configPaneCard configFormCard">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 8 }}>
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 0 }}>마이페이지 요약 운영값</h2>
            </div>
            <div className="buttonRow configInlineButtonRow">
              <button className="primaryBtn" onClick={() => void saveRuntimeSettings()} disabled={savingRuntime}>저장</button>
              <button className="ghostBtn ghostBtnSmall" onClick={() => {
                setRuntimeDraft(cfg.runtimeSettings)
                setSectionOrderDraft(cfg.runtimeSettings.myPageSectionOrder.join(', '))
                setCategoryGroupsDraft(JSON.stringify(cfg.runtimeSettings.myPageCategoryGroups, null, 2))
              }} disabled={savingRuntime}>되돌리기</button>
            </div>
          </div>
          <div className="metaRow" style={{ marginTop: 0, marginBottom: 10 }}>
            <span className="metaPill">상태 {runtimeDraft.myPageInsightsEnabled ? '켜짐' : '꺼짐'}</span>
            <span className="metaPill">기간 {runtimeDraft.myPageSummaryMonths}개월</span>
            <span className="metaPill">카테고리 {runtimeDraft.myPageTopCategoriesCount}개</span>
            <span className="metaPill">자주 담은 상품 {runtimeDraft.myPageTopItemsCount}개</span>
            <span className="metaPill">순서 {runtimeDraft.myPageSectionOrder.join(' > ')}</span>
          </div>
          <div className="configMiniControlGrid">
            <label className="field configMiniControlCard configToggleField">
              <div className="fieldLabel">활성화</div>
              <input type="checkbox" checked={runtimeDraft.myPageInsightsEnabled} onChange={(e) => setRuntimeDraft((current) => ({ ...current, myPageInsightsEnabled: e.target.checked }))} />
            </label>
            <label className="field configMiniControlCard">
              <div className="fieldLabel">리마인더 지연(분)</div>
              <input className="textInput" type="number" min={1} value={runtimeDraft.receiptReminderDelayMinutes} onChange={(e) => setRuntimeDraft((current) => ({ ...current, receiptReminderDelayMinutes: Number(e.target.value || 60) }))} />
            </label>
            <label className="field configMiniControlCard">
              <div className="fieldLabel">월 수</div>
              <input className="textInput" type="number" min={1} max={12} value={runtimeDraft.myPageSummaryMonths} onChange={(e) => setRuntimeDraft((current) => ({ ...current, myPageSummaryMonths: Number(e.target.value || 3) }))} />
            </label>
            <label className="field configMiniControlCard">
              <div className="fieldLabel">상위 카테고리 수</div>
              <input className="textInput" type="number" min={1} max={8} value={runtimeDraft.myPageTopCategoriesCount} onChange={(e) => setRuntimeDraft((current) => ({ ...current, myPageTopCategoriesCount: Number(e.target.value || 3) }))} />
            </label>
            <label className="field configMiniControlCard">
              <div className="fieldLabel">자주 담은 상품 수</div>
              <input className="textInput" type="number" min={1} max={8} value={runtimeDraft.myPageTopItemsCount} onChange={(e) => setRuntimeDraft((current) => ({ ...current, myPageTopItemsCount: Number(e.target.value || 3) }))} />
            </label>
          </div>
          <div className="configEditorGrid">
            <div className="configInlineSubcard">
              <div className="configSubcardTitle">노출 순서</div>
              <label className="field">
                <div className="fieldLabel">섹션 순서 (쉼표로 구분)</div>
                <input className="textInput" value={sectionOrderDraft} onChange={(e) => setSectionOrderDraft(e.target.value)} placeholder="recentSaved, monthlySummary, allSavedHistory" />
              </label>
              <div className="saveMessage">사용 가능값: recentSaved, monthlySummary, allSavedHistory</div>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">저장된 묶음 {cfg.runtimeSettings.myPageCategoryGroups.length}</span>
                <span className="metaPill">현재 순서 {cfg.runtimeSettings.myPageSectionOrder.join(' > ')}</span>
              </div>
            </div>
            <div className="configInlineSubcard">
              <div className="configSubcardTitle">카테고리 묶음</div>
              <label className="field">
                <div className="fieldLabel">고급 규칙(JSON 배열)</div>
                <textarea className="textInput configJsonEditor" rows={9} value={categoryGroupsDraft} onChange={(e) => setCategoryGroupsDraft(e.target.value)} />
              </label>
            </div>
          </div>
          {runtimeMessage ? <div className="loginError" style={{ marginTop: 10 }}>{runtimeMessage}</div> : null}
        </div>

        <div className="card exploreDenseCard exploreSheetCard configPaneCard">
          <h2 className="panelTitle">{t('admin.config.branding.title', '브랜딩 자산')}</h2>
          <div className="tableWrap">
            <table className="dataTable">
              <tbody>
                <tr><th>key</th><th>value</th></tr>
                <tr><td>{t('admin.config.branding.logoType', '로고 방식')}</td><td>{cfg.branding.logoType}</td></tr>
                <tr><td>{t('admin.config.branding.logoText', '로고 문구')}</td><td>{cfg.branding.logoText}</td></tr>
                <tr><td>{t('admin.config.branding.logoImageUrl', '로고 이미지')}</td><td>{cfg.branding.logoImageUrl ?? '-'}</td></tr>
                <tr><td>{t('admin.config.branding.splashImageUrl', '스플래시 이미지')}</td><td>{cfg.branding.splashImageUrl ?? '-'}</td></tr>
                <tr><td>{t('admin.config.branding.assetsDir', '브랜딩 자산 폴더')}</td><td>{brandingAssetsDisplay}</td></tr>
                <tr><td>{t('admin.config.branding.adsAssetsDir', '광고 자산 폴더')}</td><td>{adsAssetsDisplay}</td></tr>
                <tr><td>{t('admin.config.branding.runtimeAssetsDir', '공통 런타임 자산 루트')}</td><td>{runtimeAssetsDisplay}</td></tr>
              </tbody>
            </table>
          </div>
        </div>

        <div className="card exploreDenseCard exploreSheetCard configPaneCard successCard">
          <h2 className="panelTitle">공개 랜딩</h2>
          <div className="tableWrap">
            <table className="dataTable">
              <tbody>
                <tr><th>key</th><th>value</th></tr>
                <tr><td>동작 방식</td><td>{cfg.publicSite.dynamicLandingEnabled ? 'app-config 연동' : '정적 페이지'}</td></tr>
                <tr><td>랜딩 경로</td><td>{cfg.publicSite.landingRoutes.join(', ')}</td></tr>
                <tr><td>약관 경로</td><td>{cfg.publicSite.privacyRoutes.join(', ')}</td></tr>
                <tr><td>브랜딩 자산 prefix</td><td>{cfg.publicSite.assetsRoutePrefix}</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      ) : null}

      {activePane === 'coupang' ? (
      <div className="sectionGrid twoCol section configTwoColSection">
        <div className={`card exploreDenseCard exploreSheetCard configPaneCard configFormCard ${cfg.coupangPartners.affiliateReady ? 'successCard' : 'warnCard'}`}>
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 8 }}>
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 0 }}>쿠팡 파트너 연동</h2>
            </div>
            <div className="buttonRow configInlineButtonRow">
              <button className="primaryBtn" onClick={() => void saveCoupangOverride(true)} disabled={savingCoupang}>강제 켜기</button>
              <button className="ghostBtn ghostBtnSmall" onClick={() => void saveCoupangOverride(false)} disabled={savingCoupang}>강제 끄기</button>
              <button className="ghostBtn ghostBtnSmall" onClick={() => void saveCoupangOverride(null)} disabled={savingCoupang}>기본값 따르기</button>
            </div>
          </div>
          <div className="metaRow" style={{ marginTop: 0, marginBottom: 10 }}>
            <span className="metaPill">상태 {cfg.coupangPartners.enabled ? '켜짐' : '꺼짐'}</span>
            <span className="metaPill">메모 {savingCoupang ? '저장중' : noteDirty ? '미저장' : '저장됨'}</span>
            <span className="metaPill">제휴 준비 {cfg.coupangPartners.affiliateReady ? '완료' : '미완료'}</span>
          </div>
          <div className="configEditorGrid">
            <div className="configInlineSubcard">
              <div className="configSubcardTitle">연동 상태 요약</div>
              <div className="tableWrap">
                <table className="dataTable">
                  <tbody>
                    <tr><th>key</th><th>value</th></tr>
                    <tr><td>현재 적용 상태</td><td>{cfg.coupangPartners.enabled ? '켜짐' : '꺼짐'}</td></tr>
                    <tr><td>기본값</td><td>{cfg.coupangPartners.envEnabled ? '켜짐' : '꺼짐'}</td></tr>
                    <tr><td>운영자 강제값</td><td>{cfg.coupangPartners.enabledOverride === null ? '없음' : String(cfg.coupangPartners.enabledOverride)}</td></tr>
                    <tr><td>판단 기준</td><td>{cfg.coupangPartners.configSource}</td></tr>
                    <tr><td>access key 준비</td><td>{cfg.coupangPartners.accessKeyConfigured ? '예' : '아니오'}</td></tr>
                    <tr><td>secret key 준비</td><td>{cfg.coupangPartners.secretKeyConfigured ? '예' : '아니오'}</td></tr>
                    <tr><td>제휴 사용 준비</td><td>{cfg.coupangPartners.affiliateReady ? '완료' : '미완료'}</td></tr>
                    <tr><td>최근 갱신</td><td>{cfg.coupangPartners.updatedAt ?? '-'}</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div className="configInlineSubcard">
              <div className="configSubcardTitle">운영 메모</div>
              <label className="field">
                <div className="fieldLabel">운영 메모</div>
                <textarea
                  className="textInput"
                  rows={4}
                  value={coupangNoteDraft}
                  onChange={(e) => setCoupangNoteDraft(e.target.value)}
                  placeholder="예: 쿠팡 답변 전까지 강제 OFF 유지, 키 수령 후 smoke test 예정"
                />
              </label>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">최근 메모 {cfg.coupangPartners.operatorNote ? '저장됨' : '없음'}</span>
              </div>
              {cfg.coupangPartners.operatorNote ? <div className="saveMessage">{cfg.coupangPartners.operatorNote}</div> : null}
              <div className="buttonRow configInlineButtonRow">
                <button className="ghostBtn ghostBtnSmall" onClick={() => setCoupangNoteDraft(cfg.coupangPartners.operatorNote || '')} disabled={savingCoupang}>메모 되돌리기</button>
              </div>
              {runtimeMessage ? <div className="loginError" style={{ marginTop: 0 }}>{runtimeMessage}</div> : null}
            </div>
          </div>

          <div className="configHistoryStack">
            <div className="metaRow" style={{ marginTop: 0 }}>
              <span className="metaPill">변경 기록 {cfg.coupangPartners.recentChanges.length}개</span>
            </div>
            {cfg.coupangPartners.recentChanges.length === 0 ? (
              <div className="metaPill">아직 변경 이력이 없어</div>
            ) : (
              cfg.coupangPartners.recentChanges.map((change, index) => (
                <div
                  key={`${change.changedAt}-${index}`}
                  className="configHistoryCard"
                  style={{
                    border: '1px solid rgba(15,23,42,0.08)',
                    background: '#fff',
                  }}
                >
                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <span className="metaPill">{change.changedAt}</span>
                    <span className="metaPill">기준 {change.configSource}</span>
                    <span className="metaPill">강제값 {change.enabledOverride === null ? '없음' : String(change.enabledOverride)}</span>
                    <span className="metaPill">적용 결과 {change.effectiveEnabled ? '켜짐' : '꺼짐'}</span>
                  </div>
                  <div style={{ color: '#334155' }}>{change.operatorNote || '메모 없음'}</div>
                </div>
              ))
            )}
          </div>
        </div>

        <div className={`card exploreDenseCard exploreSheetCard configPaneCard ${cfg.storageWritable ? 'successCard' : 'warnCard'}`}>
          <h2 className="panelTitle">{t('admin.config.operator.title', '운영 메모')}</h2>
          <ul className="inlineList">
            <li>{startupModeNote}</li>
            <li>{cfg.storageWritable ? '저장 공간은 현재 쓰기 가능 상태야' : '저장 공간 쓰기 상태를 먼저 확인해야 해'}</li>
            <li>{cfg.legacyPathCompatibilityActive ? '이전 경로 호환이 아직 켜져 있어' : '이전 경로 의존성은 정리된 상태야'}</li>
            <li>변경 후에는 정식 runtime refresh 경로를 우선 사용해</li>
          </ul>
        </div>
      </div>
      ) : null}
    </div>
  )
}

export default function ConfigPage() {
  return (
    <Suspense fallback={<div className="exploreCompactPage"><div className="card">불러오는 중...</div></div>}>
      <ConfigPageInner />
    </Suspense>
  )
}
