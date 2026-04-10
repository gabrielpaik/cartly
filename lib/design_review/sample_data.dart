import '../models/app_ad_slot.dart';
import '../models/app_branding.dart';
import '../models/auth_provider_type.dart';
import '../models/recognized_item.dart';
import '../models/saved_cart.dart';
import '../models/user_session.dart';

final reviewBranding = AppBranding(
  logoType: 'text',
  logoText: 'Cartly',
  logoImageUrl: null,
  splashImageUrl: null,
  loginHeroImageUrl: null,
  homeTabLabel: 'Home',
  savedTabLabel: 'Saved',
  myTabLabel: 'My',
  savedPageTitle: 'Saved carts',
  myPageTitle: 'My account',
  homeSubtitle: '지금 카트 총액을 확인해',
  savedSubtitle: '저장한 카트를 다시 봐',
  mySubtitle: '기록을 남기려면 로그인',
  loginPageTitle: '계정 시작',
  loginSubtitle: '저장과 기록을 이어가려면 로그인',
  loginBenefitsTitle: '왜 계정을 만들까',
  loginBenefitsBody: '• 저장한 카트 보기\n• 다음 결제 전에 다시 확인\n• 더 저렴한 대안 추천',
  savedEmptyTitle: '아직 저장된 카트가 없어요',
  savedEmptyBody: 'Home에서 저장하면 여기서 다시 볼 수 있어.',
  recentSavedTitle: '최근 저장 카트',
  recentSavedEmptyBody: '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
  myBenefitsTitle: '계정이 있으면 좋은 점',
  myBenefitsBody: '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
  drawerGuestTitle: '아직 로그인하지 않았어요',
  drawerGuestBody: '저장한 카트와 스캔 기록을 이어가려면 로그인해.',
  saveCompleteTitle: '카트 저장 완료',
  saveCompleteSubtitle: '다음 장보기 전에 다시 볼 수 있어',
);

final reviewAdSlots = <AppAdSlot>[
  const AppAdSlot(
    slotKey: 'save_complete_sheet_1',
    placementType: 'bottom_sheet',
    enabled: true,
    config: AppAdSlotConfig(
      maxHeight: 88,
      screen: 'save_complete',
      position: 'after_summary_before_actions',
      tone: 'benefit_native',
      title: '다음 장보기도 더 가볍게',
      message: '저장한 카트를 기준으로 혜택 상품을 이어서 볼 수 있어요.',
      ctaLabel: '혜택 보기',
      targetUrl: null,
      imageUrl: null,
      campaignId: null,
    ),
  ),
  const AppAdSlot(
    slotKey: 'saved_inline_1',
    placementType: 'inline',
    enabled: true,
    config: AppAdSlotConfig(
      maxHeight: 104,
      screen: 'saved_list',
      position: 'after_first_card',
      tone: 'benefit_native',
      title: '지금 많이 담는 상품',
      message: 'Saved 카트와 같이 보는 추천 배너 슬롯이야.',
      ctaLabel: '자세히',
      targetUrl: null,
      imageUrl: null,
      campaignId: null,
    ),
  ),
  const AppAdSlot(
    slotKey: 'saved_inline_2',
    placementType: 'inline',
    enabled: true,
    config: AppAdSlotConfig(
      maxHeight: 104,
      screen: 'saved_list',
      position: 'after_third_card',
      tone: 'benefit_native',
      title: '같이 담기 좋은 상품',
      message: 'Saved 리스트 중간 보조 프로모션 슬롯이야.',
      ctaLabel: '확인',
      targetUrl: null,
      imageUrl: null,
      campaignId: null,
    ),
  ),
  const AppAdSlot(
    slotKey: 'my_perks_inline_1',
    placementType: 'inline',
    enabled: true,
    config: AppAdSlotConfig(
      maxHeight: 96,
      screen: 'my',
      position: 'below_account_card',
      tone: 'soft_promo',
      title: '멤버 혜택 확인',
      message: 'My 화면용 보조 배너 슬롯이야.',
      ctaLabel: '보기',
      targetUrl: null,
      imageUrl: null,
      campaignId: null,
    ),
  ),
];

final reviewGuestCarts = <SavedCart>[
  SavedCart(
    id: 'cart_review_guest_001',
    title: '주말 장보기',
    createdAt: DateTime.parse('2026-03-23T10:00:00Z').toLocal(),
    items: [
      SavedCartItem(name: '계란 30구', price: 8900, quantity: 1),
      SavedCartItem(name: '닭가슴살', price: 14900, quantity: 2),
      SavedCartItem(name: '베이글', price: 7990, quantity: 1),
    ],
  ),
  SavedCart(
    id: 'cart_review_guest_002',
    title: '간단 재구매',
    createdAt: DateTime.parse('2026-03-18T16:30:00Z').toLocal(),
    items: [
      SavedCartItem(name: '우유', price: 4900, quantity: 2),
      SavedCartItem(name: '시리얼', price: 17000, quantity: 1),
    ],
  ),
  SavedCart(
    id: 'cart_review_guest_003',
    title: '냉장고 채우기',
    createdAt: DateTime.parse('2026-03-12T09:15:00Z').toLocal(),
    items: [
      SavedCartItem(name: '연어 필렛', price: 23900, quantity: 1),
      SavedCartItem(name: '요거트', price: 12990, quantity: 1),
      SavedCartItem(name: '샐러드 믹스', price: 8990, quantity: 1),
    ],
  ),
];

final reviewMemberSession = UserSession(
  id: 'usr_review_member_001',
  provider: AuthProviderType.google,
  displayName: '승대',
  email: 'seungdae@wimc.app',
  isGuest: false,
  signedInAt: DateTime.parse('2026-03-24T06:00:00Z').toLocal(),
  authToken: 'review-member-token',
  sessionExpiresAt: DateTime.parse('2026-03-25T06:00:00Z').toLocal(),
);

final reviewRecognizedItem = RecognizedItem(
  name: '커클랜드 그릭요거트',
  price: 12990,
  sku: 'CARTLY-12990',
  confidence: 0.92,
  source: 'ocr',
  rawText: 'KIRKLAND GREEK YOGURT 12,990',
);
