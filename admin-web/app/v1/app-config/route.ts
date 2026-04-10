import { NextRequest } from 'next/server'

import { forwardPublicRequest } from '../../../lib/appPublicProxy'

export async function GET(request: NextRequest) {
  return forwardPublicRequest(request, '/v1/app-config')
}
