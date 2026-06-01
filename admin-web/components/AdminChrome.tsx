'use client'

import type { ReactNode } from 'react'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

import AdminCopyProvider, { useAdminCopy } from './AdminCopyProvider'
import AdminBrandMark from './AdminBrandMark'
import LogoutButton from './LogoutButton'
import NavLink from './NavLink'

const contentSectionNavItems = [
  { href: '/content?section=brand', label: '브랜드' },
  { href: '/content?section=app', label: '앱 문구' },
  { href: '/content?section=account', label: '계정 문구' },
  { href: '/content?section=public', label: '웹 문구' },
] as const

const exploreWorkspaceNavItems = [
  { href: '/explore?ws=layout', label: '노출구성' },
  { href: '/explore?ws=recommendations', label: '추천상품' },
  { href: '/explore?ws=rules', label: '노출기준' },
  { href: '/explore?ws=copy', label: '문구' },
  { href: '/explore?ws=store', label: '매장혜택' },
] as const

const configPaneNavItems = [
  { href: '/config?pane=overview', label: '전체 상태' },
  { href: '/config?pane=smoke', label: '운영 점검' },
  { href: '/config?pane=runtime', label: '저장소 / 기동' },
  { href: '/config?pane=my-page', label: '마이페이지' },
  { href: '/config?pane=coupang', label: '제휴 연동' },
] as const

const adsSectionNavItems = [
  { href: '/ads/status', label: '현황' },
  { href: '/ads/setup', label: '설정' },
  { href: '/ads/efficiency', label: '성과' },
] as const

const usersNavItems = [
  { href: '/users', label: '고객' },
  { href: '/users/legacy-cleanup', label: '정리' },
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
    label: '대시보드',
    description: '운영 현황',
    items: [
      { href: '/overview', label: '운영현황', description: '현황과 빠른 실행' },
    ],
  },
  {
    id: 'experience',
    label: '앱 운영',
    description: '브랜드와 탐색',
    items: [
      { href: '/content', label: '브랜드·문구', description: '앱 문구와 화면' },
      { href: '/explore', label: '탐색 운영', description: '추천상품과 노출' },
    ],
  },
  {
    id: 'growth',
    label: '성장 운영',
    description: '알림과 광고',
    items: [
      { href: '/push', label: '알림 운영', description: '발송과 대상' },
      { href: '/ads', label: '광고 운영', description: '광고 위치와 소재' },
    ],
  },
  {
    id: 'operations',
    label: '고객 운영',
    description: '고객과 기록',
    items: [
      { href: '/users', label: '고객', description: '회원과 상태' },
      { href: '/carts', label: '카트', description: '카트와 영수증' },
      { href: '/scan-ops', label: '스캔 운영', description: '스캔 상태' },
    ],
  },
  {
    id: 'system',
    label: '기본 설정',
    description: '연동과 점검',
    items: [
      { href: '/config', label: '기본 설정', description: '실노출과 연동' },
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
        <Link href="/overview" className="adminGlobalBrand" aria-label="운영센터">
          <AdminBrandMark variant="header" />
          <div className="brandMeta">운영센터</div>
        </Link>
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
          <span className="consoleMetaPill">운영 중심</span>
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
