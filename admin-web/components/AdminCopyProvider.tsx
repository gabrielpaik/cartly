'use client'

import type { ReactNode } from 'react'
import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import { usePathname, useRouter } from 'next/navigation'

import { fetchJsonSafe, isUnauthorizedError, putJson } from '../lib/api'
import { ADMIN_COPY_DEFAULTS } from '../lib/adminCopyDefaults'

type CopyContextValue = {
  t: (key: string, fallback?: string) => string
  editMode: boolean
  setEditMode: (value: boolean) => void
  updateValue: (key: string, value: string) => void
  save: () => Promise<void>
  reset: () => void
  saving: boolean
  canEdit: boolean
  visibleEntries: Array<[string, string]>
  message: string | null
}

const fallbackContext: CopyContextValue = {
  t: (key, fallback) => ADMIN_COPY_DEFAULTS[key] ?? fallback ?? key,
  editMode: false,
  setEditMode: () => undefined,
  updateValue: () => undefined,
  save: async () => undefined,
  reset: () => undefined,
  saving: false,
  canEdit: false,
  visibleEntries: [],
  message: null,
}

const AdminCopyContext = createContext<CopyContextValue | null>(null)

function visiblePrefixes(pathname?: string | null) {
  const safePathname = pathname ?? ''
  const common = ['admin.nav.', 'admin.common.', 'admin.copy.']
  if (safePathname.startsWith('/overview')) return [...common, 'admin.overview.']
  if (safePathname.startsWith('/users/')) return [...common, 'admin.users.', 'admin.users.detail.']
  if (safePathname.startsWith('/users')) return [...common, 'admin.users.']
  if (safePathname.startsWith('/scan-ops')) return [...common, 'admin.scanops.']
  if (safePathname.startsWith('/carts')) return [...common, 'admin.carts.']
  if (safePathname.startsWith('/ads')) return [...common, 'admin.ads.']
  if (safePathname.startsWith('/content')) return [...common, 'admin.content.']
  if (safePathname.startsWith('/config')) return [...common, 'admin.config.']
  if (safePathname.startsWith('/login')) return [...common, 'admin.login.']
  return common
}

export function useAdminCopy() {
  const context = useContext(AdminCopyContext)
  return context ?? fallbackContext
}

export default function AdminCopyProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname() ?? ''
  const router = useRouter()
  const [savedValues, setSavedValues] = useState<Record<string, string>>({})
  const [draftValues, setDraftValues] = useState<Record<string, string>>({})
  const [editMode, setEditMode] = useState(false)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  const canEdit = !pathname.startsWith('/config')

  useEffect(() => {
    let cancelled = false
    fetchJsonSafe<{ ok: boolean; data: { values: Record<string, string> } }>('/admin/ui-copy', { ok: true, data: { values: {} } })
      .then((res) => {
        if (cancelled) return
        setSavedValues(res.data.data.values)
        setDraftValues(res.data.data.values)
      })
      .catch((err) => {
        if (isUnauthorizedError(err)) return
        if (cancelled) return
      })
    return () => {
      cancelled = true
    }
  }, [])

  const mergedValues = useMemo(() => ({ ...ADMIN_COPY_DEFAULTS, ...draftValues }), [draftValues])
  const visibleEntries = useMemo(() => {
    const prefixes = visiblePrefixes(pathname)
    return Object.entries(mergedValues).filter(([key]) => prefixes.some((prefix) => key.startsWith(prefix)))
  }, [mergedValues, pathname])

  const t = (key: string, fallback?: string) => mergedValues[key] ?? fallback ?? key

  function updateValue(key: string, value: string) {
    setDraftValues((prev) => ({ ...prev, [key]: value }))
  }

  function reset() {
    setDraftValues(savedValues)
    setMessage(null)
  }

  async function save() {
    setSaving(true)
    setMessage(null)
    try {
      const response = await putJson<{ ok: boolean; data: { values: Record<string, string> } }>('/admin/ui-copy', {
        values: draftValues,
      })
      setSavedValues(response.data.values)
      setDraftValues(response.data.values)
      setMessage(t('admin.copy.saved', '문구 저장 완료'))
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setMessage(err instanceof Error ? err.message : t('admin.copy.saveFailed', '문구 저장 실패'))
    } finally {
      setSaving(false)
    }
  }

  return (
    <AdminCopyContext.Provider value={{ t, editMode, setEditMode, updateValue, save, reset, saving, canEdit, visibleEntries, message }}>
      {children}
      {canEdit ? (
        <div className="copyModeDock">
          <button className={`ghostBtn ${editMode ? 'active' : ''}`} type="button" onClick={() => setEditMode(!editMode)}>
            {t('admin.copy.toggle', '수정 모드')}
          </button>
        </div>
      ) : null}
      {canEdit && editMode ? (
        <aside className="copyEditPanel">
          <div className="sectionHeader" style={{ marginBottom: 12 }}>
            <div>
              <h2 className="panelTitle" style={{ marginBottom: 6 }}>{t('admin.copy.panelTitle', '현재 페이지 문구 수정')}</h2>
              <p className="pageDesc">{t('admin.copy.panelDesc', 'Config 페이지는 제외하고, 현재 화면에 보이는 고정 문구를 바로 수정한다.')}</p>
            </div>
          </div>
          {message ? <div className="saveMessage" style={{ marginBottom: 12 }}>{message}</div> : null}
          <div className="copyEditList">
            {visibleEntries.length === 0 ? (
              <div className="emptyState">{t('admin.copy.empty', '이 페이지에 등록된 문구가 아직 없어')}</div>
            ) : (
              visibleEntries.map(([key, value]) => (
                <label className="field" key={key}>
                  <div className="fieldLabel">{key}</div>
                  {value.length > 40 ? (
                    <textarea className="textInput" rows={3} value={value} onChange={(event) => updateValue(key, event.target.value)} />
                  ) : (
                    <input className="textInput" value={value} onChange={(event) => updateValue(key, event.target.value)} />
                  )}
                </label>
              ))
            )}
          </div>
          <div className="buttonRow" style={{ marginTop: 16 }}>
            <button className="ghostBtn pageActionBtn" type="button" onClick={reset}>{t('admin.copy.cancel', '취소')}</button>
            <button className="primaryBtn pageActionBtn" type="button" disabled={saving} onClick={() => void save()}>
              {saving ? t('admin.copy.saving', '저장 중...') : t('admin.copy.save', '문구 저장')}
            </button>
          </div>
        </aside>
      ) : null}
    </AdminCopyContext.Provider>
  )
}
