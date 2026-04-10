import { NextRequest } from 'next/server'

import { forwardPublicRequest } from '../../../../lib/appPublicProxy'

async function forward(request: NextRequest, path: string[]) {
  return forwardPublicRequest(request, `/v1/ads/${path.join('/')}`)
}

export async function GET(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params
  return forward(request, path)
}
