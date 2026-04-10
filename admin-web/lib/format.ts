export function formatNumber(value: number | null | undefined) {
  return new Intl.NumberFormat('en-US').format(value ?? 0)
}

export function formatPercent(value: number | null | undefined) {
  return `${(((value ?? 0) * 100)).toFixed(1)}%`
}

export function formatDate(value: string | null | undefined) {
  if (!value) return '-'
  try {
    return new Intl.DateTimeFormat('ko-KR', {
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit'
    }).format(new Date(value))
  } catch {
    return value
  }
}

export function statusTone(status: string | null | undefined) {
  switch ((status ?? '').toLowerCase()) {
    case 'done':
    case 'active':
      return 'green'
    case 'failed':
    case 'error':
      return 'red'
    default:
      return 'blue'
  }
}
