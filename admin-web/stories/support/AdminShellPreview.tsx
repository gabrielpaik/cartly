import type { ReactNode } from 'react'

const nav = [
  ['Overview', '/overview'],
  ['Users', '/users'],
  ['Scan Ops', '/scan-ops'],
  ['Carts', '/carts'],
  ['Ads', '/ads'],
  ['Content', '/content'],
  ['Config', '/config'],
] as const

export default function AdminShellPreview({
  activeHref,
  children,
}: {
  activeHref: string
  children: ReactNode
}) {
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brandWrap">
          <div className="brand">Cartly Admin</div>
        </div>
        <nav>
          {nav.map(([label, href]) => (
            <a
              key={href}
              href="#"
              className={`navLink ${href === activeHref ? 'active' : ''}`}
              onClick={(event) => event.preventDefault()}
            >
              {label}
            </a>
          ))}
          <div className="navLogoutWrap">
            <button className="ghostBtn ghostBtnSmall" type="button">
              로그아웃
            </button>
          </div>
        </nav>
      </aside>
      <main className="content">{children}</main>
    </div>
  )
}
