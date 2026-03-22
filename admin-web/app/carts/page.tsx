import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'

export default function CartsPage() {
  return (
    <div>
      <PageHeader
        badge="Product loop"
        title="Carts"
        description="CDO와 CMO가 함께 보는 저장/재방문 중심 보드야. WIMC가 단순 OCR 앱이 아니라 반복 사용되는 카트 제품인지 확인하는 화면이야."
      />

      <div className="kpiGrid">
        <StatCard label="Current focus" value="Save" note="지금은 스캔 정확도보다 저장까지 이어지는 루프를 먼저 키워야 해" />
        <StatCard label="Retention lever" value="History" note="Saved/History 경험이 재방문 가치의 핵심이야" />
        <StatCard label="User promise" value="Reuse" note="다음 쇼핑 전에 다시 꺼내보는 경험이 제품 정체성에 가깝다" />
        <StatCard label="Risk" value="Demo" note="저장 이후 맥락이 약하면 제품이 아니라 기술 데모처럼 느껴질 수 있어" />
      </div>

      <div className="section sectionGrid threeCol">
        <div className="card">
          <h2 className="panelTitle">핵심 퍼널</h2>
          <ul className="inlineList">
            <li>Scan started</li>
            <li>Result reviewed</li>
            <li>Added to current cart</li>
            <li>Cart saved</li>
            <li>Saved cart reopened</li>
          </ul>
        </div>
        <div className="card">
          <h2 className="panelTitle">지금 봐야 할 질문</h2>
          <ul className="inlineList">
            <li>사용자가 저장의 의미를 이해하나?</li>
            <li>저장 후 다시 돌아올 이유가 있나?</li>
            <li>현재 카트와 저장 카트의 역할이 분리되나?</li>
          </ul>
        </div>
        <div className="card warnCard">
          <h2 className="panelTitle">리스크</h2>
          <ul className="inlineList">
            <li>히스토리가 숨어 있으면 retention이 죽어.</li>
            <li>저장 직후 다음 액션이 약하면 기억에 안 남아.</li>
            <li>광고가 이 구간을 침범하면 신뢰가 깨져.</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
