'use client'

import type { ReactNode } from 'react'

import AdminCopyProvider, { useAdminCopy } from './AdminCopyProvider'
import LogoutButton from './LogoutButton'
import NavLink from './NavLink'

const nav = [
  ['admin.nav.overview', '/overview', 'Overview'],
  ['admin.nav.users', '/users', 'Users'],
  ['admin.nav.scanOps', '/scan-ops', 'Scan Ops'],
  ['admin.nav.carts', '/carts', 'Carts'],
  ['admin.nav.ads', '/ads', 'Ads'],
  ['admin.nav.content', '/content', 'Content'],
  ['admin.nav.config', '/config', 'Config'],
] as const

function AdminChromeInner({ children }: { children: ReactNode }) {
  const { t } = useAdminCopy()

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brandWrap">
          <div className="brand">{t('admin.nav.brand', 'Cartly Admin')}</div>
          <div className="brandMeta">runtime, landing, smoke, content를 한 화면에서 보는 운영면</div>
        </div>
        <div className="sidebarSectionLabel">Control room</div>
        <nav>
          {nav.map(([label, href, fallback]) => (
            <NavLink key={href} href={href} label={t(label, fallback)} />
          ))}
          <div className="navLogoutWrap">
            <LogoutButton compact />
          </div>
        </nav>
      </aside>
      <main className="content">
        <div className="contentInner">{children}</div>
      </main>
    </div>
  )
}

export default function AdminChrome({ children }: { children: ReactNode }) {
  return (
    <AdminCopyProvider>
      <AdminChromeInner>{children}</AdminChromeInner>
    </AdminCopyProvider>
  )
}
