export type CartItemDto = {
  id: string
  name: string
  price: number
  quantity: number
}

export type CartDto = {
  id: string
  sourceCartId?: string | null
  title: string | null
  savedDate?: string | null
  totalPrice: number
  totalCount: number
  createdAt: string | null
  items: CartItemDto[]
}

export type UserCartDetailPayload = {
  user: {
    id: string
    displayName: string
    guestCode?: string | null
    email: string | null
    provider: string
    status?: string
    isGuest: boolean
    guestKey?: string | null
    mergedIntoUserId?: string | null
    mergedAt?: string | null
    lastDevicePlatform?: string | null
    lastAppVersion?: string | null
    createdAt: string | null
    lastSeenAt: string | null
  }
  summary: {
    totalCarts: number
    totalItems: number
    totalValue: number
    firstSavedAt: string | null
    lastSavedAt: string | null
  }
  carts: CartDto[]
}

export function createUserDetailFallback(userId?: string): UserCartDetailPayload {
  return {
    user: {
      id: userId ?? 'usr_mock',
      displayName: 'Guest shopper',
      email: null,
      provider: 'guest',
      status: 'active',
      isGuest: true,
      guestKey: null,
      mergedIntoUserId: null,
      mergedAt: null,
      lastDevicePlatform: 'ios',
      lastAppVersion: '0.1.0',
      createdAt: '2026-03-23T00:00:00.000Z',
      lastSeenAt: '2026-03-24T00:00:00.000Z',
    },
    summary: {
      totalCarts: 2,
      totalItems: 7,
      totalValue: 90300,
      firstSavedAt: '2026-03-23T00:00:00.000Z',
      lastSavedAt: '2026-03-24T00:00:00.000Z',
    },
    carts: [
      {
        id: 'cart_002',
        sourceCartId: 'cart_001',
        title: '최근 저장본',
        savedDate: '2026-03-24',
        totalPrice: 21900,
        totalCount: 2,
        createdAt: '2026-03-24T00:00:00.000Z',
        items: [
          { id: 'item_003', name: '우유', price: 4900, quantity: 1 },
          { id: 'item_004', name: '시리얼', price: 17000, quantity: 1 },
        ],
      },
    ],
  }
}

export function isLegacyGuestUser(user: UserCartDetailPayload['user']) {
  return user.isGuest && !user.guestKey && (user.status ?? 'active') === 'active'
}
