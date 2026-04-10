'use client'

import { useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson } from '../../lib/api'
import { useAdminData } from '../../lib/useAdminData'

type ScanJobRow = {
  id: string
  userId?: string | null
  status?: string | null
  errorCode?: string | null
  errorMessage?: string | null
  createdAt?: string | null
  updatedAt?: string | null
}

type FeedbackRow = {
  id: string
  jobId?: string | null
  userId?: string | null
  accepted?: boolean | null
  createdAt?: string | null
}

type FailureRow = {
  id: string
  jobId?: string | null
  userId?: string | null
  stage?: string | null
  errorCode?: string | null
  errorMessage?: string | null
  createdAt?: string | null
}

type ScanOpsSummary = {
  jobsTotal: number
  queuedJobs: number
  processingJobs: number
  doneJobs: number
  failedJobs: number
  quarantinedJobs?: number
  oldestQueuedAt?: string | null
  workerRunning?: boolean
  feedbackTotal: number
  feedbackAccepted: number
  feedbackCorrected: number
  failureLogs: number
}

type ScanOpsDto = {
  summary?: Partial<ScanOpsSummary>
  jobs?: ScanJobRow[]
  recentFeedback?: FeedbackRow[]
  recentFailures?: FailureRow[]
}

type JobActionResponse = {
  ok: boolean
  data?: { job?: { id: string; status: string } }
}

type JobFilterKey = 'all' | 'failed' | 'quarantined' | 'done'

const fallbackData: ScanOpsDto = {
  summary: {
    jobsTotal: 0,
    queuedJobs: 0,
    processingJobs: 0,
    doneJobs: 0,
    failedJobs: 0,
    quarantinedJobs: 0,
    oldestQueuedAt: null,
    workerRunning: false,
    feedbackTotal: 0,
    feedbackAccepted: 0,
    feedbackCorrected: 0,
    failureLogs: 0,
  },
  jobs: [],
  recentFeedback: [],
  recentFailures: [],
}

function fmt(value?: string | null) {
  if (!value) return '-'
  return value.replace('T', ' ').slice(0, 19)
}

export default function ScanOpsPage() {
  const { t } = useAdminCopy()
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [retryingJobId, setRetryingJobId] = useState<string | null>(null)
  const [quarantiningJobId, setQuarantiningJobId] = useState<string | null>(null)
  const [filter, setFilter] = useState<JobFilterKey>('all')
  const [selectedJobId, setSelectedJobId] = useState<string | null>(null)

  const res = useAdminData<{ ok: boolean; data: ScanOpsDto }>('/admin/scan-jobs', {
    ok: true,
    data: fallbackData,
  })

  const data = res.data?.data ?? fallbackData
  const summary = { ...fallbackData.summary, ...(data.summary ?? {}) } as ScanOpsSummary
  const jobs = data.jobs ?? []
  const feedback = data.recentFeedback ?? []
  const failures = data.recentFailures ?? []

  const filteredJobs = useMemo(() => {
    if (filter === 'all') return jobs
    return jobs.filter((job) => job.status === filter)
  }, [filter, jobs])

  const selectedJob = useMemo(() => {
    return jobs.find((job) => job.id === selectedJobId) ?? filteredJobs[0] ?? jobs[0] ?? null
  }, [filteredJobs, jobs, selectedJobId])

  async function retryJob(jobId: string) {
    setRetryingJobId(jobId)
    setActionMessage(null)
    try {
      await postJson<JobActionResponse>(`/admin/scan-jobs/${jobId}/retry`)
      setActionMessage(t('admin.scanops.action.retryDone', 'job이 다시 queue로 들어갔어'))
      await res.reload()
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : t('admin.scanops.action.retryFailed', 'job retry 실패'))
    } finally {
      setRetryingJobId(null)
    }
  }

  async function quarantineJob(jobId: string) {
    setQuarantiningJobId(jobId)
    setActionMessage(null)
    try {
      await postJson<JobActionResponse>(`/admin/scan-jobs/${jobId}/quarantine`)
      setActionMessage(t('admin.scanops.action.quarantineDone', 'job을 quarantine으로 이동했어'))
      if (selectedJobId === jobId) setSelectedJobId(null)
      await res.reload()
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : t('admin.scanops.action.quarantineFailed', 'job quarantine 실패'))
    } finally {
      setQuarantiningJobId(null)
    }
  }

  const filterButtons: Array<[JobFilterKey, string]> = [
    ['all', `${t('admin.scanops.filter.all', 'All')} (${jobs.length})`],
    ['failed', `${t('admin.scanops.filter.failed', 'Failed')} (${summary.failedJobs ?? 0})`],
    ['quarantined', `${t('admin.scanops.filter.quarantined', 'Quarantined')} (${summary.quarantinedJobs ?? 0})`],
    ['done', `${t('admin.scanops.filter.done', 'Done')} (${summary.doneJobs ?? 0})`],
  ]

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.scanops.title', 'Scan Ops')}
        description={t('admin.scanops.desc', '작업 상태 + feedback/failure 루프')}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {actionMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{actionMessage}</div> : null}

      <div className="kpiGrid">
        <StatCard label={t('admin.scanops.kpi.jobs', 'Jobs')} value={String(summary.jobsTotal ?? 0)} note={`${t('admin.scanops.kpi.jobsNoteQueued', 'queued')} ${summary.queuedJobs ?? 0} · ${t('admin.scanops.kpi.jobsNoteProcessing', 'processing')} ${summary.processingJobs ?? 0}`} />
        <StatCard label={t('admin.scanops.kpi.doneFailed', 'Done / Failed')} value={`${summary.doneJobs ?? 0} / ${summary.failedJobs ?? 0}`} note={summary.oldestQueuedAt ? `${t('admin.scanops.kpi.oldestQueued', 'oldest queued')} ${fmt(summary.oldestQueuedAt)}` : t('admin.scanops.kpi.queueClear', 'queue clear')} />
        <StatCard label={t('admin.scanops.kpi.worker', 'Worker')} value={summary.workerRunning ? t('admin.scanops.kpi.workerRunning', 'RUNNING') : t('admin.scanops.kpi.workerStopped', 'STOPPED')} note={t('admin.scanops.kpi.workerNote', 'login-session daemon')} />
        <StatCard label={t('admin.scanops.kpi.quarantine', 'Quarantined')} value={String(summary.quarantinedJobs ?? 0)} note={t('admin.scanops.kpi.quarantineNote', 'worker 제외 운영 보관')} />
        <StatCard label={t('admin.scanops.kpi.feedback', 'Feedback')} value={String(summary.feedbackTotal ?? 0)} note={`${t('admin.scanops.kpi.feedbackAccepted', 'accepted')} ${summary.feedbackAccepted ?? 0} · ${t('admin.scanops.kpi.feedbackCorrected', 'corrected')} ${summary.feedbackCorrected ?? 0}`} />
        <StatCard label={t('admin.scanops.kpi.failures', 'Failures')} value={String(summary.failureLogs ?? 0)} note={t('admin.scanops.kpi.failuresNote', 'submit / polling / result / worker')} />
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card">
          <div className="buttonRow" style={{ marginBottom: 16, flexWrap: 'wrap' }}>
            {filterButtons.map(([key, label]) => (
              <button key={key} className={filter === key ? 'primaryBtn pageActionBtn' : 'ghostBtn pageActionBtn'} type="button" onClick={() => setFilter(key)}>
                {label}
              </button>
            ))}
          </div>

          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.scanops.jobs.title', 'Recent jobs')}</h2>
              <p className="pageDesc">{t('admin.scanops.jobs.desc', '현재 queue 적체와 완료/실패 상태를 본다')}</p>
            </div>
          </div>
          {filteredJobs.length === 0 ? (
            <div className="emptyState">{t('admin.scanops.jobs.emptyFiltered', '조건에 맞는 scan job이 없어')}</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>{t('admin.scanops.jobs.table.status', 'Status')}</th>
                    <th>{t('admin.scanops.jobs.table.job', 'Job')}</th>
                    <th>{t('admin.scanops.jobs.table.user', 'User')}</th>
                    <th>{t('admin.scanops.jobs.table.error', 'Error')}</th>
                    <th>{t('admin.scanops.jobs.table.created', 'Created')}</th>
                    <th>{t('admin.scanops.jobs.table.action', 'Action')}</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredJobs.map((row, index) => (
                    <tr key={row.id ?? index} onClick={() => setSelectedJobId(row.id)} style={{ cursor: 'pointer', background: selectedJob?.id === row.id ? 'rgba(102, 126, 234, 0.08)' : undefined }}>
                      <td>{row.status ?? '-'}</td>
                      <td>{row.id ?? '-'}</td>
                      <td>{row.userId ?? '-'}</td>
                      <td>{row.errorCode ?? '-'}</td>
                      <td>{fmt(row.createdAt)}</td>
                      <td>
                        {row.status === 'failed' ? (
                          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                            <button className="ghostBtn ghostBtnSmall" type="button" disabled={retryingJobId === row.id} onClick={(event) => { event.stopPropagation(); void retryJob(row.id) }}>
                              {retryingJobId === row.id ? t('admin.scanops.action.retrying', 'retrying...') : t('admin.scanops.action.retry', 'retry')}
                            </button>
                            <button className="ghostBtn ghostBtnSmall" type="button" disabled={quarantiningJobId === row.id} onClick={(event) => { event.stopPropagation(); void quarantineJob(row.id) }}>
                              {quarantiningJobId === row.id ? t('admin.scanops.action.moving', 'moving...') : t('admin.scanops.action.quarantine', 'quarantine')}
                            </button>
                          </div>
                        ) : (
                          '-'
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.scanops.jobs.detailTitle', 'Selected job detail')}</h2>
              <p className="pageDesc">{t('admin.scanops.jobs.detailDesc', '실패 사유와 상태 갱신 시각을 바로 본다')}</p>
            </div>
          </div>
          {selectedJob ? (
            <div className="sectionGrid" style={{ gap: 12 }}>
              <div className="field"><div className="fieldLabel">{t('admin.scanops.jobs.detail.jobId', 'Job ID')}</div><div>{selectedJob.id}</div></div>
              <div className="field"><div className="fieldLabel">{t('admin.scanops.jobs.detail.status', 'Status')}</div><div>{selectedJob.status ?? '-'}</div></div>
              <div className="field"><div className="fieldLabel">{t('admin.scanops.jobs.detail.errorCode', 'Error code')}</div><div>{selectedJob.errorCode ?? '-'}</div></div>
              <div className="field"><div className="fieldLabel">{t('admin.scanops.jobs.detail.errorMessage', 'Error message')}</div><div>{selectedJob.errorMessage ?? '-'}</div></div>
              <div className="field"><div className="fieldLabel">{t('admin.scanops.jobs.detail.created', 'Created')}</div><div>{fmt(selectedJob.createdAt)}</div></div>
              <div className="field"><div className="fieldLabel">{t('admin.scanops.jobs.detail.updated', 'Updated')}</div><div>{fmt(selectedJob.updatedAt)}</div></div>
              <div className="field"><div className="fieldLabel">{t('admin.scanops.jobs.detail.user', 'User')}</div><div>{selectedJob.userId ?? '-'}</div></div>
            </div>
          ) : (
            <div className="emptyState">{t('admin.scanops.jobs.detailEmpty', '선택된 job이 없어')}</div>
          )}
        </div>

        <div className="card">
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.scanops.feedback.title', 'Recent feedback')}</h2>
              <p className="pageDesc">{t('admin.scanops.feedback.desc', '사용자가 그대로 수락했는지, 수정 후 담았는지')}</p>
            </div>
          </div>
          {feedback.length === 0 ? (
            <div className="emptyState">{t('admin.scanops.feedback.empty', '아직 feedback 로그가 없어')}</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>{t('admin.scanops.feedback.table.action', 'Action')}</th>
                    <th>{t('admin.scanops.feedback.table.job', 'Job')}</th>
                    <th>{t('admin.scanops.feedback.table.user', 'User')}</th>
                    <th>{t('admin.scanops.feedback.table.time', 'Time')}</th>
                  </tr>
                </thead>
                <tbody>
                  {feedback.map((row, index) => (
                    <tr key={row.id ?? index}>
                      <td>{row.accepted ? t('admin.scanops.feedback.accepted', 'accepted') : t('admin.scanops.feedback.corrected', 'corrected')}</td>
                      <td>{row.jobId ?? '-'}</td>
                      <td>{row.userId ?? '-'}</td>
                      <td>{fmt(row.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="card" style={{ gridColumn: '1 / -1' }}>
          <div className="sectionHeader">
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.scanops.failures.title', 'Recent failures')}</h2>
              <p className="pageDesc">{t('admin.scanops.failures.desc', 'submit / processing / polling / result 단계 실패를 본다')}</p>
            </div>
          </div>
          {failures.length === 0 ? (
            <div className="emptyState">{t('admin.scanops.failures.empty', '아직 failure 로그가 없어')}</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th>{t('admin.scanops.failures.table.stage', 'Stage')}</th>
                    <th>{t('admin.scanops.failures.table.code', 'Code')}</th>
                    <th>{t('admin.scanops.failures.table.message', 'Message')}</th>
                    <th>{t('admin.scanops.failures.table.job', 'Job')}</th>
                    <th>{t('admin.scanops.failures.table.time', 'Time')}</th>
                  </tr>
                </thead>
                <tbody>
                  {failures.map((row, index) => (
                    <tr key={row.id ?? index}>
                      <td>{row.stage ?? '-'}</td>
                      <td>{row.errorCode ?? '-'}</td>
                      <td>{row.errorMessage ?? '-'}</td>
                      <td>{row.jobId ?? '-'}</td>
                      <td>{fmt(row.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
