'use client'

import type { ReactNode } from 'react'

import { useAdminCopy } from './AdminCopyProvider'

export default function PageHeader({
  title,
  description,
  badge,
  onRefresh,
  refreshing,
  actionLabel,
  inlineRefresh = false,
  actions,
}: {
  title: string
  description: string
  badge?: string
  onRefresh?: () => void
  refreshing?: boolean
  actionLabel?: string
  inlineRefresh?: boolean
  actions?: ReactNode
}) {
  const { t } = useAdminCopy()

  return (
    <div className="pageHeader">
      <div>
        {badge ? <div className="eyebrow">{badge}</div> : null}
        <div className="pageTitleRow">
          <h1 className="pageTitle">{title}</h1>
          {onRefresh && inlineRefresh ? (
            <button
              className="iconRefreshBtn"
              type="button"
              onClick={onRefresh}
              disabled={refreshing}
              aria-label={actionLabel ?? t('admin.common.refresh', '데이터 불러오기')}
              title={actionLabel ?? t('admin.common.refresh', '데이터 불러오기')}
            >
              ↻
            </button>
          ) : null}
        </div>
        <p className="pageDesc">{description}</p>
      </div>
      {((onRefresh && !inlineRefresh) || actions) ? (
        <div className="pageActions">
          {actions}
          {onRefresh && !inlineRefresh ? (
            <button className="ghostBtn pageActionBtn" type="button" onClick={onRefresh} disabled={refreshing}>
              {refreshing ? t('admin.common.refreshing', '불러오는 중...') : actionLabel ?? t('admin.common.refresh', '데이터 불러오기')}
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  )
}
