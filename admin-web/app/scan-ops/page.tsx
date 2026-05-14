'use client'

import type { KeyboardEvent } from 'react'
import { useMemo, useState } from 'react'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { postJson } from '../../lib/api'
import { CATEGORY_CLEAR_VALUE, LARGE_CATEGORY_OPTIONS } from '../../lib/categoryOptions'
import { mockScanJobs } from '../../lib/mock'
import { useAdminData } from '../../lib/useAdminData'

type ScanJobResult = {
  name?: string | null
  price?: number | null
  sku?: string | null
  confidence?: number | null
  source?: string | null
  rawText?: string | null
}

type JobCategoryMeta = {
  naverLargeCategory?: string | null
  naverCategoryPath?: string | null
  categorySource?: string | null
}

type JobDeviceMeta = {
  make?: string | null
  model?: string | null
}

type JobFailureSummary = {
  id: string
  stage?: string | null
  errorCode?: string | null
  errorMessage?: string | null
  createdAt?: string | null
  details?: Record<string, unknown> | null
}

type JobFeedbackSummary = {
  id: string
  accepted?: boolean | null
  createdAt?: string | null
  original?: Record<string, unknown> | null
  corrected?: Record<string, unknown> | null
}

type ScanJobRow = {
  id: string
  userId?: string | null
  status?: string | null
  errorCode?: string | null
  errorMessage?: string | null
  createdAt?: string | null
  updatedAt?: string | null
  startedAt?: string | null
  finishedAt?: string | null
  imageAvailable?: boolean | null
  imagePathLabel?: string | null
  customerMessage?: string | null
  deviceMeta?: JobDeviceMeta | null
  result?: ScanJobResult | null
  reviewedResult?: ScanJobResult | null
  categoryMeta?: JobCategoryMeta | null
  resultPayload?: Record<string, unknown> | null
  latestFailure?: JobFailureSummary | null
  latestFeedback?: JobFeedbackSummary | null
  failureHistory?: JobFailureSummary[] | null
  feedbackHistory?: JobFeedbackSummary[] | null
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

type ScanInsightCountRow = {
  label: string
  count: number
  category?: string | null
}

type ScanOpsInsights = {
  sampleSize?: number
  topProducts?: ScanInsightCountRow[]
  topCategories?: ScanInsightCountRow[]
  hourlyActivity?: ScanInsightCountRow[]
  weekdayActivity?: ScanInsightCountRow[]
  dailyActivity?: ScanInsightCountRow[]
}

type ScanOpsDto = {
  summary?: Partial<ScanOpsSummary>
  jobs?: ScanJobRow[]
  insights?: ScanOpsInsights
}

type JobActionResponse = {
  ok: boolean
  data?: { job?: { id: string; status: string } }
}

type CategoryUpdateResponse = {
  ok: boolean
  data?: { updated?: number; category?: string | null }
  error?: { message?: string }
}

type JobFilterKey = 'all' | 'failed' | 'quarantined' | 'done'

const fallbackData: ScanOpsDto = mockScanJobs

function fmt(value?: string | null) {
  if (!value) return '-'
  return value.replace('T', ' ').slice(0, 19)
}

function fmtPrice(value?: number | null) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) return '-'
  return `₩${value.toLocaleString('ko-KR')}`
}

function formatJson(value: unknown) {
  try {
    return JSON.stringify(value, null, 2)
  } catch {
    return String(value)
  }
}

function feedbackLabel(feedback?: JobFeedbackSummary | null) {
  if (!feedback) return '-'
  return feedback.accepted ? 'accepted' : 'corrected'
}

function categoryLabel(categoryMeta?: JobCategoryMeta | null) {
  return categoryMeta?.naverLargeCategory?.trim() || '-'
}

function deviceLabel(deviceMeta?: JobDeviceMeta | null) {
  const make = deviceMeta?.make?.trim()
  const model = deviceMeta?.model?.trim()
  return [make, model].filter(Boolean).join(' ') || '-'
}

function jobImageSrc(jobId: string) {
  return `/api/cartly-admin/admin/scan-jobs/${jobId}/image`
}

export default function ScanOpsPage() {
  const { t } = useAdminCopy()
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [retryingJobId, setRetryingJobId] = useState<string | null>(null)
  const [quarantiningJobId, setQuarantiningJobId] = useState<string | null>(null)
  const [filter, setFilter] = useState<JobFilterKey>('all')
  const [query, setQuery] = useState('')
  const [selectedJobId, setSelectedJobId] = useState<string | null>(null)
  const [downloadingWorkbook, setDownloadingWorkbook] = useState(false)
  const [selectedJobIds, setSelectedJobIds] = useState<string[]>([])
  const [bulkCategory, setBulkCategory] = useState('')
  const [rowCategoryDrafts, setRowCategoryDrafts] = useState<Record<string, string>>({})
  const [savingCategories, setSavingCategories] = useState(false)

  const res = useAdminData<{ ok: boolean; data: ScanOpsDto }>('/admin/scan-jobs?view=v5', {
    ok: true,
    data: fallbackData,
  })

  const data = res.data?.data ?? fallbackData
  const summary = { ...fallbackData.summary, ...(data.summary ?? {}) } as ScanOpsSummary
  const jobs = data.jobs ?? []
  const insights = data.insights ?? {}

  const filteredJobs = useMemo(() => {
    const trimmed = query.trim().toLowerCase()
    return jobs.filter((job) => {
      const matchesFilter = filter === 'all' ? true : job.status === filter
      const searchHaystacks = [
        job.id,
        job.userId,
        job.status,
        job.errorCode,
        job.errorMessage,
        job.customerMessage,
        job.result?.name,
        job.result?.rawText,
        job.latestFailure?.stage,
        job.latestFailure?.errorCode,
        job.latestFailure?.errorMessage,
      ]
      const matchesQuery = !trimmed || searchHaystacks.filter(Boolean).some((value) => String(value).toLowerCase().includes(trimmed))
      return matchesFilter && matchesQuery
    })
  }, [filter, jobs, query])

  const editableJobIds = useMemo(() => {
    return filteredJobs.filter((job) => (job.reviewedResult ?? job.result)?.name).map((job) => job.id)
  }, [filteredJobs])

  const selectedJob = useMemo(() => {
    return jobs.find((job) => job.id === selectedJobId) ?? null
  }, [jobs, selectedJobId])
  const selectedPrimaryResult = selectedJob?.reviewedResult ?? selectedJob?.result ?? null
  const selectedFailureHistory = selectedJob?.failureHistory ?? []
  const selectedFeedbackHistory = selectedJob?.feedbackHistory ?? []

  function getCategoryDraft(job: ScanJobRow) {
    return rowCategoryDrafts[job.id] ?? (job.categoryMeta?.categorySource === 'admin-override-v1' ? job.categoryMeta?.naverLargeCategory ?? CATEGORY_CLEAR_VALUE : CATEGORY_CLEAR_VALUE)
  }

  const selectedCategoryDraft = selectedJob ? getCategoryDraft(selectedJob) : CATEGORY_CLEAR_VALUE

  async function retryJob(jobId: string) {
    if (res.usingFallback) {
      setActionMessage(t('admin.scanops.action.fallbackBlocked', 'fallback/mock 상태에서는 retry 액션을 막아둘게'))
      return
    }
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
    if (res.usingFallback) {
      setActionMessage(t('admin.scanops.action.fallbackBlocked', 'fallback/mock 상태에서는 quarantine 액션을 막아둘게'))
      return
    }
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

  function toggleJobSelection(jobId: string) {
    setSelectedJobIds((current) => current.includes(jobId) ? current.filter((id) => id !== jobId) : [...current, jobId])
  }

  function openJobDetail(jobId: string) {
    setSelectedJobId(jobId)
  }

  function onJobRowKeyDown(event: KeyboardEvent<HTMLTableRowElement>, jobId: string) {
    if (event.key !== 'Enter' && event.key !== ' ') return
    event.preventDefault()
    openJobDetail(jobId)
  }

  async function saveJobCategories(jobIds: string[], categoryDraft: string) {
    if (res.usingFallback) {
      setActionMessage('fallback/mock 상태에서는 카테고리 수정이 안 돼')
      return
    }
    if (!jobIds.length) {
      setActionMessage('먼저 수정할 scan job을 선택해줘')
      return
    }
    if (!categoryDraft) {
      setActionMessage('적용할 카테고리를 먼저 골라줘')
      return
    }
    setSavingCategories(true)
    setActionMessage(null)
    try {
      const nextCategory = categoryDraft === CATEGORY_CLEAR_VALUE ? null : categoryDraft
      const result = await postJson<CategoryUpdateResponse>('/admin/scan-jobs/category', {
        jobIds,
        category: nextCategory,
      })
      if (!result.ok) {
        throw new Error(result.error?.message || 'scan job 카테고리 저장 실패')
      }
      setActionMessage(nextCategory ? `${jobIds.length}건 scan 카테고리를 ${nextCategory}로 바꿨어` : `${jobIds.length}건 scan 카테고리를 자동 추론으로 되돌렸어`)
      setSelectedJobIds([])
      setBulkCategory('')
      setRowCategoryDrafts({})
      await res.reload()
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : 'scan job 카테고리 저장 실패')
    } finally {
      setSavingCategories(false)
    }
  }

  const filterButtons: Array<[JobFilterKey, string]> = [
    ['all', `${t('admin.scanops.filter.all', 'All')} (${jobs.length})`],
    ['failed', `${t('admin.scanops.filter.failed', 'Failed')} (${summary.failedJobs ?? 0})`],
    ['quarantined', `${t('admin.scanops.filter.quarantined', 'Quarantined')} (${summary.quarantinedJobs ?? 0})`],
    ['done', `${t('admin.scanops.filter.done', 'Done')} (${summary.doneJobs ?? 0})`],
  ]

  async function downloadWorkbook() {
    setDownloadingWorkbook(true)
    setActionMessage(null)
    try {
      const XLSX = await import('xlsx')
      const workbook = XLSX.utils.book_new()

      const summaryRows = [
        {
          jobsTotal: summary.jobsTotal ?? 0,
          queuedJobs: summary.queuedJobs ?? 0,
          processingJobs: summary.processingJobs ?? 0,
          doneJobs: summary.doneJobs ?? 0,
          failedJobs: summary.failedJobs ?? 0,
          quarantinedJobs: summary.quarantinedJobs ?? 0,
          oldestQueuedAt: fmt(summary.oldestQueuedAt),
          workerRunning: summary.workerRunning ? 'RUNNING' : 'STOPPED',
          feedbackTotal: summary.feedbackTotal ?? 0,
          feedbackAccepted: summary.feedbackAccepted ?? 0,
          feedbackCorrected: summary.feedbackCorrected ?? 0,
          failureLogs: summary.failureLogs ?? 0,
        },
      ]

      const jobRows = jobs.map((row) => {
        const primaryResult = row.reviewedResult ?? row.result
        return {
          id: row.id,
          status: row.status ?? '-',
          userId: row.userId ?? '-',
          device: deviceLabel(row.deviceMeta),
          imageAvailable: row.imageAvailable ? 'Y' : 'N',
          imagePathLabel: row.imagePathLabel ?? '-',
          createdAt: fmt(row.createdAt),
          updatedAt: fmt(row.updatedAt),
          startedAt: fmt(row.startedAt),
          finishedAt: fmt(row.finishedAt),
          customerMessage: row.customerMessage ?? '-',
          resultName: primaryResult?.name ?? '-',
          resultPrice: typeof primaryResult?.price === 'number' ? primaryResult.price : '',
          resultSku: primaryResult?.sku ?? '-',
          resultConfidence: typeof primaryResult?.confidence === 'number' ? primaryResult.confidence : '',
          resultSource: primaryResult?.source ?? '-',
          resultRawText: primaryResult?.rawText ?? '-',
          category: row.categoryMeta?.naverLargeCategory ?? '-',
          categoryPath: row.categoryMeta?.naverCategoryPath ?? '-',
          categorySource: row.categoryMeta?.categorySource ?? '-',
          latestFeedback: feedbackLabel(row.latestFeedback),
          latestFailureStage: row.latestFailure?.stage ?? '-',
          latestFailureCode: row.latestFailure?.errorCode ?? row.errorCode ?? '-',
          latestFailureMessage: row.latestFailure?.errorMessage ?? row.errorMessage ?? '-',
          reviewedResultJson: row.reviewedResult ? formatJson(row.reviewedResult) : '',
          rawResultJson: row.result ? formatJson(row.result) : '',
          resultPayloadJson: row.resultPayload ? formatJson(row.resultPayload) : '',
          failureHistoryJson: row.failureHistory?.length ? formatJson(row.failureHistory) : '',
          feedbackHistoryJson: row.feedbackHistory?.length ? formatJson(row.feedbackHistory) : '',
        }
      })

      XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(summaryRows), 'Summary')
      XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(insights.topProducts ?? []), 'Top Products')
      XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(insights.topCategories ?? []), 'Top Categories')
      XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(insights.hourlyActivity ?? []), 'Hourly')
      XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(insights.weekdayActivity ?? []), 'Weekday')
      XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(insights.dailyActivity ?? []), 'Daily')
      XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(jobRows), 'Jobs')
      XLSX.writeFile(workbook, 'cartly-scan-ops.xlsx')
      setActionMessage('scan ops 데이터를 엑셀로 내려받았어')
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : '엑셀 다운로드 실패')
    } finally {
      setDownloadingWorkbook(false)
    }
  }

  return (
    <div className="exploreCompactPage">
      <PageHeader
        badge={res.usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : res.loading ? t('admin.common.badge.loading', 'Loading...') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.scanops.title', 'Scan Ops')}
        description={t('admin.scanops.desc', 'queue, failure, feedback')}
        onRefresh={() => void res.reload()}
        refreshing={res.loading}
        inlineRefresh
        actions={(
          <button className="ghostBtn pageActionBtn" type="button" onClick={() => void downloadWorkbook()} disabled={downloadingWorkbook}>
            {downloadingWorkbook ? '엑셀 준비중...' : 'Excel'}
          </button>
        )}
      />

      {res.error ? <div className="loginError" style={{ marginBottom: 16 }}>{res.error}</div> : null}
      {actionMessage ? <div className="saveMessage" style={{ marginBottom: 16 }}>{actionMessage}</div> : null}
      {res.usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.scanops.warning.fallbackTitle', 'Live scan ops unavailable.')}</strong>{' '}
          {t('admin.scanops.warning.fallbackBody', '지금 화면은 fallback/mock data일 수 있어서 retry, quarantine 같은 운영 액션은 잠깐 막아둘게.')}
        </div>
      ) : null}

      <div className="exploreSummaryGrid section" style={{ marginTop: 12 }}>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Jobs</div>
          <div className="exploreSummaryValue">{summary.jobsTotal ?? 0}</div>
          <div className="exploreSummaryNote">queued {summary.queuedJobs ?? 0} · processing {summary.processingJobs ?? 0}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Done / Failed</div>
          <div className="exploreSummaryValue">{summary.doneJobs ?? 0} / {summary.failedJobs ?? 0}</div>
          <div className="exploreSummaryNote">{summary.oldestQueuedAt ? `oldest ${fmt(summary.oldestQueuedAt)}` : 'queue clear'}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Worker</div>
          <div className="exploreSummaryValue">{summary.workerRunning ? 'RUNNING' : 'STOPPED'}</div>
          <div className="exploreSummaryNote">login-session daemon</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Feedback</div>
          <div className="exploreSummaryValue">{summary.feedbackTotal ?? 0}</div>
          <div className="exploreSummaryNote">accepted {summary.feedbackAccepted ?? 0} · corrected {summary.feedbackCorrected ?? 0}</div>
        </div>
        <div className="exploreSummaryCell">
          <div className="exploreSummaryLabel">Failures</div>
          <div className="exploreSummaryValue">{summary.failureLogs ?? 0}</div>
          <div className="exploreSummaryNote">quarantine {summary.quarantinedJobs ?? 0}</div>
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard" style={{ gridColumn: '1 / -1' }}>
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Insights</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">sample {insights.sampleSize ?? jobs.length}</div>
              <div className="metaPill">GPS 없음</div>
            </div>
          </div>
          <div className="scanInsightsGrid">
            <section className="scanInsightsPane">
              <div className="scanInsightsPaneTitle">Top products</div>
              <div className="scanInsightsList">
                {(insights.topProducts ?? []).slice(0, 8).map((row) => (
                  <div className="scanInsightsRow scanInsightsRowProducts" key={`product-${row.label}`}>
                    <div className="scanInsightsLabelBlock">
                      <div className="scanInsightsLabelCell" title={row.label}>{row.label}</div>
                      <div className="scanInsightsMetaCell" title={row.category ?? '-'}>{row.category ?? '-'}</div>
                    </div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
              </div>
            </section>
            <section className="scanInsightsPane">
              <div className="scanInsightsPaneTitle">Top 대카테고리</div>
              <div className="scanInsightsList">
                {(insights.topCategories ?? []).slice(0, 8).map((row) => (
                  <div className="scanInsightsRow" key={`category-${row.label}`}>
                    <div className="scanInsightsLabelCell" title={row.label}>{row.label}</div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
              </div>
            </section>
            <section className="scanInsightsPane">
              <div className="scanInsightsPaneTitle">시간대</div>
              <div className="scanInsightsList">
                {(insights.hourlyActivity ?? []).filter((row) => row.count > 0).slice(0, 8).map((row) => (
                  <div className="scanInsightsRow" key={`hour-${row.label}`}>
                    <div className="scanInsightsLabelCell">{row.label}</div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
              </div>
            </section>
            <section className="scanInsightsPane">
              <div className="scanInsightsPaneTitle">요일 / 최근일</div>
              <div className="scanInsightsList">
                {(insights.weekdayActivity ?? []).filter((row) => row.count > 0).map((row) => (
                  <div className="scanInsightsRow" key={`weekday-${row.label}`}>
                    <div className="scanInsightsLabelCell">{row.label}</div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
                {(insights.dailyActivity ?? []).slice(0, 5).map((row) => (
                  <div className="scanInsightsRow" key={`day-${row.label}`}>
                    <div className="scanInsightsLabelCell">{row.label}</div>
                    <div className="scanInsightsCountCell">{row.count}</div>
                  </div>
                ))}
              </div>
            </section>
          </div>
        </div>
      </div>

      <div className="exploreActionBar exploreActionBarSingle section" style={{ marginTop: 8 }}>
        <div className="exploreActionPanel exploreActionPanelTight">
          <div className="sectionHeader exploreSheetHeader" style={{ marginBottom: 0 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>Queue</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">{t('admin.scanops.meta.filter', 'filter')} {filter}</div>
              <div className="metaPill">feedback {summary.feedbackAccepted ?? 0} / {summary.feedbackCorrected ?? 0}</div>
              <div className="metaPill">dblclick or detail</div>
            </div>
          </div>
          <div className="editorSubtabRow scanOpsFilterTabs">
            {filterButtons.map(([key, label]) => (
              <button key={key} type="button" className={`editorSubtab ${filter === key ? 'active' : ''}`} onClick={() => setFilter(key)}>
                {label}
              </button>
            ))}
          </div>
          <div className="exploreSheetFilterGrid">
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">검색</div>
              <input className="textInput exploreSheetInput" value={query} onChange={(event) => setQuery(event.target.value)} placeholder={t('admin.scanops.filters.searchPlaceholder', 'job / user / result / message')} />
            </label>
          </div>
          <div style={{ display: 'grid', gap: 8, marginTop: 10, gridTemplateColumns: 'auto auto minmax(180px, 240px) auto', alignItems: 'end' }}>
            <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setSelectedJobIds(editableJobIds)} disabled={!editableJobIds.length || savingCategories}>보이는 결과 전체 선택</button>
            <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setSelectedJobIds([])} disabled={!selectedJobIds.length || savingCategories}>선택 해제</button>
            <label className="field" style={{ margin: 0 }}>
              <div className="exploreSheetFieldLabel">선택 카테고리</div>
              <select className="textInput exploreSheetInput" value={bulkCategory} onChange={(event) => setBulkCategory(event.target.value)} disabled={savingCategories}>
                <option value="">카테고리 선택</option>
                <option value={CATEGORY_CLEAR_VALUE}>자동 추론으로 복귀</option>
                {LARGE_CATEGORY_OPTIONS.map((option) => (
                  <option key={option} value={option}>{option}</option>
                ))}
              </select>
            </label>
            <button type="button" className="ghostBtn pageActionBtn" onClick={() => void saveJobCategories(selectedJobIds, bulkCategory)} disabled={!selectedJobIds.length || !bulkCategory || savingCategories}>
              {savingCategories ? '저장중...' : `선택 ${selectedJobIds.length}건 적용`}
            </button>
          </div>
        </div>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="card exploreDenseCard exploreSheetCard" style={{ gridColumn: '1 / -1' }}>
          <div className="sectionHeader exploreSheetHeader">
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>{t('admin.scanops.jobs.title', 'Jobs')}</h2>
            <div className="metaRow" style={{ marginTop: 0 }}>
              <div className="metaPill">{t('admin.scanops.jobs.filtered', 'filtered')} {filteredJobs.length}</div>
              <div className="metaPill">selected {selectedJobIds.length}</div>
              <div className="metaPill">{t('admin.scanops.jobs.failed', 'failed')} {summary.failedJobs ?? 0}</div>
            </div>
          </div>
          {filteredJobs.length === 0 ? (
            <div className="emptyState">{t('admin.scanops.jobs.emptyFiltered', '조건에 맞는 scan job이 없어')}</div>
          ) : (
            <div className="tableWrap">
              <table className="dataTable">
                <thead>
                  <tr>
                    <th style={{ width: 44 }}>선택</th>
                    <th>사진</th>
                    <th>{t('admin.scanops.jobs.table.status', 'Status')}</th>
                    <th>{t('admin.scanops.jobs.table.job', 'Job')}</th>
                    <th>결과값</th>
                    <th>카테고리 수정</th>
                    <th>고객 메시지</th>
                    <th>운영 로그</th>
                    <th>{t('admin.scanops.jobs.table.created', 'Created')}</th>
                    <th>{t('admin.scanops.jobs.table.action', 'Action')}</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredJobs.map((row, index) => {
                    const primaryResult = row.reviewedResult ?? row.result
                    const rowDraft = getCategoryDraft(row)
                    return (
                    <tr
                      key={row.id ?? index}
                      onDoubleClick={() => openJobDetail(row.id)}
                      onKeyDown={(event) => onJobRowKeyDown(event, row.id)}
                      tabIndex={0}
                      aria-label={`${row.id} detail 열기`}
                      style={{ cursor: 'pointer', background: selectedJob?.id === row.id ? 'rgba(102, 126, 234, 0.08)' : undefined }}
                    >
                      <td>
                        {primaryResult?.name ? (
                          <input type="checkbox" checked={selectedJobIds.includes(row.id)} onChange={(event) => { event.stopPropagation(); toggleJobSelection(row.id) }} />
                        ) : (
                          <span style={{ color: '#94a3b8' }}>-</span>
                        )}
                      </td>
                      <td>
                        {row.imageAvailable ? (
                          <img src={jobImageSrc(row.id)} alt={row.id} style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 8, border: '1px solid rgba(15, 23, 42, 0.1)', background: '#f8fafc' }} />
                        ) : (
                          <div style={{ width: 56, height: 56, borderRadius: 8, border: '1px dashed rgba(15, 23, 42, 0.15)', display: 'grid', placeItems: 'center', color: '#94a3b8', fontSize: 11 }}>-</div>
                        )}
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <strong>{row.status ?? '-'}</strong>
                          {row.latestFeedback ? <span className="metaPill">{feedbackLabel(row.latestFeedback)}</span> : null}
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4 }}>
                          <strong>{row.id ?? '-'}</strong>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{row.userId ?? '-'}</span>
                          <span style={{ color: '#64748b', fontSize: 12 }}>{deviceLabel(row.deviceMeta)}</span>
                        </div>
                      </td>
                      <td>
                        {primaryResult ? (
                          <div style={{ display: 'grid', gap: 4, minWidth: 220 }}>
                            <strong>{primaryResult.name ?? '-'}</strong>
                            <span style={{ color: '#0f172a', fontSize: 12 }}>{fmtPrice(primaryResult.price)}</span>
                            <span style={{ color: '#64748b', fontSize: 12 }}>{typeof primaryResult.confidence === 'number' ? `confidence ${primaryResult.confidence.toFixed(2)}` : primaryResult.source ?? '-'}</span>
                            <span className="metaPill">대카테고리 {categoryLabel(row.categoryMeta)}</span>
                            {row.reviewedResult ? <span className="metaPill">customer reviewed</span> : null}
                          </div>
                        ) : (
                          <span style={{ color: '#94a3b8' }}>-</span>
                        )}
                      </td>
                      <td>
                        {primaryResult ? (
                          <div style={{ display: 'grid', gap: 6, minWidth: 180 }}>
                            <span className="metaPill">{row.categoryMeta?.categorySource ?? '-'}</span>
                            <select className="textInput exploreSheetInput" value={rowDraft} onChange={(event) => setRowCategoryDrafts((current) => ({ ...current, [row.id]: event.target.value }))} onClick={(event) => event.stopPropagation()} disabled={savingCategories}>
                              <option value={CATEGORY_CLEAR_VALUE}>자동 추론</option>
                              {LARGE_CATEGORY_OPTIONS.map((option) => (
                                <option key={option} value={option}>{option}</option>
                              ))}
                            </select>
                            <button className="ghostBtn ghostBtnSmall" type="button" onClick={(event) => { event.stopPropagation(); void saveJobCategories([row.id], rowDraft) }} disabled={savingCategories}>
                              적용
                            </button>
                          </div>
                        ) : (
                          <span style={{ color: '#94a3b8' }}>-</span>
                        )}
                      </td>
                      <td>
                        <div style={{ minWidth: 220, whiteSpace: 'pre-wrap', lineHeight: 1.45 }}>{row.customerMessage ?? '-'}</div>
                      </td>
                      <td>
                        <div style={{ display: 'grid', gap: 4, minWidth: 240 }}>
                          {row.latestFailure ? (
                            <>
                              <strong>{row.latestFailure.stage ?? '-'}</strong>
                              <span style={{ color: '#0f172a', fontSize: 12 }}>{row.latestFailure.errorCode ?? row.errorCode ?? '-'}</span>
                              <span style={{ color: '#64748b', fontSize: 12, whiteSpace: 'pre-wrap', lineHeight: 1.45 }}>{row.latestFailure.errorMessage ?? row.errorMessage ?? '-'}</span>
                            </>
                          ) : row.latestFeedback ? (
                            <>
                              <strong>{feedbackLabel(row.latestFeedback)}</strong>
                              <span style={{ color: '#64748b', fontSize: 12 }}>{fmt(row.latestFeedback.createdAt)}</span>
                            </>
                          ) : (
                            <span style={{ color: '#94a3b8' }}>{row.errorCode ?? '-'}</span>
                          )}
                        </div>
                      </td>
                      <td>{fmt(row.createdAt)}</td>
                      <td>
                        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                          <button className="ghostBtn ghostBtnSmall" type="button" onClick={(event) => { event.stopPropagation(); openJobDetail(row.id) }}>
                            detail
                          </button>
                          {row.status === 'failed' ? (
                            <>
                              <button className="ghostBtn ghostBtnSmall" type="button" disabled={retryingJobId === row.id || res.usingFallback} onClick={(event) => { event.stopPropagation(); void retryJob(row.id) }}>
                                {retryingJobId === row.id ? t('admin.scanops.action.retrying', 'retrying...') : t('admin.scanops.action.retry', 'retry')}
                              </button>
                              <button className="ghostBtn ghostBtnSmall" type="button" disabled={quarantiningJobId === row.id || res.usingFallback} onClick={(event) => { event.stopPropagation(); void quarantineJob(row.id) }}>
                                {quarantiningJobId === row.id ? t('admin.scanops.action.moving', 'moving...') : t('admin.scanops.action.quarantine', 'quarantine')}
                              </button>
                            </>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                    )})}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {selectedJob ? (
        <div className="confirmOverlay" onClick={() => setSelectedJobId(null)}>
          <div className="confirmDialog" style={{ width: 'min(1040px, 100%)' }} onClick={(event) => event.stopPropagation()}>
            <div className="sectionHeader" style={{ marginBottom: 0 }}>
              <div>
                <div className="confirmTitle">{t('admin.scanops.jobs.detailTitle', 'Job detail')}</div>
              </div>
              <div className="metaRow" style={{ marginTop: 0 }}>
                <span className="metaPill">{selectedJob.status ?? '-'}</span>
                <span className="metaPill">failures {selectedFailureHistory.length}</span>
                <span className="metaPill">feedback {selectedFeedbackHistory.length}</span>
                <button type="button" className="ghostBtn ghostBtnSmall" onClick={() => setSelectedJobId(null)}>닫기</button>
              </div>
            </div>

            <div style={{ display: 'grid', gap: 12 }}>
              <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'minmax(240px, 320px) minmax(0, 1fr)' }}>
                <div className="card exploreDenseCard" style={{ padding: 12 }}>
                  {selectedJob.imageAvailable ? (
                    <img src={jobImageSrc(selectedJob.id)} alt={selectedJob.id} style={{ width: '100%', maxHeight: 360, objectFit: 'contain', borderRadius: 10, background: '#f8fafc', border: '1px solid rgba(15, 23, 42, 0.08)' }} />
                  ) : (
                    <div className="emptyState" style={{ minHeight: 220 }}>이미지 없음</div>
                  )}
                  {selectedJob.imagePathLabel ? <div style={{ marginTop: 8, color: '#64748b', fontSize: 12 }}>{selectedJob.imagePathLabel}</div> : null}
                </div>

                <div className="tableWrap">
                  <table className="dataTable exploreDenseTable">
                    <tbody>
                      <tr><td>{t('admin.scanops.jobs.detail.jobId', 'Job ID')}</td><td>{selectedJob.id}</td></tr>
                      <tr><td>{t('admin.scanops.jobs.detail.status', 'Status')}</td><td>{selectedJob.status ?? '-'}</td></tr>
                      <tr><td>{t('admin.scanops.jobs.detail.user', 'User')}</td><td>{selectedJob.userId ?? '-'}</td></tr>
                      <tr><td>촬영 기기</td><td>{deviceLabel(selectedJob.deviceMeta)}</td></tr>
                      <tr><td>{t('admin.scanops.jobs.detail.created', 'Created')}</td><td>{fmt(selectedJob.createdAt)}</td></tr>
                      <tr><td>{t('admin.scanops.jobs.detail.updated', 'Updated')}</td><td>{fmt(selectedJob.updatedAt)}</td></tr>
                      <tr><td>Started</td><td>{fmt(selectedJob.startedAt)}</td></tr>
                      <tr><td>Finished</td><td>{fmt(selectedJob.finishedAt)}</td></tr>
                      <tr><td>고객 메시지</td><td style={{ whiteSpace: 'pre-wrap' }}>{selectedJob.customerMessage ?? '-'}</td></tr>
                      <tr><td>{t('admin.scanops.jobs.detail.errorCode', 'Error code')}</td><td>{selectedJob.errorCode ?? selectedJob.latestFailure?.errorCode ?? '-'}</td></tr>
                      <tr><td>{t('admin.scanops.jobs.detail.errorMessage', 'Error message')}</td><td style={{ whiteSpace: 'pre-wrap' }}>{selectedJob.errorMessage ?? selectedJob.latestFailure?.errorMessage ?? '-'}</td></tr>
                    </tbody>
                  </table>
                </div>
              </div>

              {selectedPrimaryResult ? (
                <div className="card exploreDenseCard exploreSheetCard" style={{ padding: 12 }}>
                  <div className="sectionHeader exploreSheetHeader">
                    <h2 className="panelTitle" style={{ marginBottom: 0 }}>고객 기준 결과</h2>
                    <div className="metaRow" style={{ marginTop: 0 }}>
                      {typeof selectedPrimaryResult.confidence === 'number' ? <span className="metaPill">confidence {selectedPrimaryResult.confidence.toFixed(2)}</span> : null}
                      {selectedJob.reviewedResult ? <span className="metaPill">reviewed</span> : <span className="metaPill">raw</span>}
                      <span className="metaPill">category {selectedJob.categoryMeta?.naverLargeCategory ?? '-'}</span>
                      <span className="metaPill">source {selectedJob.categoryMeta?.categorySource ?? '-'}</span>
                    </div>
                  </div>
                  <div style={{ display: 'grid', gap: 10, gridTemplateColumns: 'minmax(220px, 280px) minmax(0, 1fr)', alignItems: 'end', marginBottom: 10 }}>
                    <label className="field" style={{ margin: 0 }}>
                      <div className="exploreSheetFieldLabel">대카테고리 수정</div>
                      <select className="textInput exploreSheetInput" value={selectedCategoryDraft} onChange={(event) => setRowCategoryDrafts((current) => ({ ...current, [selectedJob.id]: event.target.value }))} disabled={savingCategories}>
                        <option value={CATEGORY_CLEAR_VALUE}>자동 추론</option>
                        {LARGE_CATEGORY_OPTIONS.map((option) => (
                          <option key={option} value={option}>{option}</option>
                        ))}
                      </select>
                    </label>
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                      <button className="ghostBtn ghostBtnSmall" type="button" onClick={() => void saveJobCategories([selectedJob.id], selectedCategoryDraft)} disabled={savingCategories}>
                        {savingCategories ? '저장중...' : '카테고리 적용'}
                      </button>
                      {selectedJob.status === 'failed' ? (
                        <>
                          <button className="ghostBtn ghostBtnSmall" type="button" disabled={retryingJobId === selectedJob.id || res.usingFallback} onClick={() => void retryJob(selectedJob.id)}>
                            {retryingJobId === selectedJob.id ? t('admin.scanops.action.retrying', 'retrying...') : t('admin.scanops.action.retry', 'retry')}
                          </button>
                          <button className="ghostBtn ghostBtnSmall" type="button" disabled={quarantiningJobId === selectedJob.id || res.usingFallback} onClick={async () => { await quarantineJob(selectedJob.id) }}>
                            {quarantiningJobId === selectedJob.id ? t('admin.scanops.action.moving', 'moving...') : t('admin.scanops.action.quarantine', 'quarantine')}
                          </button>
                        </>
                      ) : null}
                    </div>
                  </div>
                  <div className="tableWrap">
                    <table className="dataTable exploreDenseTable">
                      <tbody>
                        <tr><td>상품명</td><td>{selectedPrimaryResult.name ?? '-'}</td></tr>
                        <tr><td>가격</td><td>{fmtPrice(selectedPrimaryResult.price)}</td></tr>
                        <tr><td>SKU</td><td>{selectedPrimaryResult.sku ?? '-'}</td></tr>
                        <tr><td>Source</td><td>{selectedPrimaryResult.source ?? '-'}</td></tr>
                        <tr><td>대카테고리</td><td>{selectedJob.categoryMeta?.naverLargeCategory ?? '-'}</td></tr>
                        <tr><td>카테고리 경로</td><td style={{ whiteSpace: 'pre-wrap' }}>{selectedJob.categoryMeta?.naverCategoryPath ?? '-'}</td></tr>
                        <tr><td>카테고리 source</td><td>{selectedJob.categoryMeta?.categorySource ?? '-'}</td></tr>
                        <tr><td>원문</td><td style={{ whiteSpace: 'pre-wrap' }}>{selectedPrimaryResult.rawText ?? '-'}</td></tr>
                      </tbody>
                    </table>
                  </div>
                  {selectedJob.result && selectedJob.reviewedResult ? (
                    <details style={{ marginTop: 10 }}>
                      <summary style={{ cursor: 'pointer', fontWeight: 700 }}>original raw result</summary>
                      <pre style={{ marginTop: 8, padding: 12, background: '#f8fafc', borderRadius: 10, overflowX: 'auto', fontSize: 12, lineHeight: 1.45 }}>{formatJson(selectedJob.result)}</pre>
                    </details>
                  ) : null}
                  {selectedJob.resultPayload ? (
                    <details style={{ marginTop: 10 }}>
                      <summary style={{ cursor: 'pointer', fontWeight: 700 }}>raw result payload</summary>
                      <pre style={{ marginTop: 8, padding: 12, background: '#f8fafc', borderRadius: 10, overflowX: 'auto', fontSize: 12, lineHeight: 1.45 }}>{formatJson(selectedJob.resultPayload)}</pre>
                    </details>
                  ) : null}
                </div>
              ) : null}

              {selectedFailureHistory.length > 0 ? (
                <div className="card exploreDenseCard exploreSheetCard" style={{ padding: 12 }}>
                  <div className="sectionHeader exploreSheetHeader">
                    <h2 className="panelTitle" style={{ marginBottom: 0 }}>실패 이력</h2>
                    <span className="metaPill">{selectedFailureHistory.length}</span>
                  </div>
                  <div className="tableWrap">
                    <table className="dataTable">
                      <thead>
                        <tr>
                          <th>Time</th>
                          <th>Stage</th>
                          <th>Code</th>
                          <th>Message</th>
                        </tr>
                      </thead>
                      <tbody>
                        {selectedFailureHistory.map((failure) => (
                          <tr key={failure.id}>
                            <td>{fmt(failure.createdAt)}</td>
                            <td>{failure.stage ?? '-'}</td>
                            <td>{failure.errorCode ?? '-'}</td>
                            <td style={{ whiteSpace: 'pre-wrap' }}>{failure.errorMessage ?? '-'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {selectedJob.latestFailure?.details ? (
                    <details style={{ marginTop: 10 }}>
                      <summary style={{ cursor: 'pointer', fontWeight: 700 }}>latest failure details</summary>
                      <pre style={{ marginTop: 8, padding: 12, background: '#f8fafc', borderRadius: 10, overflowX: 'auto', fontSize: 12, lineHeight: 1.45 }}>{formatJson(selectedJob.latestFailure.details)}</pre>
                    </details>
                  ) : null}
                </div>
              ) : null}

              {selectedFeedbackHistory.length > 0 ? (
                <div className="card exploreDenseCard exploreSheetCard" style={{ padding: 12 }}>
                  <div className="sectionHeader exploreSheetHeader">
                    <h2 className="panelTitle" style={{ marginBottom: 0 }}>고객 피드백 이력</h2>
                    <span className="metaPill">{selectedFeedbackHistory.length}</span>
                  </div>
                  <div className="tableWrap">
                    <table className="dataTable">
                      <thead>
                        <tr>
                          <th>Time</th>
                          <th>상태</th>
                          <th>Original</th>
                          <th>Corrected</th>
                        </tr>
                      </thead>
                      <tbody>
                        {selectedFeedbackHistory.map((feedback) => (
                          <tr key={feedback.id}>
                            <td>{fmt(feedback.createdAt)}</td>
                            <td>{feedbackLabel(feedback)}</td>
                            <td style={{ whiteSpace: 'pre-wrap' }}>{feedback.original ? formatJson(feedback.original) : '-'}</td>
                            <td style={{ whiteSpace: 'pre-wrap' }}>{feedback.corrected ? formatJson(feedback.corrected) : '-'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              ) : null}
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
