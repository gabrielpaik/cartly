import './globals.css'
import NavLink from '../components/NavLink'

export const metadata = {
  title: 'WIMC Admin',
  description: 'WIMC backoffice dashboard',
}

const nav = [
  ['Overview', '/overview'],
  ['Users', '/users'],
  ['Scan Ops', '/scan-ops'],
  ['Carts', '/carts'],
  ['Ads', '/ads'],
  ['Config', '/config'],
] as const

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <div className="shell">
          <aside className="sidebar">
            <div className="brandWrap">
              <div className="brand">WIMC Admin</div>
              <div className="brandMeta">CTO · CMO · CDO · CFO 운영 보드</div>
            </div>
            <nav>
              {nav.map(([label, href]) => (
                <NavLink key={href} href={href} label={label} />
              ))}
            </nav>
            <div className="sidebarFoot">
              <div className="miniLabel">운영 원칙</div>
              <ul>
                <li>OCR 품질은 측정하고 보정한다</li>
                <li>핵심 루프는 광고보다 우선한다</li>
                <li>저장/히스토리/재사용이 제품 가치다</li>
              </ul>
            </div>
          </aside>
          <main className="content">{children}</main>
        </div>
      </body>
    </html>
  )
}
