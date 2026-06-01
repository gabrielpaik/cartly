import type { Metadata } from 'next'
import type { ReactNode } from 'react'

import './globals.css'
import AdminChrome from '../components/AdminChrome'

export const metadata: Metadata = {
  title: '카트리 운영센터',
  description: '카트리 운영센터',
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <AdminChrome>{children}</AdminChrome>
      </body>
    </html>
  )
}
