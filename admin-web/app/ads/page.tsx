import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { fetchJsonSafe } from '../../lib/api'
import { formatDate, statusTone } from '../../lib/format'
import { mockSlots } from '../../lib/mock'

type SlotRow = {
  id: string
  slotKey: string
  placementType: string
  status: string
  createdAt: string | null
  updatedAt: string | null
}

const slotNotes: Record<string, string> = {
  save_complete_sheet_1: '저장 완료 직후 요약 아래 · 88px · benefit native',
  saved_inline_1: 'Saved 리스트 첫 카드 뒤 · 104px · 혜택 추천',
  saved_inline_2: 'Saved 리스트 세 번째 카드 뒤 · 104px · 낮은 밀도 유지',
  my_perks_inline_1: 'My 화면 계정 카드 아래 · 96px · soft promo',
}

export default async function AdsPage() {
  const res = await fetchJsonSafe<{ ok: boolean; data: { slots: SlotRow[] } }>('/admin/ads/slots', {
    ok: true,
    data: { slots: mockSlots },
  })
  const slots = res.data.data.slots

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? 'Fallback data' : 'Live data'}
        title="Ads"
        description="CFO와 CMO가 함께 보는 슬롯 운영 보드야. 광고는 핵심 작업 흐름을 방해하지 않는 수준에서만 배치해야 해."
      />

      <div className="kpiGrid">
        <StatCard label="Policy" value="Light" note="초기 광고 밀도는 낮게 유지하고 저장/히스토리/계정 영역 중심으로만 간다" />
        <StatCard label="Blocked zones" value="Scan" note="스캔/보정/현재 카트 편집 중엔 광고 금지" />
        <StatCard label="Slot count" value={`${slots.length}`} note="지금 활성화한 MVP 슬롯 수" />
        <StatCard label="Tone" value="Native" note="거친 배너보다 자연스러운 혜택/추천 카드 형태가 우선" />
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card successCard">
          <h2 className="panelTitle">허용 영역</h2>
          <ul className="inlineList">
            <li>저장 완료 바텀시트</li>
            <li>Saved 리스트 카드 사이</li>
            <li>My 화면 계정 가치 아래</li>
          </ul>
        </div>
        <div className="card warnCard">
          <h2 className="panelTitle">금지 영역</h2>
          <ul className="inlineList">
            <li>스캔 직전/직후 핵심 검토 구간</li>
            <li>OCR 결과 수정 화면</li>
            <li>현재 카트 편집 화면</li>
          </ul>
        </div>
      </div>

      <div className="section">
        <table className="table">
          <thead>
            <tr>
              <th>Slot Key</th>
              <th>Placement</th>
              <th>Status</th>
              <th>Spec</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody>
            {slots.map((slot) => (
              <tr key={slot.id}>
                <td style={{ fontWeight: 700 }}>{slot.slotKey}</td>
                <td>{slot.placementType}</td>
                <td><span className={`badge ${statusTone(slot.status)}`}>{slot.status}</span></td>
                <td>{slotNotes[slot.slotKey] ?? '운영 메모 추가 필요'}</td>
                <td>{formatDate(slot.updatedAt ?? slot.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
