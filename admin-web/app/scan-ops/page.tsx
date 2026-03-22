import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { fetchJsonSafe } from '../../lib/api'
import { formatDate, statusTone } from '../../lib/format'
import { mockScanJobs } from '../../lib/mock'

type JobRow = {
  id: string
  userId: string | null
  status: string
  errorCode: string | null
  createdAt: string | null
  updatedAt: string | null
}

export default async function ScanOpsPage() {
  const res = await fetchJsonSafe<{ ok: boolean; data: { jobs: JobRow[] } }>('/admin/scan-jobs', {
    ok: true,
    data: { jobs: mockScanJobs },
  })
  const jobs = res.data.data.jobs
  const failed = jobs.filter((job) => job.status === 'failed').length
  const done = jobs.filter((job) => job.status === 'done').length
  const active = jobs.filter((job) => ['queued', 'processing', 'uploading'].includes(job.status)).length

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? 'Fallback data' : 'Live data'}
        title="Scan Ops"
        description="CTO와 운영자가 OCR 품질, 워커 상태, 실패 로그, 피드백 루프를 같이 보는 운영 화면이야."
      />

      <div className="kpiGrid">
        <StatCard label="Done" value={`${done}`} note="정상 처리된 스캔 작업 수" />
        <StatCard label="Active" value={`${active}`} note="대기/처리 중인 워크로드" />
        <StatCard label="Failed" value={`${failed}`} note="실패 로그와 피드백 분류가 필요한 작업 수" />
        <StatCard label="Priority" value="High" note="현재 트랙은 OCR 품질 측정과 feedback loop 구축이 우선이야" />
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card">
          <h2 className="panelTitle">운영 원칙</h2>
          <ul className="inlineList">
            <li>앱은 job 상태를 조회하고 수정 결과를 제출한다.</li>
            <li>Backend/DB가 source of truth고, NAS는 파일/로그/AI 처리 인프라다.</li>
            <li>실패 케이스는 <strong>failed + logs + feedback</strong> 세 축으로 남겨야 한다.</li>
            <li>모델 버전/프롬프트 버전/파서 버전은 결과와 함께 추적해야 한다.</li>
          </ul>
        </div>
        <div className="card successCard">
          <h2 className="panelTitle">즉시 필요한 로그</h2>
          <ul className="inlineList">
            <li>low confidence 비율</li>
            <li>사용자 수정률</li>
            <li>재촬영률</li>
            <li>가격/상품명 분리 실패 비율</li>
            <li>failure stage 분포</li>
          </ul>
        </div>
      </div>

      <div className="section">
        <table className="table">
          <thead>
            <tr>
              <th>Job ID</th>
              <th>User</th>
              <th>Status</th>
              <th>Error</th>
              <th>Created</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody>
            {jobs.map((job) => (
              <tr key={job.id}>
                <td style={{ maxWidth: 260, overflowWrap: 'anywhere', fontWeight: 700 }}>{job.id}</td>
                <td>{job.userId ?? '-'}</td>
                <td><span className={`badge ${statusTone(job.status)}`}>{job.status}</span></td>
                <td>{job.errorCode ?? '-'}</td>
                <td>{formatDate(job.createdAt)}</td>
                <td>{formatDate(job.updatedAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
