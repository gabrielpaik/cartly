export const mockSummary = {
  dau: 128,
  wau: 602,
  mau: 1820,
  activeUsers: 941,
  newUsers: 214,
  guestToMemberConversion: 0.124,
  totalScans: 4821,
  scanSuccessRate: 0.71,
  cartSaveRate: 0.43,
  adImpressions: 1320,
  adClicks: 48,
  adCtr: 0.036,
}

export const mockUsers = [
  {
    id: 'usr_001',
    displayName: 'Guest shopper',
    email: null,
    provider: 'guest',
    isGuest: true,
    createdAt: new Date().toISOString(),
    lastSeenAt: new Date().toISOString(),
  },
  {
    id: 'usr_002',
    displayName: 'Seungdae',
    email: 'ceo@wimc.app',
    provider: 'google',
    isGuest: false,
    createdAt: new Date().toISOString(),
    lastSeenAt: new Date().toISOString(),
  },
]

export const mockScanJobs = [
  {
    id: 'job_001',
    userId: 'usr_002',
    status: 'done',
    errorCode: null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'job_002',
    userId: null,
    status: 'failed',
    errorCode: 'OCR_NOT_CONFIDENT',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
]

export const mockSlots = [
  {
    id: 'slot_001',
    slotKey: 'save_complete_sheet_1',
    placementType: 'bottom_sheet',
    status: 'active',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'slot_002',
    slotKey: 'saved_inline_1',
    placementType: 'inline',
    status: 'active',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'slot_003',
    slotKey: 'my_perks_inline_1',
    placementType: 'inline',
    status: 'active',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
]

export const mockBranding = {
  logoType: 'text',
  logoText: "What's in my cart",
  logoImageUrl: null,
  homeSubtitle: '지금 카트 총액을 확인해',
  savedSubtitle: '저장한 카트를 다시 봐',
  mySubtitle: '기록을 남기려면 로그인',
  loginSubtitle: '저장과 기록을 이어가려면 로그인',
  saveCompleteTitle: '카트 저장 완료',
  saveCompleteSubtitle: '다음 장보기 전에 다시 볼 수 있어',
}

export const mockConfig = {
  remoteScan: true,
  adsEnabled: true,
  storageRoot: '/Volumes/AI/WIMC',
  apiBase: 'http://127.0.0.1:8011',
  branding: mockBranding,
}
