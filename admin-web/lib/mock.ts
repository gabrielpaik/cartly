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

export const mockConfig = {
  remoteScan: true,
  adsEnabled: true,
  storageRoot: '/Volumes/AI/WIMC',
  apiBase: 'http://127.0.0.1:8011',
}
