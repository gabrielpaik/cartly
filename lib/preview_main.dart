import 'package:flutter/material.dart';

import 'models/app_branding.dart';
import 'models/auth_provider_type.dart';
import 'models/saved_cart.dart';
import 'models/user_session.dart';
import 'preview/preview_bridge.dart';
import 'preview/preview_shared_screens.dart';
import 'preview/preview_state.dart';
import 'services/app_config_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CartlyPreviewApp());
}

class CartlyPreviewApp extends StatefulWidget {
  const CartlyPreviewApp({super.key});

  @override
  State<CartlyPreviewApp> createState() => _CartlyPreviewAppState();
}

class _CartlyPreviewAppState extends State<CartlyPreviewApp> {
  String _previewScreen = 'home';
  bool _memberMode = false;

  @override
  void initState() {
    super.initState();
    _applyPreviewPayload(_defaultPayload());
    listenPreviewMessages(_applyPreviewPayload);
    notifyPreviewReady();
  }

  void _applyPreviewPayload(Map<String, dynamic> payload) {
    AppConfigStore.instance.branding.value = AppBranding.fromJson(payload);
    AppConfigStore.instance.copy.value = _buildPreviewCopy(payload);
    AppConfigStore.instance.adSlots.value = const [];
    _previewScreen = (payload['__previewScreen'] as String?) ?? _previewScreen;
    _applySessionState(
      memberMode: (payload['__previewMemberMode'] as bool?) ?? _memberMode,
    );
    if (mounted) setState(() {});
  }

  void _applySessionState({required bool memberMode}) {
    _memberMode = memberMode;
    PreviewState.session.value = memberMode ? _memberSession() : _guestSession();
    PreviewState.carts.value = memberMode ? _memberCarts() : _guestCarts();
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
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(34),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(10),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: _buildPreviewBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBody() {
    switch (_previewScreen) {
      case 'home':
        return const PreviewHomeScreen();
      case 'saved':
        return const PreviewSavedScreen();
      case 'my':
        return const PreviewMyScreen();
      case 'login':
        return const PreviewLoginScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

Map<String, dynamic> _defaultPayload() => {
  'logoType': 'text',
  'logoText': 'Cartly',
  'logoImageUrl': null,
  'splashImageUrl': null,
  'loginHeroImageUrl': null,
  'homePageTitle': 'Cartly',
  'homeSubtitle': '결제 전에 더 똑똑하게 비교해보세요',
  'helpSubtitle': '운영 부담이 큰 피드형 쇼핑 탭 대신, 정말 도움이 되는 기능부터 붙일 예정이야',
  'homeTabLabel': 'Home',
  'helpTabLabel': '도움',
  'savedTabLabel': 'Saved',
  'myTabLabel': 'My',
  'savedTitle': '저장한 카트',
  'savedSubtitle': '다음 쇼핑 전에 다시 꺼내 비교할 수 있어요.',
  'myGuestTitle': '게스트로 사용 중이에요',
  'myGuestBody': '저장과 기록을 이어가려면 로그인',
  'myGuestSignupAction': '회원가입하기',
  'myBenefitsTitle': '계정이 있으면 좋은 점',
  'myBenefitsBody': '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
  'loginPageTitle': 'Cartly',
  'loginBenefitsTitle': '회원이 되면 더 편리해요',
  'loginBenefitsBody': '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.',
  'loginEmailLocalFieldLabel': '이메일',
  'loginPasswordLabel': '비밀번호',
  'loginLoginSubmit': '로그인',
  'loginContinueAsGuest': '게스트로 계속하기',
  'saveCompleteTitle': '카트를 저장했어요',
  'saveCompleteSubtitle': '다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
};

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
      'recentSavedTitle': text('homeRecentSavedTitle', '최근 저장 카트'),
      'recentSavedBody': text('homeRecentSavedBody', '최근에 저장한 카트를 다시 열어 빠르게 이어볼 수 있어요.'),
      'addSectionTitle': text('homeAddSectionTitle', '새 상품 추가'),
      'addSectionSubtitle': text('homeAddSectionSubtitle', '사진 인식이 어렵다면 직접 추가해도 돼요.'),
      'scanCta': text('homeScanCta', '가격표 인식하기'),
    },
    'saved': {
      'pageTitle': text('savedTitle', '저장한 카트'),
      'subtitle': text('savedSubtitle', '다음 쇼핑 전에 다시 꺼내 비교할 수 있어요.'),
      'recentTitle': text('homeRecentSavedTitle', '최근 저장 카트'),
      'emptyTitle': text('savedEmptyTitle', '아직 저장된 카트가 없어요'),
      'emptyBody': text('savedEmptyBody', '현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
    },
    'my': {
      'pageTitle': text('myPageTitle', 'My account'),
      'subtitle': text('mySubtitle', '기록을 남기려면 로그인이 필요합니다'),
      'subtitleMember': text('mySubtitleMember', '내 계정과 저장한 카트를 확인해.'),
      'guestModeLabel': text('myGuestTitle', '게스트로 사용 중이에요'),
      'guestBody': text('myGuestBody', '저장과 기록을 이어가려면 로그인'),
      'guestSignupAction': text('myGuestSignupAction', '회원가입하기'),
      'benefitsTitle': text('myBenefitsTitle', '계정이 있으면 좋은 점'),
      'benefitsBody': text('myBenefitsBody', '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기'),
      'logoutAction': text('myLogoutAction', '로그아웃'),
    },
    'login': {
      'pageTitle': text('loginPageTitle', 'Cartly'),
      'benefitsTitle': text('loginBenefitsTitle', '회원이 되면 더 편리해요'),
      'benefitsBody': text('loginBenefitsBody', '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.'),
      'emailLocalFieldLabel': text('loginEmailLocalFieldLabel', '이메일'),
      'passwordLabel': text('loginPasswordLabel', '비밀번호'),
      'loginSubmit': text('loginLoginSubmit', '로그인'),
      'continueAsGuest': text('loginContinueAsGuest', '게스트로 계속하기'),
      'signupTab': text('loginSignupTab', '회원가입'),
      'loginTab': text('loginLoginTab', '로그인'),
      'forgotPassword': text('loginForgotPassword', '비밀번호를 잊으셨나요?'),
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
