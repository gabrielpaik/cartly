'use client'

import type { FormEvent } from 'react'
import { useState } from 'react'

import { isUnauthorizedError, loginAdmin } from '../lib/api'
import { useAdminCopy } from './AdminCopyProvider'
import AdminBrandMark from './AdminBrandMark'

export default function LoginScreen({ nextPath, reason }: { nextPath?: string; reason?: string }) {
  const { t } = useAdminCopy()
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(
    reason === 'expired' ? t('admin.login.error.expired', '세션이 만료됐거나 비밀번호가 바뀌었어. 다시 로그인해.') : null,
  )

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setSubmitting(true)
    setError(null)
    try {
      await loginAdmin(password)
      window.location.assign(nextPath || '/overview')
    } catch (err) {
      if (isUnauthorizedError(err)) {
        setError(t('admin.login.error.invalid', '비밀번호가 맞지 않아. 다시 확인해.'))
      } else {
        setError(err instanceof Error ? err.message : t('admin.login.error.failed', '로그인에 실패했어'))
      }
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="loginShell">
      <div className="loginCard">
        <div className="loginBrandWrap">
          <AdminBrandMark variant="login" live={false} />
        </div>
        <div className="eyebrow">운영센터</div>
        <h1 className="pageTitle" style={{ marginBottom: 10 }}>비밀번호 확인</h1>
        <p className="pageDesc" style={{ marginBottom: 20 }}>관리자 비밀번호 입력</p>

        <form className="sectionGrid" onSubmit={onSubmit}>
          <label className="field">
            <div className="fieldLabel">{t('admin.login.passwordLabel', '관리자 비밀번호')}</div>
            <input
              className="textInput"
              type="password"
              autoComplete="current-password"
              autoFocus
              value={password}
              placeholder={t('admin.login.passwordPlaceholder', '비밀번호 입력')}
              onChange={(e) => setPassword(e.target.value)}
            />
          </label>

          <button className="primaryBtn loginBtn" disabled={submitting || !password.trim()} type="submit">
            {submitting ? t('admin.login.submitting', '확인 중...') : t('admin.login.submit', '들어가기')}
          </button>
        </form>

        {error ? <div className="loginError">{error}</div> : null}
      </div>
    </div>
  )
}
