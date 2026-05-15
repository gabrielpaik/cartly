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

export type PushDeviceDto = {
  id: string
  installId: string
  platform: string | null
  provider: string | null
  status: string | null
  notificationsEnabled: boolean
  hasPushToken: boolean
  isReady: boolean
  appVersion: string | null
  locale: string | null
  lastRegisteredAt: string | null
  lastSeenAt: string | null
  createdAt: string | null
}

export type ScanRecentDto = {
  id: string
  status: string
  createdAt: string | null
  finishedAt: string | null
  errorCode?: string | null
  errorMessage?: string | null
}

export type ActivityTimelineDto = {
  kind: string
  at: string | null
  title: string
  note: string | null
}

export type UserRegionProfileDto = {
  regionKey: string
  regionLevel: string
  city?: string | null
  district?: string | null
  neighborhood?: string | null
  label?: string | null
  visitCount: number
  activeDayCount: number
  weekdayVisitCount: number
  weekendVisitCount: number
  firstSeenAt: string | null
  lastSeenAt: string | null
  lastSource?: string | null
}

export type UserRegionEventDto = {
  id: string
  source?: string | null
  regionKey: string
  city?: string | null
  district?: string | null
  neighborhood?: string | null
  label?: string | null
  capturedAt: string | null
  createdAt: string | null
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
    lastRegionLabel?: string | null
    lastRegionCapturedAt?: string | null
  }
  summary: {
    totalCarts: number
    totalItems: number
    totalValue: number
    firstSavedAt: string | null
    lastSavedAt: string | null
    totalSessions: number
    totalScans: number
    pushDeviceCount: number
    readyPushDeviceCount: number
  }
  lifecycle: {
    lifecycleStage: string
    lifecycleLabel: string
    reachabilityState: string
    reachabilityLabel: string
    operatorAction: string
    operatorActionLabel: string
    daysSinceSeen?: number | null
    daysSinceCreated?: number | null
    lastActivityType?: string | null
    lastActivityAt?: string | null
  }
  push: {
    reachabilityState: string
    reachabilityLabel: string
    deviceCount: number
    readyDeviceCount: number
    devices: PushDeviceDto[]
  }
  scan: {
    totalScans: number
    feedbackCount: number
    acceptedFeedbackCount: number
    failureCount: number
    lastScanAt: string | null
    latestFailure: {
      at: string | null
      stage?: string | null
      errorCode?: string | null
      errorMessage?: string | null
    }
    statusSummary: Array<{ status: string; count: number }>
    recent: ScanRecentDto[]
  }
  activity: {
    lastActivityType?: string | null
    lastActivityAt?: string | null
    timeline: ActivityTimelineDto[]
    eventSummary: Array<{ eventName: string; screenName?: string | null; count: number }>
  }
  regions: {
    currentLabel?: string | null
    currentCapturedAt?: string | null
    profileCount: number
    profiles: UserRegionProfileDto[]
    recentEvents: UserRegionEventDto[]
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
      lastRegionLabel: '서울특별시, 문래동',
      lastRegionCapturedAt: '2026-03-24T00:00:00.000Z',
    },
    summary: {
      totalCarts: 2,
      totalItems: 7,
      totalValue: 90300,
      firstSavedAt: '2026-03-23T00:00:00.000Z',
      lastSavedAt: '2026-03-24T00:00:00.000Z',
      totalSessions: 5,
      totalScans: 4,
      pushDeviceCount: 1,
      readyPushDeviceCount: 0,
    },
    lifecycle: {
      lifecycleStage: 'guest_active',
      lifecycleLabel: 'active guest',
      reachabilityState: 'push_blocked',
      reachabilityLabel: 'device exists, push blocked',
      operatorAction: 'recover_push_optin',
      operatorActionLabel: 'recover push opt-in',
      daysSinceSeen: 1,
      daysSinceCreated: 2,
      lastActivityType: 'seen',
      lastActivityAt: '2026-03-24T00:00:00.000Z',
    },
    push: {
      reachabilityState: 'push_blocked',
      reachabilityLabel: 'device exists, push blocked',
      deviceCount: 1,
      readyDeviceCount: 0,
      devices: [
        {
          id: 'device_001',
          installId: 'install_mock_001',
          platform: 'ios',
          provider: 'apns',
          status: 'active',
          notificationsEnabled: false,
          hasPushToken: true,
          isReady: false,
          appVersion: '1.0.3',
          locale: 'ko-KR',
          lastRegisteredAt: '2026-03-23T00:00:00.000Z',
          lastSeenAt: '2026-03-24T00:00:00.000Z',
          createdAt: '2026-03-23T00:00:00.000Z',
        },
      ],
    },
    scan: {
      totalScans: 4,
      feedbackCount: 1,
      acceptedFeedbackCount: 1,
      failureCount: 1,
      lastScanAt: '2026-03-24T00:00:00.000Z',
      latestFailure: {
        at: '2026-03-23T08:00:00.000Z',
        stage: 'processing',
        errorCode: 'LOW_CONFIDENCE',
        errorMessage: 'confidence low',
      },
      statusSummary: [
        { status: 'done', count: 3 },
        { status: 'failed', count: 1 },
      ],
      recent: [
        {
          id: 'scan_001',
          status: 'done',
          createdAt: '2026-03-24T00:00:00.000Z',
          finishedAt: '2026-03-24T00:03:00.000Z',
        },
      ],
    },
    activity: {
      lastActivityType: 'seen',
      lastActivityAt: '2026-03-24T00:00:00.000Z',
      timeline: [
        {
          kind: 'cart',
          at: '2026-03-24T00:00:00.000Z',
          title: 'Saved cart 최근 저장본',
          note: '2 items · ₩21,900',
        },
        {
          kind: 'event',
          at: '2026-03-23T12:00:00.000Z',
          title: 'help_opened',
          note: 'help screen',
        },
      ],
      eventSummary: [
        { eventName: 'help_opened', screenName: 'help', count: 2 },
      ],
    },
    regions: {
      currentLabel: '문래동, 서울특별시',
      currentCapturedAt: '2026-03-24T00:00:00.000Z',
      profileCount: 3,
      profiles: [
        {
          regionKey: 'neighborhood:서울특별시/영등포구/문래동',
          regionLevel: 'neighborhood',
          label: '문래동, 영등포구, 서울특별시',
          visitCount: 8,
          activeDayCount: 5,
          weekdayVisitCount: 6,
          weekendVisitCount: 2,
          firstSeenAt: '2026-03-20T00:00:00.000Z',
          lastSeenAt: '2026-03-24T00:00:00.000Z',
          lastSource: 'app_launch',
        },
      ],
      recentEvents: [
        {
          id: 'region_evt_1',
          source: 'scan_start',
          regionKey: 'neighborhood:서울특별시/영등포구/문래동',
          label: '문래동, 영등포구, 서울특별시',
          capturedAt: '2026-03-24T00:00:00.000Z',
          createdAt: '2026-03-24T00:00:00.000Z',
        },
      ],
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
