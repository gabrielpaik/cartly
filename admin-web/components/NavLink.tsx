'use client'

import { useEffect, useState } from 'react'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

function ensureLocationChangeEventPatched() {
  if (typeof window === 'undefined') return
  const historyState = window.history as History & {
    __cartlyLocationPatched?: boolean
    __cartlyPushState?: History['pushState']
    __cartlyReplaceState?: History['replaceState']
  }
  if (historyState.__cartlyLocationPatched) return
  historyState.__cartlyPushState = window.history.pushState.bind(window.history)
  historyState.__cartlyReplaceState = window.history.replaceState.bind(window.history)
  window.history.pushState = ((...args) => {
    const result = historyState.__cartlyPushState?.(...args)
    window.dispatchEvent(new Event('cartly:locationchange'))
    return result
  }) as History['pushState']
  window.history.replaceState = ((...args) => {
    const result = historyState.__cartlyReplaceState?.(...args)
    window.dispatchEvent(new Event('cartly:locationchange'))
    return result
  }) as History['replaceState']
  historyState.__cartlyLocationPatched = true
}

type NavChild = {
  href: string
  label: string
}

function pathMatches(pathname: string, href: string) {
  return pathname === href || pathname.startsWith(`${href}/`)
}

export default function NavLink({
  href,
  label,
  description,
  children,
}: {
  href: string
  label: string
  description?: string
  children?: NavChild[]
}) {
  const pathname = usePathname() ?? ''
  const normalized = pathname === '/' ? '/overview' : pathname
  const active = pathMatches(normalized, href)
  const [currentPath, setCurrentPath] = useState(normalized)
  const [currentSearch, setCurrentSearch] = useState('')

  useEffect(() => {
    ensureLocationChangeEventPatched()
    const syncLocation = () => {
      setCurrentPath(window.location.pathname)
      setCurrentSearch(window.location.search)
    }
    syncLocation()
    window.addEventListener('popstate', syncLocation)
    window.addEventListener('cartly:locationchange', syncLocation as EventListener)
    return () => {
      window.removeEventListener('popstate', syncLocation)
      window.removeEventListener('cartly:locationchange', syncLocation as EventListener)
    }
  }, [normalized])

  return (
    <div className="navLinkBlock">
      <Link href={href} className={`navLink ${active ? 'active' : ''}`} aria-current={active ? 'page' : undefined}>
        <span className="navLinkLabel">{label}</span>
        {description ? <span className="navLinkMeta">{description}</span> : null}
      </Link>
      {active && children && children.length > 0 ? (
        <div className="navSubLinks">
          {children.map((child) => {
            const childActive = (() => {
              try {
                const target = new URL(child.href, 'http://localhost')
                return target.pathname === currentPath && target.search === currentSearch
              } catch {
                return false
              }
            })()
            return (
              <Link
                key={child.href}
                href={child.href}
                className={`navSubLink ${childActive ? 'active' : ''}`}
                aria-current={childActive ? 'page' : undefined}
              >
                {child.label}
              </Link>
            )
          })}
        </div>
      ) : null}
    </div>
  )
}
