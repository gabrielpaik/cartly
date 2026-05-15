import 'package:flutter/material.dart';

import 'app_support.dart';
import 'models/app_branding.dart';
import 'models/auth_provider_type.dart';
import 'models/recognized_item.dart';
import 'models/recognized_item_candidate.dart';
import 'models/saved_cart.dart';
import 'models/scan_job.dart';
import 'models/user_session.dart';
import 'pages/login_page.dart';
import 'pages/my_page.dart';
import 'pages/shopping_help_page.dart';
import 'pages/home_tab_view.dart';
import 'preview/preview_bridge.dart';
import 'preview/preview_state.dart';
import 'services/app_config_store.dart';
import 'services/auth_store.dart';
import 'services/cart_store.dart';
import 'services/scan_repository.dart';
import 'widgets/total_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) {
    return Material(
      color: const Color(0xFFFFF1F2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Preview error\n\n${details.exceptionAsString()}\n\n${details.stack ?? ''}',
          style: const TextStyle(
            color: Color(0xFF9F1239),
            fontSize: 12,
            height: 1.45,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  };
  runApp(const CartlyPreviewApp());
}

class CartlyPreviewApp extends StatefulWidget {
  const CartlyPreviewApp({super.key});

  @override
  State<CartlyPreviewApp> createState() => _CartlyPreviewAppState();
}

class _CartlyPreviewAppState extends State<CartlyPreviewApp> {
  String _previewScreen = Uri.base.queryParameters['screen'] ?? 'home';
  bool _memberMode = false;
  String _explorePreviewState = 'activeShopping';

  @override
  void initState() {
    super.initState();
    _applyPreviewPayload(_defaultContentSettings());
    listenPreviewMessages(_applyPreviewPayload);
    notifyPreviewReady();
  }

  void _applyPreviewPayload(Map<String, dynamic> payload) {
    AppConfigStore.instance.branding.value = AppBranding.fromJson(
      _projectPreviewBranding(payload),
    );
    AppConfigStore.instance.copy.value = _buildPreviewCopy(payload);
    AppConfigStore.instance.explore.value = _buildPreviewExploreConfig(payload);
    AppConfigStore.instance.adSlots.value = const [];
    _previewScreen = (payload['__previewScreen'] as String?) ?? _previewScreen;
    _explorePreviewState = _normalizePreviewExploreState(
      payload['__previewExploreState'] as String?,
      _explorePreviewState,
    );
    _applySessionState(
      memberMode: (payload['__previewMemberMode'] as bool?) ?? _memberMode,
    );
    if (mounted) setState(() {});
  }

  void _applySessionState({required bool memberMode}) {
    _memberMode = memberMode;
    final session = memberMode ? _memberSession() : _guestSession();
    final carts = _resolvePreviewCarts(
      memberMode: memberMode,
      explorePreviewState: _explorePreviewState,
    );
    PreviewState.session.value = session;
    PreviewState.carts.value = carts;
    AuthStore.instance.session.value = session;
    CartStore.instance.carts.value = carts;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE31837)),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Center(
          child: Container(
            width: 430,
            height: 860,
            margin: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildPreviewBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<CartItem> get _previewExploreItems =>
      _explorePreviewState == 'activeShopping' ? _previewCartItems : const [];

  List<RecentScanEntry> get _previewExploreRecentScans =>
      _explorePreviewState == 'activeShopping' ? _previewRecentScans : const [];

  Widget _buildPreviewBody() {
    switch (_previewScreen) {
      case 'home':
        return Scaffold(
          backgroundColor: Colors.white,
          body: HomeTabView(
            cameras: const [],
            scanRepository: _PreviewScanRepository(),
            items: _previewCartItems,
            recentScans: _previewRecentScans,
            onRecognized: (_) {},
            onAdd: (_) async => true,
            onDismissRecognized: (_) {},
            onAddRecentScan: (_) async => true,
            onDismissRecentScan: (_) {},
            onRemove: (_) {},
            onChangeCurrentCartItem: (_) {},
            onGoExplore: () {
              setState(() {
                _previewScreen = 'help';
              });
            },
          ),
          bottomNavigationBar: TotalBar(
            totalPrice: _previewCartItems.fold(
              0,
              (sum, item) => sum + item.totalPrice,
            ),
            onSave: () async {},
            isSaving: false,
          ),
        );
      case 'help':
        return ShoppingHelpPage(
          items: _previewExploreItems,
          recentScans: _previewExploreRecentScans,
          onGoHome: () {},
          onGoSaved: () {},
        );
      case 'my':
        return const Scaffold(backgroundColor: Colors.white, body: MyPage());
      case 'login':
        return const LoginPage(skipInitialConfigRefresh: true);
      default:
        return const SizedBox.shrink();
    }
  }
}

const _previewBrandingKeys = <String>{
  'logoType',
  'logoText',
  'logoImageUrl',
  'splashImageUrl',
  'loginHeroImageUrl',
  'homeTabLabel',
  'helpTabLabel',
  'myTabLabel',
};

Map<String, dynamic> _projectPreviewBranding(Map<String, dynamic> payload) => {
  for (final entry in payload.entries)
    if (_previewBrandingKeys.contains(entry.key)) entry.key: entry.value,
};

Map<String, dynamic> _defaultContentSettings() => {
  'logoType': 'text',
  'logoText': 'Cartly',
  'logoImageUrl': null,
  'splashImageUrl': null,
  'loginHeroImageUrl': null,
  'homePageTitle': 'Cartly',
  'homeSubtitle': '결제 전에 더 똑똑하게 비교해보세요',
  'helpPageTitle': 'Explore',
  'helpSubtitle': '지금 필요한 비교만 모아 보여드릴게요',
  'homeTabLabel': '홈',
  'helpTabLabel': '탐색',
  'myTabLabel': '마이',
  'savedPageTitle': '지난 카트',
  'savedSubtitle': '저장한 장보기 기록을 다시 확인해보세요',
  'savedEmptyTitle': '아직 저장된 카트가 없어요',
  'savedEmptyBody': '현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
  'recentSavedTitle': '최근 저장한 카트',
  'recentSavedEmptyBody': '아직 저장한 카트가 없어요. 카트를 저장하면 다음 장보기 전에 다시 꺼내보실 수 있어요.',
  'homeRecentScanTitle': '최근 스캔',
  'homeRecentScanSubtitle': '방금 읽은 상품이에요',
  'homeCurrentCartTitle': '현재 카트',
  'homeCurrentCartSubtitle': '지금 담은 상품과 합계를 확인해보세요',
  'homeCurrentCartEmpty': '아직 담은 상품이 없어요',
  'homeAddToCurrentCartDone': '현재 카트에 담았어요',
  'homeAddToCurrentCartButton': '현재 카트에 담기',
  'homeSaveCartButton': '카트 저장',
  'homeCartTotalLabel': '현재 카트 합계',
  'homeContinueScanAction': '계속 스캔하기',
  'homeExploreEntryTitle': '탐색에서 다음 판단 이어가기',
  'homeExploreEntryBody': '비교 후보와 대안을 한 번에 보고 결정해보세요',
  'myGuestModeLabel': '게스트로 사용 중이에요',
  'drawerGuestTitle': '게스트로 사용 중이에요',
  'drawerGuestBody': '저장한 카트와 스캔 기록을 이어서 보시려면 로그인해 주세요.',
  'myBenefitsTitle': '계정을 연결하면 이런 점이 좋아요',
  'myBenefitsBody':
      '• 지난 카트를 계속 보실 수 있어요\n• 최근 스캔 결과를 이어서 확인하실 수 있어요\n• 다음 장보기 전에 다시 비교하실 수 있어요',
  'loginPageTitle': '로그인',
  'loginBenefitsTitle': '로그인하면 더 편해져요',
  'loginBenefitsBody': '저장한 카트와 스캔 기록을 이어서 관리하실 수 있어요.',
  'loginModeLogin': '로그인',
  'loginModeSignup': '회원가입',
  'loginModeReset': '비밀번호 찾기',
  'loginEmailLocalFieldLabel': '이메일 아이디',
  'loginEmailDomainFieldLabel': '도메인',
  'loginEmailCustomDomainOption': '직접입력',
  'loginEmailCustomDomainFieldLabel': '직접 입력 도메인',
  'loginPasswordFieldLabel': '비밀번호',
  'loginPasswordConfirmFieldLabel': '비밀번호 확인',
  'loginCodeFieldLabel': '인증 코드',
  'loginForgotPasswordAction': '비밀번호를 잊으셨나요?',
  'loginSendCode': '코드 전송',
  'loginResendCode': '재전송',
  'loginSubmitting': '처리 중입니다...',
  'loginLoginSubmit': '로그인',
  'loginSignupSubmit': '회원가입 완료',
  'loginContinueAsGuest': '게스트로 계속하기',
  'saveCompleteTitle': '카트를 저장했어요',
  'saveCompleteSubtitle': '다음 장보기 때 다시 꺼내보실 수 있어요',
  'saveCompleteViewSavedAction': '지난 카트 보기',
};

Map<String, dynamic> _defaultExploreConfig() => {
  'enabledSections':
      'heroSummary,decisionInbox,revisitItems,repeatCandidates,editorialPicks,offerSlots,savedContext,storeContextPromo',
  'sectionOrder':
      'heroSummary,decisionInbox,revisitItems,repeatCandidates,editorialPicks,offerSlots,savedContext,storeContextPromo',
  'stateMode': 'auto',
  'activeShoppingSectionOrder':
      'offerSlots,heroSummary,decisionInbox,revisitItems',
  'postSaveSectionOrder':
      'savedContext,decisionInbox,repeatCandidates,editorialPicks,offerSlots',
  'idlePlanningSectionOrder':
      'savedContext,repeatCandidates,editorialPicks,offerSlots',
  'storeContextSectionOrder':
      'storeContextPromo,savedContext,editorialPicks,repeatCandidates,offerSlots',
  'stateRules': {
    'activeShopping': {
      'revisitRecentScanLimit': 3,
      'revisitCartItemLimit': 3,
      'revisitMaxItems': 4,
      'repeatMinCount': 2,
      'repeatMaxItems': 2,
      'offerMaxSlots': 3,
      'storeContextMaxPromos': 0,
    },
    'postSave': {
      'revisitRecentScanLimit': 2,
      'revisitCartItemLimit': 2,
      'revisitMaxItems': 3,
      'repeatMinCount': 2,
      'repeatMaxItems': 4,
      'offerMaxSlots': 3,
      'storeContextMaxPromos': 1,
    },
    'idlePlanning': {
      'revisitRecentScanLimit': 0,
      'revisitCartItemLimit': 0,
      'revisitMaxItems': 0,
      'repeatMinCount': 2,
      'repeatMaxItems': 4,
      'offerMaxSlots': 2,
      'storeContextMaxPromos': 0,
    },
    'storeContext': {
      'revisitRecentScanLimit': 0,
      'revisitCartItemLimit': 0,
      'revisitMaxItems': 0,
      'repeatMinCount': 2,
      'repeatMaxItems': 3,
      'offerMaxSlots': 2,
      'storeContextMaxPromos': 3,
    },
  },
  'statePromoPolicies': {
    'activeShopping': {
      'allowSponsoredPromos': false,
      'maxSponsoredPromos': 0,
      'organicFirst': true,
    },
    'postSave': {
      'allowSponsoredPromos': true,
      'maxSponsoredPromos': 1,
      'organicFirst': true,
    },
    'idlePlanning': {
      'allowSponsoredPromos': true,
      'maxSponsoredPromos': 1,
      'organicFirst': true,
    },
    'storeContext': {
      'allowSponsoredPromos': true,
      'maxSponsoredPromos': 2,
      'organicFirst': false,
    },
  },
  'decisionCopy': {
    'recentScanPendingReasonLabel': '아직 담기 전이에요',
    'recentScanPendingBody': '방금 스캔했지만 아직 카트에 담지 않았어요. 지금 확인해 두시면 놓치지 않아요.',
    'recentScanInCartReasonLabel': '담은 뒤 한 번 더 보기',
    'recentScanInCartBody': '이미 카트에 담았어요. 결제 전에 다른 선택지가 있는지만 가볍게 확인해보세요.',
    'currentCartHighImpactReasonLabel': '합계 영향이 커요',
    'currentCartHighImpactBody':
        '수량이나 가격 영향이 큰 상품이에요. 비슷한 대안과 비교하면 체감 차이가 날 수 있어요.',
    'currentCartDefaultReasonLabel': '결제 전에 확인해보세요',
    'currentCartDefaultBody': '지금 카트에 담아둔 상품이에요. 결제 전에 한 번만 더 비교해보세요.',
    'offerReasonLabelActiveShopping': '지금 비교해보세요',
    'offerReasonLabelPostSave': '저장한 뒤 다시 보기',
    'offerReasonLabelIdlePlanning': '다음 장보기 준비',
    'offerReasonLabelStoreContext': '지금 매장 할인 보기',
    'offerBody': '같은 용도의 다른 선택지를 바로 비교하실 수 있어요. 가격이나 구성만 가볍게 확인해보세요.',
  },
  'stateDecisionPriorities': {
    'activeShopping': {
      'offerPendingReview': 300,
      'offerCurrentCart': 280,
      'offerRepeatPurchase': 180,
      'currentCartHighImpact': 240,
      'recentScanPending': 220,
      'recentScanInCart': 180,
      'currentCartDefault': 160,
    },
    'postSave': {
      'offerPendingReview': 220,
      'offerCurrentCart': 250,
      'offerRepeatPurchase': 280,
      'recentScanInCart': 240,
      'currentCartDefault': 210,
      'currentCartHighImpact': 180,
      'recentScanPending': 160,
    },
    'idlePlanning': {
      'offerPendingReview': 150,
      'offerCurrentCart': 140,
      'offerRepeatPurchase': 220,
      'recentScanPending': 210,
      'currentCartDefault': 180,
      'recentScanInCart': 150,
      'currentCartHighImpact': 140,
    },
    'storeContext': {
      'offerPendingReview': 300,
      'offerCurrentCart': 320,
      'offerRepeatPurchase': 200,
      'currentCartHighImpact': 230,
      'recentScanInCart': 210,
      'currentCartDefault': 180,
      'recentScanPending': 150,
    },
  },
  'stateDecisionMaxCounts': {
    'activeShopping': {
      'offerPendingReview': 1,
      'offerCurrentCart': 1,
      'offerRepeatPurchase': 1,
      'recentScanPending': 1,
      'recentScanInCart': 1,
      'currentCartHighImpact': 1,
      'currentCartDefault': 1,
    },
    'postSave': {
      'offerPendingReview': 1,
      'offerCurrentCart': 1,
      'offerRepeatPurchase': 2,
      'recentScanPending': 1,
      'recentScanInCart': 2,
      'currentCartHighImpact': 1,
      'currentCartDefault': 2,
    },
    'idlePlanning': {
      'offerPendingReview': 1,
      'offerCurrentCart': 1,
      'offerRepeatPurchase': 2,
      'recentScanPending': 2,
      'recentScanInCart': 1,
      'currentCartHighImpact': 1,
      'currentCartDefault': 1,
    },
    'storeContext': {
      'offerPendingReview': 1,
      'offerCurrentCart': 2,
      'offerRepeatPurchase': 1,
      'recentScanPending': 1,
      'recentScanInCart': 1,
      'currentCartHighImpact': 1,
      'currentCartDefault': 1,
    },
  },
  'revisitRecentScanLimit': 3,
  'revisitCartItemLimit': 3,
  'revisitMaxItems': 4,
  'repeatMinCount': 2,
  'repeatMaxItems': 4,
  'offerMaxSlots': 3,
  'editorialRecommendationsEnabled': true,
  'editorialRecommendationsTitle': '추천 제품',
  'editorialRecommendationsSubtitle': '지금 카트에 많이 담는 TOP5',
  'editorialRecommendationsCount': 5,
  'editorialRecommendationsPoolRaw': [
    '삼다수 2L 12개 | 12900 | https://placehold.co/160x160/png?text=Water | https://link.coupang.com/example-water',
    '비비고 왕교자 | 8990 | https://placehold.co/160x160/png?text=Dumpling | https://link.coupang.com/example-dumpling',
    '켈로그 콘푸로스트 | 7480 | https://placehold.co/160x160/png?text=Cereal | https://link.coupang.com/example-cereal',
    '서울우유 1L 2입 | 5980 | https://placehold.co/160x160/png?text=Milk | https://link.coupang.com/example-milk',
    '코카콜라 제로 24캔 | 18900 | https://placehold.co/160x160/png?text=Cola | https://link.coupang.com/example-cola',
    '동원 참치 8캔 | 13980 | https://placehold.co/160x160/png?text=Tuna | https://link.coupang.com/example-tuna',
  ].join('\n'),
  'editorialRecommendationsDisclaimer':
      '이 섹션에는 제휴 링크가 포함될 수 있으며, 이에 따라 일정 수수료를 제공받을 수 있어요.',
  'storeContextEnabled': false,
  'storeContextStoreName': '이마트 양재점',
  'storeContextPromoTitle': '지금 이 마트 세일',
  'storeContextPromoBody': '자주 사는 상품군과 겹치는 할인 행사부터 먼저 보여줘요.',
  'storeContextPromoCtaLabel': '행사 보기',
  'storeContextPromoSeedLabels': '유제품 세일,음료 행사,오늘의 마트 추천',
  'storeContextPromoSourceType': 'storeSale',
  'storeContextPromoSponsored': false,
  'storeContextPromoSponsorLabel': '',
  'storeContextPromoPriorityStart': 100,
  'storeContextMaxPromos': 3,
};

Map<String, dynamic> _buildPreviewExploreConfig(Map<String, dynamic> form) {
  final base = _defaultExploreConfig();
  final raw = form['__previewExploreConfig'];
  if (raw is Map) {
    base.addAll(Map<String, dynamic>.from(raw));
  }
  final previewState = form['__previewExploreState'];
  if (previewState is String && previewState.trim().isNotEmpty) {
    base['__previewState'] = _normalizePreviewExploreState(
      previewState,
      'activeShopping',
    );
  }
  return base;
}

Map<String, dynamic> _buildPreviewCopy(Map<String, dynamic> form) {
  String text(String key, String fallback) {
    final value = form[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  return {
    'home': {
      'pageTitle': text('homePageTitle', 'Cartly'),
      'subtitle': text('homeSubtitle', '결제 전에 더 똑똑하게 비교해보세요'),
      'tabLabel': text('homeTabLabel', 'Home'),
      'recentScanTitle': text('homeRecentScanTitle', '스캔 보관함'),
      'recentScanSubtitle': text(
        'homeRecentScanSubtitle',
        '검토 대기 결과를 한 번에 정리해',
      ),
      'addSectionTitle': text('homeAddSectionTitle', '새 상품 추가'),
      'addSectionSubtitle': text('homeAddSectionSubtitle', '스캔하거나 바로 담기'),
      'currentCartTitle': text('homeCurrentCartTitle', '현재 카트'),
      'currentCartSubtitle': text(
        'homeCurrentCartSubtitle',
        '지금 담은 상품과 합계를 확인해보세요',
      ),
      'currentCartEmpty': text('homeCurrentCartEmpty', '아직 담은 상품이 없어요'),
      'addToCurrentCartDone': text('homeAddToCurrentCartDone', '현재 카트에 담았어요'),
      'addToCurrentCartButton': text('homeAddToCurrentCartButton', '현재 카트에 담기'),
      'saveCartButton': text('homeSaveCartButton', '카트 저장'),
      'cartTotalLabel': text('homeCartTotalLabel', '현재 카트 합계'),
      'continueScanAction': text('homeContinueScanAction', '계속 스캔하기'),
      'recentSavedAction': text('homeRecentSavedAction', '지난 카트 보기'),
      'exploreEntryTitle': text('homeExploreEntryTitle', '탐색에서 다음 판단 이어가기'),
      'exploreEntryBody': text(
        'homeExploreEntryBody',
        '비교 후보와 대안을 한 번에 보고 결정해보세요',
      ),
    },
    'help': {
      'pageTitle': text('helpPageTitle', 'Explore'),
      'subtitle': text('helpSubtitle', '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요'),
    },
    'saved': {
      'pageTitle': text('savedPageTitle', '저장한 카트'),
      'subtitle': text('savedSubtitle', '다음 쇼핑 전에 다시 꺼내 비교할 수 있어요.'),
      'recentTitle': text('recentSavedTitle', '최근 저장 카트'),
      'emptyTitle': text('savedEmptyTitle', '아직 저장된 카트가 없어요'),
      'emptyBody': text('savedEmptyBody', '현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
      'recentEmptyBody': text(
        'recentSavedEmptyBody',
        '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
      ),
      'adFallbackTitle': text('savedAdFallbackTitle', '함께 보면 좋은 혜택'),
      'adFallbackMessage': text(
        'savedAdFallbackMessage',
        '지난 카트를 다시 보는 흐름을 해치지 않는 선에서 꼭 맞는 혜택만 보여드릴게요.',
      ),
      'adSecondaryFallbackTitle': text(
        'savedAdSecondaryFallbackTitle',
        '비슷한 상품 혜택',
      ),
      'adSecondaryFallbackMessage': text(
        'savedAdSecondaryFallbackMessage',
        '기록을 보는 흐름은 그대로 두고, 필요한 혜택만 가볍게 보여드릴게요.',
      ),
    },
    'my': {
      'pageTitle': text('myPageTitle', '마이'),
      'subtitle': text('mySubtitle', '계정과 지난 카트를 한곳에서 관리해보세요'),
      'guestModeLabel': text('myGuestModeLabel', '게스트로 사용 중이에요'),
      'guestTitle': text('drawerGuestTitle', '게스트로 사용 중이에요'),
      'guestBody': text('drawerGuestBody', '저장과 기록을 이어가려면 로그인'),
      'benefitsTitle': text('myBenefitsTitle', '계정을 연결하면 이런 점이 좋아요'),
      'benefitsBody': text(
        'myBenefitsBody',
        '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
      ),
      'memberBody': text(
        'myMemberBody',
        '계정 정보와 지난 장보기 기록을 여기서 함께 관리하실 수 있어요.',
      ),
      'guestSignupAction': text('myGuestSignupAction', '회원가입하기'),
      'loginAction': text('myLoginAction', '로그인 / 회원가입'),
      'logoutAction': text('myLogoutAction', '로그아웃'),
      'linkedDoneMessage': text('myLinkedDoneMessage', '계정이 연결되었어요'),
      'logoutDoneMessage': text('myLogoutDoneMessage', '로그아웃되었어요'),
      'savedSectionTitle': text('mySavedSectionTitle', '지난 카트'),
      'savedSectionMemberSubtitle': text(
        'mySavedSectionMemberSubtitle',
        '저장해둔 지난 카트를 여기서 다시 확인해보세요',
      ),
      'savedSectionGuestSubtitle': text(
        'mySavedSectionGuestSubtitle',
        '게스트로 저장한 카트도 여기서 함께 확인하실 수 있어요',
      ),
      'adFallbackTitle': text('myAdFallbackTitle', '회원 전용 혜택 준비 중'),
      'adFallbackMessage': text(
        'myAdFallbackMessage',
        '마이에서는 계정과 잘 맞는 혜택만 보여드릴 예정이에요.',
      ),
      'complianceTitle': text('myComplianceTitle', '개인정보 및 문의'),
      'complianceBody': text(
        'myComplianceBody',
        '개인정보 처리방침과 문의 이메일을 여기서 바로 확인하실 수 있어요.',
      ),
      'privacyPolicyLabel': text(
        'myPrivacyPolicyLabel',
        '개인정보 처리방침',
      ),
      'privacyPolicyUrl': text(
        'myPrivacyPolicyUrl',
        'https://scan-api.seoa-nas.com/privacy',
      ),
      'supportEmailLabel': text('mySupportEmailLabel', '문의 이메일'),
      'supportEmail': text('mySupportEmail', ''),
      'supportPhoneLabel': text('mySupportPhoneLabel', '고객센터 연락처'),
      'supportPhone': text('mySupportPhone', ''),
      'supportHoursLabel': text('mySupportHoursLabel', '응답 안내'),
      'supportHours': text('mySupportHours', ''),
      'businessInfoLabel': text('myBusinessInfoLabel', '운영 정보'),
      'businessInfo': text('myBusinessInfo', ''),
      'supportNote': text(
        'mySupportNote',
        '문의는 아래 이메일로 보내주세요.',
      ),
    },
    'login': {
      'pageTitle': text('loginPageTitle', 'Cartly'),
      'subtitle': text('loginSubtitle', '저장과 기록을 이어가려면 로그인'),
      'benefitsTitle': text('loginBenefitsTitle', '회원이 되면 더 편리해요'),
      'benefitsBody': text(
        'loginBenefitsBody',
        '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.',
      ),
      'nameFieldLabel': text('loginNameFieldLabel', '이름'),
      'emailFieldLabel': text('loginEmailFieldLabel', '이메일'),
      'emailLocalFieldLabel': text('loginEmailLocalFieldLabel', '이메일 아이디'),
      'emailDomainFieldLabel': text('loginEmailDomainFieldLabel', '도메인'),
      'emailCustomDomainOption': text('loginEmailCustomDomainOption', '직접입력'),
      'emailCustomDomainFieldLabel': text(
        'loginEmailCustomDomainFieldLabel',
        '직접 입력 도메인',
      ),
      'passwordFieldLabel': text('loginPasswordFieldLabel', '비밀번호'),
      'passwordConfirmFieldLabel': text(
        'loginPasswordConfirmFieldLabel',
        '비밀번호 확인',
      ),
      'codeFieldLabel': text('loginCodeFieldLabel', '인증 코드'),
      'forgotPasswordAction': text('loginForgotPasswordAction', '비밀번호를 잊으셨나요?'),
      'invalidPasswordMessage': text(
        'loginInvalidPasswordMessage',
        '비밀번호를 확인해 주세요',
      ),
      'existingEmailTitle': text('loginExistingEmailTitle', '이미 가입된 이메일입니다'),
      'existingEmailBody': text(
        'loginExistingEmailBody',
        '이미 가입된 이메일입니다. 로그인하시거나 비밀번호를 재설정해 주세요.',
      ),
      'existingEmailLoginAction': text(
        'loginExistingEmailLoginAction',
        '로그인하기',
      ),
      'existingEmailResetAction': text(
        'loginExistingEmailResetAction',
        '비밀번호 재설정',
      ),
      'forgotPasswordPromptTitle': text(
        'loginForgotPasswordPromptTitle',
        '비밀번호를 잊으셨나요?',
      ),
      'forgotPasswordPromptBody': text(
        'loginForgotPasswordPromptBody',
        '비밀번호 입력을 여러 번 실패했습니다. 비밀번호 재설정으로 이동하시겠어요?',
      ),
      'forgotPasswordPromptStay': text(
        'loginForgotPasswordPromptStay',
        '다시 입력하기',
      ),
      'forgotPasswordPromptReset': text(
        'loginForgotPasswordPromptReset',
        '비밀번호 재설정',
      ),
      'sendingCode': text('loginSendingCode', '전송 중입니다...'),
      'resendCode': text('loginResendCode', '재전송'),
      'sendCode': text('loginSendCode', '코드 전송'),
      'submitting': text('loginSubmitting', '처리 중입니다...'),
      'continueAsGuest': text('loginContinueAsGuest', '게스트로 계속하기'),
      'mode': {
        'login': text('loginModeLogin', '로그인'),
        'signup': text('loginModeSignup', '회원가입'),
        'reset': text('loginModeReset', '비밀번호 찾기'),
      },
      'login': {'submit': text('loginLoginSubmit', '로그인')},
      'signup': {
        'submit': text('loginSignupSubmit', '회원가입 완료'),
        'codeSent': text('loginSignupCodeSent', '이메일 인증 코드를 보내드렸습니다'),
        'codeVerified': text('loginSignupCodeVerified', '이메일 인증이 완료되었습니다'),
        'verifyCodeAction': text('loginSignupVerifyCodeAction', '인증 코드 확인'),
        'verifyingCode': text('loginSignupVerifyingCode', '인증 확인 중입니다...'),
        'verifiedBadge': text('loginSignupVerifiedBadge', '인증 완료'),
      },
      'reset': {
        'newPasswordLabel': text('loginNewPasswordLabel', '새 비밀번호'),
        'submit': text('loginResetSubmit', '비밀번호 재설정'),
        'codeSent': text('loginResetCodeSent', '비밀번호 재설정 코드를 보내드렸습니다'),
        'backToLogin': text('loginResetBackToLogin', '로그인으로 돌아가기'),
      },
      'validation': {
        'emailRequired': text('loginValidationEmailRequired', '이메일을 입력해 주세요'),
        'emailPasswordRequired': text(
          'loginValidationEmailPasswordRequired',
          '이메일과 비밀번호를 입력해 주세요',
        ),
        'signupFieldsRequired': text(
          'loginValidationSignupFieldsRequired',
          '이름과 인증 코드를 모두 입력해 주세요',
        ),
        'nameRequired': text('loginValidationNameRequired', '이름을 입력해 주세요'),
        'signupCodeVerifyRequired': text(
          'loginValidationSignupCodeVerifyRequired',
          '이메일 인증을 먼저 완료해 주세요',
        ),
        'passwordTooShort': text(
          'loginValidationPasswordTooShort',
          '비밀번호는 8자 이상이어야 합니다',
        ),
        'passwordMismatch': text(
          'loginValidationPasswordMismatch',
          '비밀번호 확인이 일치하지 않습니다',
        ),
        'codeRequired': text('loginValidationCodeRequired', '인증 코드를 입력해 주세요'),
      },
    },
    'saveComplete': {
      'title': text('saveCompleteTitle', '카트를 저장했어요'),
      'subtitle': text('saveCompleteSubtitle', '다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
      'adFallbackTitle': text('saveCompleteAdFallbackTitle', '더 나은 대안 보기'),
      'adFallbackMessage': text(
        'saveCompleteAdFallbackMessage',
        '결제 전에 가볍게 비교해보실 수 있는 선택지를 보여드릴게요.',
      ),
      'viewSavedAction': text('saveCompleteViewSavedAction', '지난 카트 보기'),
    },
  };
}

UserSession _guestSession() => UserSession(
  id: 'preview-guest',
  provider: AuthProviderType.guest,
  displayName: 'Guest#2048',
  guestCode: '2048',
  email: '',
  isGuest: true,
  signedInAt: DateTime.now().subtract(const Duration(hours: 2)),
  authToken: 'preview',
  sessionExpiresAt: DateTime.now().add(const Duration(days: 7)),
);

UserSession _memberSession() => UserSession(
  id: 'preview-member',
  provider: AuthProviderType.email,
  displayName: '백승대',
  email: 'gabriel.paik@gmail.com',
  isGuest: false,
  signedInAt: DateTime.now().subtract(const Duration(days: 2)),
  authToken: 'preview',
  sessionExpiresAt: DateTime.now().add(const Duration(days: 7)),
);

List<SavedCart> _resolvePreviewCarts({
  required bool memberMode,
  required String explorePreviewState,
}) {
  if (explorePreviewState == 'idlePlanning' ||
      explorePreviewState == 'storeContext') {
    return _idleExploreCarts();
  }
  if (explorePreviewState == 'postSave') {
    return _postSaveExploreCarts();
  }
  if (memberMode) return _memberCarts();
  return _guestCarts();
}

String _normalizePreviewExploreState(String? value, String fallback) {
  switch (value?.trim()) {
    case 'active':
    case 'activeShopping':
      return 'activeShopping';
    case 'postSave':
      return 'postSave';
    case 'idle':
    case 'idlePlanning':
      return 'idlePlanning';
    case 'store':
    case 'storeContext':
      return 'storeContext';
    default:
      return fallback;
  }
}

List<SavedCart> _idleExploreCarts() => [
  SavedCart(
    id: 'preview-idle-1',
    title: '지난 주 장보기',
    createdAt: DateTime.now().subtract(const Duration(days: 7)),
    expiresAt: null,
    isExpired: false,
    retentionExtensionCount: 0,
    canExtendRetention: false,
    items: [
      SavedCartItem(name: '서울우유 1L', price: 2980, quantity: 2),
      SavedCartItem(name: '코카콜라 제로 355ml 24캔', price: 18900, quantity: 1),
    ],
  ),
  SavedCart(
    id: 'preview-idle-2',
    title: '이번 주 평일 장보기',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    expiresAt: null,
    isExpired: false,
    retentionExtensionCount: 0,
    canExtendRetention: false,
    items: [
      SavedCartItem(name: '서울우유 1L', price: 3050, quantity: 1),
      SavedCartItem(name: '커클랜드 키친타월 12롤', price: 17990, quantity: 1),
    ],
  ),
];

List<SavedCart> _postSaveExploreCarts() => [
  SavedCart(
    id: 'preview-post-save-1',
    title: '방금 저장한 장보기',
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    expiresAt: null,
    isExpired: false,
    retentionExtensionCount: 0,
    canExtendRetention: false,
    items: [
      SavedCartItem(name: '서울우유 1L', price: 2980, quantity: 2),
      SavedCartItem(name: '코카콜라 제로 355ml 24캔', price: 18900, quantity: 1),
      SavedCartItem(name: '삼다수 2L 6입', price: 6480, quantity: 1),
    ],
  ),
  ..._idleExploreCarts(),
];

List<SavedCart> _guestCarts() => [
  SavedCart(
    id: 'preview-expired',
    title: '금요일 장보기',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    isExpired: true,
    retentionExtensionCount: 0,
    canExtendRetention: true,
    items: [
      SavedCartItem(name: '콜라', price: 2500, quantity: 1),
      SavedCartItem(name: '과자', price: 3100, quantity: 2),
    ],
  ),
  SavedCart(
    id: 'preview-active',
    title: '주말 코스트코',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    expiresAt: DateTime.now().add(const Duration(days: 12)),
    isExpired: false,
    retentionExtensionCount: 0,
    canExtendRetention: true,
    items: [
      SavedCartItem(name: '우유', price: 4200, quantity: 2),
      SavedCartItem(name: '빵', price: 3900, quantity: 1),
    ],
  ),
];

final _previewCartItems = <CartItem>[
  CartItem(name: '서울우유 1L', price: 2980, quantity: 2),
  CartItem(name: '코카콜라 제로 355ml 24캔', price: 18900, quantity: 1),
  CartItem(name: '커클랜드 키친타월 12롤', price: 17990, quantity: 1),
];

final _previewRecentScans = <RecentScanEntry>[
  RecentScanEntry(
    id: 'preview-scan-1',
    item: RecognizedItem(name: '서울우유 1 L 기획팩', price: 2980),
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
  ),
  RecentScanEntry(
    id: 'preview-scan-2',
    item: RecognizedItem(name: '코카콜라 제로 355 ml 24캔 특가', price: 18900),
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
];

class _PreviewScanRepository implements ScanRepository {
  @override
  Future<ScanJob> submitImage(String imagePath) async {
    throw UnimplementedError('preview only');
  }

  @override
  Future<ScanJob> getJob(String jobId) async {
    throw UnimplementedError('preview only');
  }

  @override
  Future<RecognizedItemCandidate?> getResult(String jobId) async => null;

  @override
  Future<void> submitFeedback({
    required String jobId,
    required bool accepted,
    required RecognizedItemCandidate original,
    RecognizedItem? corrected,
  }) async {}

  @override
  Future<void> reportFailure({
    required String jobId,
    required String stage,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? details,
  }) async {}
}

List<SavedCart> _memberCarts() => [
  SavedCart(
    id: 'preview-member-cart',
    title: '평일 장보기',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    expiresAt: null,
    isExpired: false,
    retentionExtensionCount: 0,
    canExtendRetention: false,
    items: [
      SavedCartItem(name: '샴푸', price: 8900, quantity: 1),
      SavedCartItem(name: '휴지', price: 12900, quantity: 1),
    ],
  ),
];
