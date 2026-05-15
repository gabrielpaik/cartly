'use client'

import type { ReactNode } from 'react'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

import AdminCopyProvider, { useAdminCopy } from './AdminCopyProvider'
import LogoutButton from './LogoutButton'
import NavLink from './NavLink'

const contentSectionNavItems = [
  { href: '/content?section=brand', label: 'Brand' },
  { href: '/content?section=app', label: 'App Copy' },
  { href: '/content?section=account', label: 'Account' },
  { href: '/content?section=public', label: 'Public Site' },
] as const

const exploreWorkspaceNavItems = [
  { href: '/explore?ws=layout', label: 'Layout' },
  { href: '/explore?ws=recommendations', label: 'Recommendation Pool' },
  { href: '/explore?ws=rules', label: 'Decision Rules' },
  { href: '/explore?ws=copy', label: 'Decision Copy' },
  { href: '/explore?ws=store', label: 'Store Context' },
] as const

const configPaneNavItems = [
  { href: '/config?pane=overview', label: '전체 상태' },
  { href: '/config?pane=smoke', label: '운영 점검' },
  { href: '/config?pane=runtime', label: '저장소 / 기동' },
  { href: '/config?pane=my-page', label: '마이페이지' },
  { href: '/config?pane=coupang', label: '제휴 연동' },
] as const

const adsSectionNavItems = [
  { href: '/ads#ads-runtime-health', label: '현황' },
  { href: '/ads#ads-quick-setup', label: '세팅' },
  { href: '/ads#ads-efficiency-review', label: '효율' },
] as const

const usersNavItems = [
  { href: '/users', label: 'Accounts' },
  { href: '/users/legacy-cleanup', label: 'Legacy Cleanup' },
] as const

type NavItem = {
  href: string
  label: string
  description: string
}

type NavGroup = {
  id: string
  label: string
  description: string
  items: NavItem[]
}

const navGroups: NavGroup[] = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    description: '상태판과 운영 현황',
    items: [
      { href: '/overview', label: 'Overview', description: '전체 상태, alert, quick action' },
    ],
  },
  {
    id: 'experience',
    label: 'App Experience',
    description: '앱 화면과 사용자 경험 운영',
    items: [
      { href: '/content', label: 'Content Surfaces', description: 'Home, My, Login, Receipt 카피와 화면 문구' },
      { href: '/explore', label: 'Explore Journeys', description: '추천 제품, 상태별 구성, 탐색 흐름' },
    ],
  },
  {
    id: 'growth',
    label: 'Growth',
    description: '리텐션과 수익화 운영',
    items: [
      { href: '/push', label: 'Push', description: '푸시 메시지, 딥링크, 발송 흐름' },
      { href: '/ads', label: 'Ads', description: '광고 슬롯, 크리에이티브, 배치 미리보기' },
    ],
  },
  {
    id: 'operations',
    label: 'Operations',
    description: '실사용 데이터와 장애 대응',
    items: [
      { href: '/users', label: 'Users', description: '가입 상태와 사용자 세션 확인' },
      { href: '/carts', label: 'Carts', description: '저장 카트와 영수증 흐름 추적' },
      { href: '/scan-ops', label: 'Scan Ops', description: '스캔 큐, worker, 실패 이슈 확인' },
    ],
  },
  {
    id: 'system',
    label: 'System',
    description: 'runtime, 설정, 안전장치',
    items: [
      { href: '/config', label: 'Runtime Config', description: '런타임 설정, feature flag, 파트너 제어' },
    ],
  },
]

const allNavItems = navGroups.flatMap((group) => group.items)

function normalizePathname(pathname: string) {
  if (!pathname || pathname === '/') {
    return '/overview'
  }
  return pathname
}

function pathMatches(pathname: string, href: string) {
  return pathname === href || pathname.startsWith(`${href}/`)
}

function findCurrentNavItem(pathname: string) {
  const normalized = normalizePathname(pathname)
  return allNavItems.find((item) => pathMatches(normalized, item.href)) ?? allNavItems[0]
}

function findCurrentNavGroup(pathname: string) {
  const normalized = normalizePathname(pathname)
  return (
    navGroups.find((group) => group.items.some((item) => pathMatches(normalized, item.href))) ?? navGroups[0]
  )
}

function AdminChromeInner({ children }: { children: ReactNode }) {
  const pathname = usePathname() ?? '/overview'
  const { t } = useAdminCopy()

  if (pathname === '/login') {
    return <>{children}</>
  }

  const currentItem = findCurrentNavItem(pathname)
  const currentGroup = findCurrentNavGroup(pathname)

  return (
    <div className="shell shellConsole">
      <header className="adminGlobalTopbar">
        <div className="adminGlobalBrand">
          <div className="brand">{t('admin.nav.brand', 'Cartly Admin')}</div>
          <div className="brandMeta">operator console</div>
        </div>
        <nav className="adminPrimaryNav" aria-label="Primary admin navigation">
          {navGroups.map((group) => {
            const active = group.id === currentGroup.id
            const href = group.items[0]?.href ?? '/overview'
            return (
              <Link
                key={group.id}
                href={href}
                className={`adminPrimaryNavLink ${active ? 'active' : ''}`}
                aria-current={active ? 'page' : undefined}
              >
                {group.label}
              </Link>
            )
          })}
        </nav>
        <div className="adminGlobalActions">
          <span className="consoleMetaPill">Operator-first IA</span>
          <LogoutButton compact />
        </div>
      </header>

      <div className="adminMainLayout">
        <aside className="sidebar sidebarSecondary">
          <div className="sidebarOverviewCard">
            <div className="sidebarOverviewLabel">Workspace</div>
            <div className="sidebarOverviewTitle">{currentGroup.label}</div>
            <div className="sidebarOverviewText">{currentGroup.description}</div>
          </div>

          <nav className="groupedNav secondaryNav" aria-label="Secondary admin navigation">
            <section className="navGroup">
              <div className="navGroupLinks">
                {currentGroup.items.map((item) => (
                  <NavLink
                    key={item.href}
                    href={item.href}
                    label={item.label}
                    description={item.description}
                    children={
                      item.href === '/content'
                        ? [...contentSectionNavItems]
                        : item.href === '/explore'
                          ? [...exploreWorkspaceNavItems]
                          : item.href === '/ads'
                            ? [...adsSectionNavItems]
                            : item.href === '/config'
                              ? [...configPaneNavItems]
                              : item.href === '/users'
                                ? [...usersNavItems]
                                : undefined
                    }
                  />
                ))}
              </div>
            </section>
            <div className="navLogoutWrap mobileOnlyLogout">
              <LogoutButton compact />
            </div>
          </nav>
        </aside>
        <main className="content">
          <div className="contentInner">
            <div className="consoleTopbar">
              <div className="consoleTopbarCopy">
                <div className="consoleEyebrow">{currentGroup.label}</div>
                <div className="consoleHeadingRow">
                  <h1 className="consoleTitle">{currentItem.label}</h1>
                  <span className="consoleRoutePill">{currentItem.href}</span>
                </div>
              </div>
              <div className="consoleMetaPills">
                <span className="consoleMetaPill subtle">{currentItem.description}</span>
              </div>
            </div>
            {children}
          </div>
        </main>
      </div>
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
