import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'app/cartly_ui.dart';
import 'app_support.dart';
import 'models/auth_provider_type.dart';
import 'models/household_state.dart';
import 'models/recognized_item.dart';
import 'models/recognized_item_candidate.dart';
import 'models/saved_cart.dart';
import 'models/scan_job.dart';
import 'models/user_session.dart';
import 'pages/home_tab_view.dart';
import 'pages/login_page.dart';
import 'pages/my_page.dart';
import 'pages/shopping_help_page.dart';
import 'services/app_config_store.dart';
import 'services/app_location_service.dart';
import 'services/auth_store.dart';
import 'services/cart_store.dart';
import 'services/household_store.dart';
import 'services/scan_repository.dart';
import 'widgets/cartly_symbol_icon.dart';
import 'widgets/total_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _seedScreenshotState();
  runApp(const CartlyScreenshotApp());
}

class CartlyScreenshotApp extends StatelessWidget {
  const CartlyScreenshotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppConfigStore.instance.branding,
        AppConfigStore.instance.copy,
        AppConfigStore.instance.runtime,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Pretendard',
            scaffoldBackgroundColor: CartlyColors.surface0,
            canvasColor: CartlyColors.surface0,
            cardColor: CartlyColors.surface1,
            colorScheme: ColorScheme.fromSeed(
              seedColor: CartlyColors.brand,
              surface: CartlyColors.surface0,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: CartlyColors.surface0,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(CartlyRadii.hero),
                ),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: CartlyColors.surface0,
              indicatorColor: Colors.transparent,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CartlyColors.brand,
                  );
                }
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CartlyColors.textSecondary,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: CartlyColors.brand);
                }
                return const IconThemeData(
                  color: CartlyColors.textSecondary,
                );
              }),
            ),
          ),
          home: _buildScreen(),
        );
      },
    );
  }

  Widget _buildScreen() {
    const screen = String.fromEnvironment(
      'SCREENSHOT_SCREEN',
      defaultValue: 'home',
    );

    switch (screen) {
      case 'login':
        return const Scaffold(
          body: SafeArea(
            child: LoginPage(skipInitialConfigRefresh: true),
          ),
        );
      case 'explore':
        return const _ScreenshotShell(initialTabIndex: 1);
      case 'my':
        return const _ScreenshotShell(initialTabIndex: 2);
      case 'home':
      default:
        return const _ScreenshotShell(initialTabIndex: 0);
    }
  }
}

class _ScreenshotShell extends StatelessWidget {
  final int initialTabIndex;

  const _ScreenshotShell({required this.initialTabIndex});

  @override
  Widget build(BuildContext context) {
    final branding = AppConfigStore.instance.branding.value;
    final items = _mockCurrentCartItems;
    final recentScans = _mockRecentScans;
    final consideredItems = _mockConsideredItems;
    final activeShopping = items.isNotEmpty || recentScans.isNotEmpty;
    final exploreTabLabel = activeShopping ? '지금 장보는중!' : branding.helpTabLabel;

    final body = IndexedStack(
      index: initialTabIndex,
      children: [
        HomeTabView(
          cameras: const <CameraDescription>[],
          scanRepository: const _ScreenshotScanRepository(),
          items: items,
          recentScans: recentScans,
          onRecognized: (_) {},
          onAdd: (_) async => true,
          onDismissRecognized: (_) {},
          onAddRecentScan: (_) async => true,
          onDismissRecentScan: (_) {},
          onRemove: (_) {},
          onChangeCurrentCartItem: (_) {},
          onGoExplore: () {},
        ),
        ShoppingHelpPage(
          items: items,
          recentScans: recentScans,
          consideredItems: consideredItems,
          onGoHome: () {},
          onGoSaved: () {},
        ),
        const MyPage(),
      ],
    );

    return Scaffold(
      backgroundColor: CartlyColors.surface0,
      body: SafeArea(child: body),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (initialTabIndex == 0)
            TotalBar(
              totalPrice: items.fold(0, (sum, item) => sum + item.totalPrice),
              onSave: () {},
              isSaving: false,
            ),
          NavigationBar(
            selectedIndex: initialTabIndex,
            onDestinationSelected: (_) {},
            backgroundColor: CartlyColors.surface0,
            indicatorColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            height: 78,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CartlyColors.brand,
                );
              }
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CartlyColors.textSecondary,
              );
            }),
            destinations: [
              NavigationDestination(
                icon: const CartlySymbolIcon.sf('cart', size: 28),
                selectedIcon: const CartlySymbolIcon.sf('cart.fill', size: 28),
                label: branding.homeTabLabel,
              ),
              NavigationDestination(
                icon: const CartlySymbolIcon.sf(
                  'magnifyingglass',
                  size: 28,
                ),
                selectedIcon: const CartlySymbolIcon.sf(
                  'sparkle.magnifyingglass',
                  size: 28,
                ),
                label: exploreTabLabel,
              ),
              NavigationDestination(
                icon: const CartlySymbolIcon.sf(
                  'person.crop.circle',
                  size: 28,
                ),
                selectedIcon: const CartlySymbolIcon.sf(
                  'person.crop.circle.fill',
                  size: 28,
                ),
                label: branding.myTabLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScreenshotScanRepository implements ScanRepository {
  const _ScreenshotScanRepository();

  @override
  Future<ScanJob> submitImage(String imagePath) async {
    throw UnimplementedError('Screenshot harness does not submit scans');
  }

  @override
  Future<ScanJob> getJob(String jobId) async {
    throw UnimplementedError('Screenshot harness does not fetch scan jobs');
  }

  @override
  Future<RecognizedItemCandidate?> getResult(String jobId) async {
    return null;
  }

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

Future<void> _seedScreenshotState() async {
  await AppConfigStore.instance.load();

  final screen = const String.fromEnvironment(
    'SCREENSHOT_SCREEN',
    defaultValue: 'home',
  );

  AuthStore.instance.session.value = screen == 'login' ? null : _memberSession;
  CartStore.instance.carts.value = _mockSavedCarts;
  HouseholdStore.instance.state.value = _mockHouseholdState;
  AppLocationService.instance.snapshot.value = _mockLocationSnapshot;
  AppLocationService.instance.history.value = [_mockLocationSnapshot];

  if (AppConfigStore.instance.copy.value.isEmpty) {
    AppConfigStore.instance.copy.value = _fallbackCopy;
  }
}

final _memberSession = UserSession(
  id: 'screenshot-member',
  provider: AuthProviderType.email,
  displayName: '백승대',
  email: 'preview-member@cartly.app',
  isGuest: false,
  signedInAt: DateTime.now().subtract(const Duration(days: 12)),
  authToken: 'screenshot-session-token',
  sessionExpiresAt: DateTime.now().add(const Duration(days: 7)),
);

final _mockLocationSnapshot = AppLocationSnapshot(
  latitude: 37.5253,
  longitude: 126.8896,
  source: 'manual_refresh',
  permissionStatus: 'whileInUse',
  cityName: '서울특별시',
  districtName: '영등포구',
  neighborhoodName: '양평동',
  capturedAt: DateTime.now().subtract(const Duration(minutes: 8)),
  accuracyMeters: 42,
);

const _mockHouseholdState = HouseholdState(
  hasHousehold: true,
  household: HouseholdSummary(
    id: 'household-1',
    name: '백가네',
    inviteCode: 'ABCD12',
    memberCount: 2,
  ),
  members: [
    HouseholdMemberSummary(
      userId: 'screenshot-member',
      displayName: '백승대',
      email: 'preview-member@cartly.app',
      role: 'owner',
      isMe: true,
    ),
    HouseholdMemberSummary(
      userId: 'member-2',
      displayName: '가족 구성원',
      email: 'family@example.com',
      role: 'member',
      isMe: false,
    ),
  ],
);

final _mockCurrentCartItems = <CartItem>[
  CartItem(
    id: 'cart-1',
    name: '서울우유 1L',
    price: 2980,
    quantity: 2,
    source: 'manual',
  ),
  CartItem(
    id: 'cart-2',
    name: '코카콜라 제로 355ml 24캔',
    price: 18900,
    quantity: 1,
    source: 'manual',
  ),
  CartItem(
    id: 'cart-3',
    name: '커클랜드 키친타월 12롤',
    price: 17990,
    quantity: 1,
    source: 'manual',
  ),
];

final _mockRecentScans = <RecentScanEntry>[
  RecentScanEntry(
    id: 'scan-1',
    item: RecognizedItem(
      name: '서울우유 1L 기획팩',
      price: 2980,
      source: 'scan',
      originalRecognizedName: '서울우유 1L 기획팩',
    ),
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
  ),
  RecentScanEntry(
    id: 'scan-2',
    item: RecognizedItem(
      name: '코카콜라 제로 355ml 24캔 특가',
      price: 18900,
      source: 'scan',
      originalRecognizedName: '코카콜라 제로 355ml 24캔 특가',
    ),
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
];

final _mockConsideredItems = <ConsideredProductEntry>[
  ConsideredProductEntry(
    id: 'considered-1',
    name: '서울우유 1L 기획팩',
    price: 2980,
    source: 'scanNotAdded',
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    originalRecognizedName: '서울우유 1L 기획팩',
  ),
  ConsideredProductEntry(
    id: 'considered-2',
    name: '코카콜라 제로 355ml 24캔 특가',
    price: 18900,
    source: 'cartRemoved',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    originalRecognizedName: '코카콜라 제로 355ml 24캔 특가',
  ),
];

final _mockSavedCarts = <SavedCart>[
  SavedCart(
    id: 'saved-1',
    title: '코스트코 5월 14일',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    expiresAt: DateTime.now().add(const Duration(days: 10)),
    items: [
      SavedCartItem(
        name: '서울우유 1L',
        price: 2980,
        quantity: 2,
        categoryLabel: '식품',
      ),
      SavedCartItem(
        name: '코카콜라 제로 355ml 24캔',
        price: 18900,
        quantity: 1,
        categoryLabel: '식품',
      ),
      SavedCartItem(
        name: '커클랜드 키친타월 12롤',
        price: 17990,
        quantity: 1,
        categoryLabel: '생활',
      ),
    ],
    owner: const SavedCartUserSummary(
      id: 'screenshot-member',
      displayName: '백승대',
      email: 'preview-member@cartly.app',
      isGuest: false,
    ),
    household: const SavedCartHouseholdSummary(
      id: 'household-1',
      name: '백가네',
    ),
    receiptStatus: SavedCartReceiptStatus(
      receiptId: 'receipt-1',
      receiptStatus: 'ready',
      merchantName: '코스트코',
      hasReceipt: true,
      purchasedAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      completedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ),
  SavedCart(
    id: 'saved-2',
    title: '주말 장보기',
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
    updatedAt: DateTime.now().subtract(const Duration(days: 8)),
    expiresAt: DateTime.now().add(const Duration(days: 5)),
    items: [
      SavedCartItem(
        name: '계란 30구',
        price: 7990,
        quantity: 1,
        categoryLabel: '식품',
      ),
      SavedCartItem(
        name: '바나나',
        price: 4980,
        quantity: 1,
        categoryLabel: '식품',
      ),
      SavedCartItem(
        name: '애호박',
        price: 1980,
        quantity: 1,
        categoryLabel: '식품',
      ),
    ],
    owner: const SavedCartUserSummary(
      id: 'screenshot-member',
      displayName: '백승대',
      email: 'preview-member@cartly.app',
      isGuest: false,
    ),
  ),
];

const _fallbackCopy = {
  'home': {
    'subtitle': '지금 담은 상품과 합계를 한눈에 확인해보세요',
    'addSectionTitle': '새 상품 추가',
    'addSectionSubtitle': '스캔하거나 직접 담아보세요',
    'recentScanTitle': '스캔 보관함',
    'recentScanSubtitle': '검토 대기 결과를 한 번에 정리해',
    'currentCartTitle': '현재 카트',
    'currentCartSubtitle': '지금 담은 상품과 합계를 확인해보세요',
    'exploreEntryTitle': '탐색에서 다음 판단 이어가기',
    'exploreEntryBody': '비교 후보와 대안을 한 번에 보고 결정해보세요',
  },
  'help': {
    'pageTitle': '탐색',
    'subtitle': '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요',
  },
  'my': {
    'pageTitle': '마이페이지',
    'subtitle': '내 계정과 저장한 카트를 확인해.',
    'subtitleMember': '내 계정과 저장한 카트를 확인해.',
    'settingsShareEntryAction': '수정 및 가족공유',
    'privacyPolicyLabel': '개인정보 처리방침',
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
};
