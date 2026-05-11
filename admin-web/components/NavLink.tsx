'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

export default function NavLink({ href, label }: { href: string; label: string }) {
  const pathname = usePathname() ?? ''
  const active = pathname === href

  return (
    <Link href={href} className={`navLink ${active ? 'active' : ''}`}>
      {label}
    </Link>
  )
}
