'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

import { logoutAdmin } from '../lib/api'
import { useAdminCopy } from './AdminCopyProvider'

export default function LogoutButton({ compact = false }: { compact?: boolean }) {
  const router = useRouter()
  const { t } = useAdminCopy()
  const [busy, setBusy] = useState(false)

  async function onLogout() {
    setBusy(true)
    try {
      await logoutAdmin()
      router.replace('/login')
      router.refresh()
    } finally {
      setBusy(false)
    }
  }

  return (
    <button
      className={compact ? 'ghostBtn ghostBtnSmall' : 'ghostBtn'}
      disabled={busy}
      onClick={onLogout}
      type="button"
    >
      {busy ? t('admin.nav.loggingOut', '정리 중...') : t('admin.nav.logout', '로그아웃')}
    </button>
  )
}
