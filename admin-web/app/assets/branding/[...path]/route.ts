import { NextRequest } from 'next/server'

import { forwardPublicAsset } from '../../../../lib/appPublicProxy'

export async function GET(_request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forwardPublicAsset(`/assets/branding/${path.join('/')}`)
}

export async function HEAD(_request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forwardPublicAsset(`/assets/branding/${path.join('/')}`)
}
