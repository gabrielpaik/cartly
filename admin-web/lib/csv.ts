export type CsvScalar = string | number | boolean | null | undefined

function escapeCsvCell(value: CsvScalar) {
  const text = value == null ? '' : String(value)
  if (/[,"\n\r]/.test(text)) {
    return `"${text.replace(/"/g, '""')}"`
  }
  return text
}

function stripBom(text: string) {
  return text.replace(/^\uFEFF/, '')
}

function isCommentRow(row: string[]) {
  const firstValue = row.find((cell) => cell.trim().length > 0)?.trim() ?? ''
  return firstValue.startsWith('#')
}

export function csvTextFromObjects(
  rows: Array<Record<string, CsvScalar>>,
  options: {
    headers?: string[]
    commentLines?: string[]
  } = {},
) {
  const headers = options.headers ?? Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
  const csvRows = [headers, ...rows.map((row) => headers.map((header) => row[header]))]
  const body = csvRows.map((row) => row.map(escapeCsvCell).join(',')).join('\r\n')
  const comments = (options.commentLines ?? []).map((line) => `# ${line}`.trimEnd())
  return [...comments, body].filter(Boolean).join('\r\n')
}

export function downloadCsv(filename: string, text: string) {
  const blob = new Blob([`\uFEFF${text}`], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

export function parseCsvRows(text: string) {
  const rows: string[][] = []
  let currentRow: string[] = []
  let currentCell = ''
  let inQuotes = false

  const source = stripBom(text)
  for (let index = 0; index < source.length; index += 1) {
    const char = source[index]

    if (inQuotes) {
      if (char === '"') {
        if (source[index + 1] === '"') {
          currentCell += '"'
          index += 1
        } else {
          inQuotes = false
        }
      } else {
        currentCell += char
      }
      continue
    }

    if (char === '"') {
      inQuotes = true
      continue
    }

    if (char === ',') {
      currentRow.push(currentCell)
      currentCell = ''
      continue
    }

    if (char === '\n') {
      currentRow.push(currentCell)
      rows.push(currentRow)
      currentRow = []
      currentCell = ''
      continue
    }

    if (char === '\r') {
      continue
    }

    currentCell += char
  }

  currentRow.push(currentCell)
  if (currentRow.some((cell) => cell.length > 0)) {
    rows.push(currentRow)
  }

  return rows
}

export function parseCsvObjects(text: string) {
  const rows = parseCsvRows(text).filter((row) => row.some((cell) => cell.trim().length > 0))
  while (rows.length > 0 && isCommentRow(rows[0])) {
    rows.shift()
  }

  const headerRow = rows.shift()
  if (!headerRow || headerRow.every((cell) => cell.trim().length === 0)) {
    return [] as Record<string, string>[]
  }

  const headers = headerRow.map((cell) => cell.trim())
  return rows
    .filter((row) => !isCommentRow(row))
    .map<Record<string, string>>((row) => {
      const record: Record<string, string> = {}
      headers.forEach((header, index) => {
        if (!header) return
        record[header] = row[index] ?? ''
      })
      return record
    })
}

export async function readCsvObjects(file: File) {
  return parseCsvObjects(await file.text())
}
