import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { fetchJsonSafe } from '../../lib/api'
import { mockConfig } from '../../lib/mock'

type ConfigDto = {
  remoteScan: boolean
  adsEnabled: boolean
  storageRoot: string
  apiBase: string
}

export default async function ConfigPage() {
  const res = await fetchJsonSafe<{ ok: boolean; data: ConfigDto }>('/admin/config', {
    ok: true,
    data: mockConfig,
  })
  const cfg = res.data.data

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? 'Fallback data' : 'Live data'}
        title="Config"
        description="운영 플래그, NAS 경로, API 기준점을 확인하는 CTO용 런타임 보드야."
      />

      <div className="kpiGrid">
        <StatCard label="Remote Scan" value={cfg.remoteScan ? 'ON' : 'OFF'} note="앱이 remote scan 파이프라인을 쓰는지 여부" />
        <StatCard label="Ads" value={cfg.adsEnabled ? 'ON' : 'OFF'} note="광고 슬롯 노출 가능 여부" />
        <StatCard label="Storage" value="NAS" note={cfg.storageRoot} />
        <StatCard label="API Base" value="Backend" note={cfg.apiBase} />
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card">
          <h2 className="panelTitle">CTO 체크포인트</h2>
          <ul className="inlineList">
            <li>Backend/DB를 source of truth로 고정</li>
            <li>NAS는 AI 처리/파일/로그 인프라로만 사용</li>
            <li>feedback / failure / event 스키마를 먼저 확정</li>
            <li>모델/프롬프트/파서 버전 추적 추가</li>
          </ul>
        </div>
        <div className="card warnCard">
          <h2 className="panelTitle">현재 리스크</h2>
          <ul className="inlineList">
            <li>DB(Postgres) 미기동이면 admin 데이터가 라이브로 안 뜬다.</li>
            <li>OCR 품질이 낮은 상태라 feedback 루프 없이는 개선 속도가 느리다.</li>
            <li>광고는 설정만 켜도 되는 게 아니라 위치/빈도/톤을 같이 제어해야 한다.</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
