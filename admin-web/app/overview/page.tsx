import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { fetchJsonSafe } from '../../lib/api'
import { formatNumber, formatPercent } from '../../lib/format'
import { mockSummary } from '../../lib/mock'

export default async function OverviewPage() {
  const res = await fetchJsonSafe<{ ok: boolean; data: typeof mockSummary }>('/admin/dashboard/summary', {
    ok: true,
    data: mockSummary,
  })
  const data = res.data.data

  const summary = [
    ['DAU', formatNumber(data.dau), '오늘 실제로 제품을 다시 연 사용자 수'],
    ['WAU', formatNumber(data.wau), '최근 7일 유지되고 있는 사용자 풀'],
    ['MAU', formatNumber(data.mau), '30일 기준 제품 체력'],
    ['Total Scans', formatNumber(data.totalScans), 'OCR/AI 파이프라인 전체 볼륨'],
    ['Scan Success', formatPercent(data.scanSuccessRate), 'CTO가 가장 먼저 끌어올려야 할 핵심 품질 지표'],
    ['Cart Save', formatPercent(data.cartSaveRate), 'CDO/CMO가 함께 봐야 할 핵심 전환 지표'],
    ['Guest→Member', formatPercent(data.guestToMemberConversion), '가치 체감 후 계정 전환율'],
    ['Ad CTR', formatPercent(data.adCtr), '광고 실험은 retention 보조 수준으로만 본다'],
  ] as const

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? 'Fallback data' : 'Live data'}
        title="Overview"
        description="CEO가 오늘 바로 봐야 하는 제품 건강도, 스캔 품질, 전환, 수익화 상태를 한 화면에 정리한 보드야."
      />

      <div className="kpiGrid">
        {summary.map(([label, value, note]) => (
          <StatCard key={label} label={label} value={value} note={note} />
        ))}
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card">
          <h2 className="panelTitle">오늘의 경영 해석</h2>
          <ul className="inlineList">
            <li>WIMC의 핵심은 OCR 정확도 자체보다 <strong>스캔 → 보정 → 저장 → 재방문</strong> 루프야.</li>
            <li>Scan Success가 아직 완벽하지 않더라도 Cart Save와 Saved revisit를 올리면 제품 가치는 살아 있어.</li>
            <li>광고는 핵심 루프가 아니라 저장/히스토리 기반 부가 수익 레이어로 봐야 해.</li>
            <li>이번 주 우선순위는 OCR 품질 측정, Saved 경험 강화, 계정 가치 노출 정리야.</li>
          </ul>
          <div className="metaRow">
            <div className="metaPill">CTO: OCR quality</div>
            <div className="metaPill">CDO: save/history UX</div>
            <div className="metaPill">CMO: value framing</div>
            <div className="metaPill">CFO: controlled ad density</div>
          </div>
        </div>

        <div className="card warnCard">
          <h2 className="panelTitle">이번 주 경고 신호</h2>
          <ul className="inlineList">
            <li>OCR 품질이 낮은 상태에서 결과 신뢰 설계가 약하면 이탈이 커질 수 있어.</li>
            <li>Saved 진입점이 약하면 재방문 가치가 살아나지 않아.</li>
            <li>광고가 너무 앞에 나오면 제품을 방해하는 앱으로 느껴질 위험이 커.</li>
            <li>Backend/DB를 state source of truth로 빨리 고정해야 NAS/AI 파이프라인이 안정돼.</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
