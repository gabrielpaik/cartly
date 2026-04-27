import 'package:flutter/material.dart';

import 'app_support.dart';
import 'models/app_branding.dart';
import 'models/auth_provider_type.dart';
import 'models/recognized_item.dart';
import 'models/saved_cart.dart';
import 'models/user_session.dart';
import 'pages/shopping_help_page.dart';
import 'preview/preview_shared_screens.dart';
import 'preview/preview_state.dart';
import 'services/app_config_store.dart';
import 'services/cart_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _seedScreenshotState();
  runApp(const CartlyScreenshotApp());
}

class CartlyScreenshotApp extends StatelessWidget {
  const CartlyScreenshotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE31837)),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        useMaterial3: true,
      ),
      home: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    const screen = String.fromEnvironment(
      'SCREENSHOT_SCREEN',
      defaultValue: 'explore',
    );

    switch (screen) {
      case 'home':
        return const Scaffold(body: PreviewHomeScreen());
      case 'my':
        return const Scaffold(body: PreviewMyScreen());
      case 'login':
        return const Scaffold(body: PreviewLoginScreen());
      case 'explore':
      default:
        return Scaffold(
          body: ShoppingHelpPage(
            items: _mockCartItems,
            recentScans: _mockRecentScans,
            onGoHome: () {},
            onGoSaved: () {},
          ),
        );
    }
  }
}

void _seedScreenshotState() {
  AppConfigStore.instance.branding.value = AppBranding.fromJson(const {
    'logoType': 'text',
    'logoText': 'Cartly',
    'homeTabLabel': 'Home',
    'helpTabLabel': 'Explore',
    'myTabLabel': 'My',
  });

  AppConfigStore.instance.copy.value = {
    'home': {
      'pageTitle': 'Cartly',
      'subtitle': '지금 카트 총액과 최근 기록을 한 번에 확인해',
      'recentSavedTitle': '최근 저장 카트',
      'recentSavedBody': '저장한 장보기 기록을 다시 열어 비교할 수 있어요.',
      'addSectionTitle': '새 상품 추가',
      'addSectionSubtitle': '스캔하거나 바로 담기',
      'scanCta': '가격표 인식하기',
    },
    'help': {
      'pageTitle': 'Explore',
      'subtitle': '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요',
    },
    'my': {
      'pageTitle': 'My account',
      'subtitle': '내 계정과 저장한 카트를 확인해.',
      'subtitleMember': '내 계정과 저장한 카트를 확인해.',
      'logoutAction': '로그아웃',
    },
    'login': {
      'pageTitle': 'Cartly',
      'benefitsTitle': '회원이 되면 더 편리해요',
      'benefitsBody': '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.',
      'emailLocalFieldLabel': '이메일',
      'passwordLabel': '비밀번호',
      'loginSubmit': '로그인',
      'continueAsGuest': '게스트로 계속하기',
      'signupTab': '회원가입',
      'loginTab': '로그인',
      'forgotPassword': '비밀번호를 잊으셨나요?',
    },
    'saved': {
      'pageTitle': '저장한 카트',
      'subtitle': '다음 쇼핑 전에 다시 꺼내 비교할 수 있어요.',
    },
  };

  final memberSession = UserSession(
    id: 'screenshot-member',
    provider: AuthProviderType.email,
    displayName: '백승대',
    email: 'gabriel.paik@gmail.com',
    isGuest: false,
    signedInAt: DateTime.now().subtract(const Duration(days: 2)),
    authToken: 'preview',
    sessionExpiresAt: DateTime.now().add(const Duration(days: 7)),
  );

  PreviewState.session.value = memberSession;
  PreviewState.carts.value = _mockSavedCarts;
  CartStore.instance.carts.value = _mockSavedCarts;
}

final _mockCartItems = <CartItem>[
  CartItem(name: '서울우유 1L', price: 2980, quantity: 2),
  CartItem(name: '코카콜라 제로 355ml 24캔', price: 18900, quantity: 1),
  CartItem(name: '커클랜드 키친타월 12롤', price: 17990, quantity: 1),
];

final _mockRecentScans = <RecentScanEntry>[
  RecentScanEntry(
    id: 'scan-1',
    item: RecognizedItem(name: '서울우유 1 L 기획팩', price: 2980),
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
  ),
  RecentScanEntry(
    id: 'scan-2',
    item: RecognizedItem(name: '코카콜라 제로 355 ml 24캔 특가', price: 18900),
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
];

final _mockSavedCarts = <SavedCart>[
  SavedCart(
    id: 'saved-1',
    title: '코스트코 4월 마지막 주',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    expiresAt: DateTime.now().add(const Duration(days: 10)),
    isExpired: false,
    retentionExtensionCount: 0,
    canExtendRetention: true,
    items: [
      SavedCartItem(name: '서울우유 1L', price: 2980, quantity: 2),
      SavedCartItem(name: '코카콜라 제로 355ml 24캔', price: 18900, quantity: 1),
      SavedCartItem(name: '커클랜드 키친타월 12롤', price: 17990, quantity: 1),
    ],
  ),
  SavedCart(
    id: 'saved-2',
    title: '주말 장보기',
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
    expiresAt: DateTime.now().add(const Duration(days: 5)),
    isExpired: false,
    retentionExtensionCount: 0,
    canExtendRetention: true,
    items: [
      SavedCartItem(name: '서울우유 1L', price: 2980, quantity: 1),
      SavedCartItem(name: '계란 30구', price: 7990, quantity: 1),
      SavedCartItem(name: '바나나', price: 4980, quantity: 1),
    ],
  ),
];
