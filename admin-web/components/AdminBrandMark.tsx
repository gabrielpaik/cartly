'use client'

import { useEffect, useState } from 'react'

import { fetchJsonSafe } from '../lib/api'
import { mockBranding } from '../lib/mock'

type BrandingResponse = {
  ok: boolean
  data: {
    logoType?: string
    logoText?: string
    logoImageUrl?: string | null
  }
}

export default function AdminBrandMark({
  variant = 'header',
  live = true,
}: {
  variant?: 'header' | 'login'
  live?: boolean
}) {
  const [branding, setBranding] = useState(mockBranding)

  useEffect(() => {
    if (!live) return
    let cancelled = false
    void (async () => {
      try {
        const response = await fetchJsonSafe<BrandingResponse>('/admin/branding', {
          ok: true,
          data: mockBranding,
        })
        if (!cancelled && response.data?.data) {
          setBranding({
            ...mockBranding,
            ...response.data.data,
          })
        }
      } catch {
        // keep fallback branding quietly
      }
    })()
    return () => {
      cancelled = true
    }
  }, [live])

  const logoText = (branding.logoText || mockBranding.logoText || 'Cartly').trim()
  const logoImageUrl = (branding.logoImageUrl || mockBranding.logoImageUrl || '').trim()
  const useImage = (branding.logoType || mockBranding.logoType) === 'image' && logoImageUrl.length > 0
  const className = `adminBrandMark ${variant === 'login' ? 'login' : 'header'}`

  if (useImage) {
    return (
      <div className={className} aria-label={logoText}>
        <img className="adminBrandLogo" src={logoImageUrl} alt={logoText} />
      </div>
    )
  }

  return (
    <div className={className} aria-label={logoText}>
      <span className="adminBrandText">{logoText}</span>
    </div>
  )
}
