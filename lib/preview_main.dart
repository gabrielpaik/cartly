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
  String _previewScreen = 'home';
  bool _memberMode = false;

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
    AppConfigStore.instance.adSlots.value = const [];
    _previewScreen = (payload['__previewScreen'] as String?) ?? _previewScreen;
    _applySessionState(
      memberMode: (payload['__previewMemberMode'] as bool?) ?? _memberMode,
    );
    if (mounted) setState(() {});
  }

  void _applySessionState({required bool memberMode}) {
    _memberMode = memberMode;
    final session = memberMode ? _memberSession() : _guestSession();
    final carts = memberMode ? _memberCarts() : _guestCarts();
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
          ),
          bottomNavigationBar: TotalBar(
            totalPrice: _previewCartItems.fold(0, (sum, item) => sum + item.totalPrice),
            onSave: () async {},
            isSaving: false,
          ),
        );
      case 'help':
        return ShoppingHelpPage(
          items: _previewCartItems,
          recentScans: _previewRecentScans,
          onGoHome: () {},
          onGoSaved: () {},
        );
      case 'my':
        return const Scaffold(
          backgroundColor: Colors.white,
          body: MyPage(),
        );
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
  'helpSubtitle': '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요',
  'homeTabLabel': 'Home',
  'helpTabLabel': '도움',
  'myTabLabel': 'My',
  'savedPageTitle': '저장한 카트',
  'savedSubtitle': '다음 쇼핑 전에 다시 꺼내 비교할 수 있어요.',
  'savedEmptyTitle': '아직 저장된 카트가 없어요',
  'savedEmptyBody': '현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
  'recentSavedTitle': '최근 저장 카트',
  'recentSavedEmptyBody': '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
  'homeRecentScanTitle': '스캔 보관함',
  'homeRecentScanSubtitle': '검토 대기 결과를 한 번에 정리해',
  'homeCurrentCartTitle': '현재 카트',
  'homeCurrentCartSubtitle': '결제 전 합계를 확인해',
  'homeCurrentCartEmpty': '아직 담은 상품이 없어요',
  'homeAddToCurrentCartDone': '현재 카트에 담았어요',
  'homeAddToCurrentCartButton': '현재 카트에 담기',
  'homeSaveCartButton': '카트 저장',
  'homeCartTotalLabel': '현재 카트 합계',
  'homeContinueScanAction': '계속 스캔하기',
  'myGuestModeLabel': '게스트로 사용 중이에요',
  'drawerGuestTitle': '게스트로 사용 중이에요',
  'drawerGuestBody': '저장과 기록을 이어가려면 로그인',
  'myBenefitsTitle': '계정이 있으면 좋은 점',
  'myBenefitsBody': '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
  'loginPageTitle': 'Cartly',
  'loginBenefitsTitle': '회원이 되면 더 편리해요',
  'loginBenefitsBody': '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.',
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
  'saveCompleteSubtitle': '다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
  'saveCompleteViewSavedAction': '지난 카트 보기',
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
      'recentScanTitle': text('homeRecentScanTitle', '스캔 보관함'),
      'recentScanSubtitle': text('homeRecentScanSubtitle', '검토 대기 결과를 한 번에 정리해'),
      'addSectionTitle': text('homeAddSectionTitle', '새 상품 추가'),
      'addSectionSubtitle': text('homeAddSectionSubtitle', '스캔하거나 바로 담기'),
      'currentCartTitle': text('homeCurrentCartTitle', '현재 카트'),
      'currentCartSubtitle': text('homeCurrentCartSubtitle', '결제 전 합계를 확인해'),
      'currentCartEmpty': text('homeCurrentCartEmpty', '아직 담은 상품이 없어요'),
      'addToCurrentCartDone': text('homeAddToCurrentCartDone', '현재 카트에 담았어요'),
      'addToCurrentCartButton': text('homeAddToCurrentCartButton', '현재 카트에 담기'),
      'saveCartButton': text('homeSaveCartButton', '카트 저장'),
      'cartTotalLabel': text('homeCartTotalLabel', '현재 카트 합계'),
      'continueScanAction': text('homeContinueScanAction', '계속 스캔하기'),
      'recentSavedAction': text('homeRecentSavedAction', '지난 카트 보기'),
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
      'recentEmptyBody': text('recentSavedEmptyBody', '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
    },
    'my': {
      'pageTitle': text('myPageTitle', 'My account'),
      'subtitle': text('mySubtitle', '기록을 남기려면 로그인이 필요합니다'),
      'guestModeLabel': text('myGuestModeLabel', '게스트로 사용 중이에요'),
      'guestTitle': text('drawerGuestTitle', '게스트로 사용 중이에요'),
      'guestBody': text('drawerGuestBody', '저장과 기록을 이어가려면 로그인'),
      'benefitsTitle': text('myBenefitsTitle', '계정이 있으면 좋은 점'),
      'benefitsBody': text('myBenefitsBody', '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기'),
      'loginAction': text('myLoginAction', '로그인 / 회원가입'),
      'logoutAction': text('myLogoutAction', '로그아웃'),
      'linkedDoneMessage': text('myLinkedDoneMessage', '계정을 연결했어요'),
      'logoutDoneMessage': text('myLogoutDoneMessage', '로그아웃했어요'),
    },
    'login': {
      'pageTitle': text('loginPageTitle', 'Cartly'),
      'subtitle': text('loginSubtitle', '저장과 기록을 이어가려면 로그인'),
      'benefitsTitle': text('loginBenefitsTitle', '회원이 되면 더 편리해요'),
      'benefitsBody': text('loginBenefitsBody', '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.'),
      'nameFieldLabel': text('loginNameFieldLabel', '이름'),
      'emailFieldLabel': text('loginEmailFieldLabel', '이메일'),
      'emailLocalFieldLabel': text('loginEmailLocalFieldLabel', '이메일 아이디'),
      'emailDomainFieldLabel': text('loginEmailDomainFieldLabel', '도메인'),
      'emailCustomDomainOption': text('loginEmailCustomDomainOption', '직접입력'),
      'emailCustomDomainFieldLabel': text('loginEmailCustomDomainFieldLabel', '직접 입력 도메인'),
      'passwordFieldLabel': text('loginPasswordFieldLabel', '비밀번호'),
      'passwordConfirmFieldLabel': text('loginPasswordConfirmFieldLabel', '비밀번호 확인'),
      'codeFieldLabel': text('loginCodeFieldLabel', '인증 코드'),
      'forgotPasswordAction': text('loginForgotPasswordAction', '비밀번호를 잊으셨나요?'),
      'invalidPasswordMessage': text('loginInvalidPasswordMessage', '비밀번호를 확인해 주세요'),
      'existingEmailTitle': text('loginExistingEmailTitle', '이미 가입된 이메일입니다'),
      'existingEmailBody': text('loginExistingEmailBody', '이미 가입된 이메일입니다. 로그인하시거나 비밀번호를 재설정해 주세요.'),
      'existingEmailLoginAction': text('loginExistingEmailLoginAction', '로그인하기'),
      'existingEmailResetAction': text('loginExistingEmailResetAction', '비밀번호 재설정'),
      'forgotPasswordPromptTitle': text('loginForgotPasswordPromptTitle', '비밀번호를 잊으셨나요?'),
      'forgotPasswordPromptBody': text('loginForgotPasswordPromptBody', '비밀번호 입력을 여러 번 실패했습니다. 비밀번호 재설정으로 이동하시겠어요?'),
      'forgotPasswordPromptStay': text('loginForgotPasswordPromptStay', '다시 입력하기'),
      'forgotPasswordPromptReset': text('loginForgotPasswordPromptReset', '비밀번호 재설정'),
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
      'login': {
        'submit': text('loginLoginSubmit', '로그인'),
      },
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
        'emailPasswordRequired': text('loginValidationEmailPasswordRequired', '이메일과 비밀번호를 입력해 주세요'),
        'signupFieldsRequired': text('loginValidationSignupFieldsRequired', '이름과 인증 코드를 모두 입력해 주세요'),
        'nameRequired': text('loginValidationNameRequired', '이름을 입력해 주세요'),
        'signupCodeVerifyRequired': text('loginValidationSignupCodeVerifyRequired', '이메일 인증을 먼저 완료해 주세요'),
        'passwordTooShort': text('loginValidationPasswordTooShort', '비밀번호는 8자 이상이어야 합니다'),
        'passwordMismatch': text('loginValidationPasswordMismatch', '비밀번호 확인이 일치하지 않습니다'),
        'codeRequired': text('loginValidationCodeRequired', '인증 코드를 입력해 주세요'),
      },
    },
    'saveComplete': {
      'title': text('saveCompleteTitle', '카트를 저장했어요'),
      'subtitle': text('saveCompleteSubtitle', '다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
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
