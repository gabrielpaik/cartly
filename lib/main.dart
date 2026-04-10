import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/wimc_runtime_config.dart';
import 'models/app_ad_slot.dart';
import 'models/recognized_item.dart';
import 'models/saved_cart.dart';
import 'models/user_session.dart';
import 'pages/cart_detail_page.dart';
import 'pages/login_page.dart';
import 'services/ad_tracking_service.dart';
import 'services/admob_service.dart';
import 'services/app_config_store.dart';
import 'services/app_runtime_copy.dart';
import 'services/auth_store.dart';
import 'services/cart_store.dart';
import 'services/remote_scan_repository.dart';
import 'services/scan_repository.dart';
import 'splash_screen.dart';
import 'widgets/admob_banner_slot.dart';
import 'widgets/item_add_section.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  await AuthStore.instance.load();
  await CartStore.instance.load();
  await AdMobService.instance.initialize();
  runApp(const MyApp());
}

final _priceFormatter = NumberFormat('#,###');
String formatPrice(int price) => _priceFormatter.format(price);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final Listenable _runtimeListenable = Listenable.merge([
    AppConfigStore.instance.branding,
    AppConfigStore.instance.copy,
    AppConfigStore.instance.adSlots,
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppConfigStore.instance.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppConfigStore.instance.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runtimeListenable,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Pretendard',
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE31837)),
          ),
          home: SplashScreen(next: const HomePage()),
        );
      },
    );
  }
}

class CartItem {
  String name;
  int price;
  int quantity;

  CartItem({required this.name, required this.price, this.quantity = 1});
  int get totalPrice => price * quantity;
}

class RecentScanEntry {
  final RecognizedItem item;
  final DateTime createdAt;

  const RecentScanEntry({required this.item, required this.createdAt});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<CartItem> items = [];
  final List<RecentScanEntry> recentScans = [];
  int _tabIndex = 0;
  bool _savingCurrentCart = false;

  late final ScanRepository _scanRepository = RemoteScanRepository(
    baseUrl: WimcRuntimeConfig.current.normalizedRemoteBaseUrl,
    authToken: WimcRuntimeConfig.current.effectiveRemoteAuthToken,
  );

  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

  void _recordRecentScan(RecognizedItem item) {
    setState(() {
      recentScans.insert(
        0,
        RecentScanEntry(item: item, createdAt: DateTime.now()),
      );
      if (recentScans.length > 10) {
        recentScans.removeRange(10, recentScans.length);
      }
    });
  }

  Future<void> _saveCurrentCart() async {
    if (_savingCurrentCart) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장할 상품이 없어요')));
      return;
    }

    setState(() => _savingCurrentCart = true);

    try {
      final session = AuthStore.instance.session.value;
      if (session?.isGuest == true) {
        await AdMobService.instance.showGuestSaveInterstitial();
      }

      final savedItems = items
          .map(
            (e) => SavedCartItem(
              name: e.name,
              price: e.price,
              quantity: e.quantity,
            ),
          )
          .toList();

      final savedCart = await CartStore.instance.saveNewCart(items: savedItems);
      if (!mounted) return;

      setState(() => items.clear());

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF1E8E3E)),
                      const SizedBox(width: 8),
                      Text(
                        AppRuntimeCopy.text([
                          'saveComplete',
                          'title',
                        ], '카트를 저장했어요'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${savedCart.totalCount}개 상품 · ₩${formatPrice(savedCart.totalPrice)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppRuntimeCopy.text([
                      'saveComplete',
                      'subtitle',
                    ], '다음 결제 전에 다시 볼 수 있어.'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InlinePromoSlot(
                    slotKey: 'save_complete_sheet_1',
                    title: AppRuntimeCopy.text([
                      'saveComplete',
                      'adFallbackTitle',
                    ], '더 저렴한 대안 보기'),
                    message: AppRuntimeCopy.text([
                      'saveComplete',
                      'adFallbackMessage',
                    ], '결제 전에 더 나은 선택을 추천해.'),
                    height: 88,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            AppRuntimeCopy.text([
                              'home',
                              'continueScanAction',
                            ], '계속 스캔하기'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE31837),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _tabIndex = 1);
                          },
                          child: Text(
                            AppRuntimeCopy.text([
                              'home',
                              'recentSavedAction',
                            ], 'Saved 보기'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _savingCurrentCart = false);
      }
    }
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 1:
        return const SavedTabView();
      case 2:
        return const MyPage();
      case 0:
      default:
        return HomeTabView(
          cameras: _cameras,
          scanRepository: _scanRepository,
          items: items,
          recentScans: recentScans,
          onRecognized: _recordRecentScan,
          onAdd: (item) {
            setState(() {
              items.insert(0, CartItem(name: item.name, price: item.price));
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = AppConfigStore.instance.branding.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_tabIndex == 0)
            TotalBar(
              totalPrice: totalPrice,
              onSave: _saveCurrentCart,
              isSaving: _savingCurrentCart,
            ),
          NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) => setState(() => _tabIndex = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: branding.homeTabLabel,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bookmark_border),
                selectedIcon: const Icon(Icons.bookmark),
                label: branding.savedTabLabel,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: branding.myTabLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeTabView extends StatelessWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final void Function(RecognizedItem item) onRecognized;
  final void Function(RecognizedItem item) onAdd;

  const HomeTabView({
    super.key,
    required this.cameras,
    required this.scanRepository,
    required this.items,
    required this.recentScans,
    required this.onRecognized,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text(
          AppRuntimeCopy.text(['home', 'pageTitle'], 'Cartly'),
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
            height: 0.95,
            color: Color(0xFFE31837),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppRuntimeCopy.text(['home', 'subtitle'], '지금 카트 총액을 확인해'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: AppRuntimeCopy.text(['home', 'addSectionTitle'], '새 상품 추가'),
          subtitle: AppRuntimeCopy.text([
            'home',
            'addSectionSubtitle',
          ], '스캔하거나 바로 담기'),
        ),
        const SizedBox(height: 10),
        ItemAddSection(
          key: const ValueKey('home-item-add-section'),
          cameras: cameras,
          scanRepository: scanRepository,
          onRecognized: onRecognized,
          onAdd: (item) {
            onAdd(item);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppRuntimeCopy.text([
                    'home',
                    'addToCurrentCartDone',
                  ], '현재 카트에 담았어요'),
                ),
              ),
            );
          },
          addButtonText: AppRuntimeCopy.text([
            'home',
            'addToCurrentCartButton',
          ], '현재 카트에 담기'),
        ),
        if (recentScans.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(
            title: AppRuntimeCopy.text(['home', 'recentScanTitle'], '최근 스캔'),
            subtitle: AppRuntimeCopy.text([
              'home',
              'recentScanSubtitle',
            ], '방금 읽은 결과'),
          ),
          const SizedBox(height: 10),
          ...recentScans.take(3).map((entry) => _RecentScanCard(entry: entry)),
        ],
        const SizedBox(height: 20),
        _SectionHeader(
          title: AppRuntimeCopy.text(['home', 'currentCartTitle'], '현재 카트'),
          subtitle: AppRuntimeCopy.text([
            'home',
            'currentCartSubtitle',
          ], '결제 전 합계를 확인해'),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.28,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Opacity(
                    opacity: 0.14,
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppRuntimeCopy.text([
                      'home',
                      'currentCartEmpty',
                    ], '아직 담은 상품이 없어요'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...items.map((item) {
          return Dismissible(
            key: ValueKey('${item.name}-${item.price}-${item.hashCode}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => items.remove(item),
            child: ItemCard(item: item),
          );
        }),
        const SizedBox(height: 20),
        ValueListenableBuilder<List<SavedCart>>(
          valueListenable: CartStore.instance.carts,
          builder: (context, carts, _) {
            return _RecentSavedPreviewCard(
              cart: carts.isEmpty ? null : carts.first,
            );
          },
        ),
      ],
    );
  }
}

class SavedTabView extends StatelessWidget {
  const SavedTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedCart>>(
      valueListenable: CartStore.instance.carts,
      builder: (context, carts, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Text(
              AppRuntimeCopy.text(['saved', 'pageTitle'], 'Saved carts'),
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                height: 0.95,
                color: Color(0xFFE31837),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppRuntimeCopy.text(['saved', 'subtitle'], '저장한 카트를 다시 봐'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const _AudienceBannerSlot(
              showForGuests: true,
              showForMembers: true,
            ),
            if (carts.isNotEmpty) const SizedBox(height: 8),
            if (carts.isEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: 0.16,
                        child: Icon(Icons.bookmark_border, size: 72),
                      ),
                      SizedBox(height: 14),
                      Text(
                        AppRuntimeCopy.text([
                          'saved',
                          'emptyTitle',
                        ], '아직 저장된 카트가 없어요'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        AppRuntimeCopy.text([
                          'saved',
                          'emptyBody',
                        ], 'Home에서 저장하면 여기서 다시 볼 수 있어.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(carts.length, (index) {
                final cart = carts[index];
                return Column(
                  children: [
                    _SavedCartListCard(
                      cart: cart,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CartDetailPage(cart: cart),
                          ),
                        );
                      },
                    ),
                    if (index == 0)
                      _InlinePromoSlot(
                        slotKey: 'saved_inline_1',
                        title: AppRuntimeCopy.text([
                          'saved',
                          'adFallbackTitle',
                        ], '오늘의 혜택 추천'),
                        message: AppRuntimeCopy.text([
                          'saved',
                          'adFallbackMessage',
                        ], '저장 카트 확인을 방해하지 않는 위치에 작고 자연스러운 혜택 슬롯을 둬요.'),
                        height: 104,
                      ),
                    if (index == 2)
                      _InlinePromoSlot(
                        slotKey: 'saved_inline_2',
                        title: AppRuntimeCopy.text([
                          'saved',
                          'adSecondaryFallbackTitle',
                        ], '비슷한 상품 프로모션'),
                        message: AppRuntimeCopy.text([
                          'saved',
                          'adSecondaryFallbackMessage',
                        ], '히스토리를 보는 흐름은 유지하고, 목록 사이에만 낮은 밀도로 노출해요.'),
                        height: 104,
                      ),
                  ],
                );
              }),
          ],
        );
      },
    );
  }
}

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text(
          AppRuntimeCopy.text(['my', 'pageTitle'], 'My account'),
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 0.95,
            color: Color(0xFFE31837),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppRuntimeCopy.text(['my', 'subtitle'], '기록을 남기려면 로그인'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder(
          valueListenable: AuthStore.instance.session,
          builder: (context, session, _) {
            final memberSignedIn = session != null && !session.isGuest;
            final isGuestMode = session?.isGuest == true;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ValueListenableBuilder(
                valueListenable: CartStore.instance.carts,
                builder: (context, carts, _) {
                  final cartCount = carts.length;
                  if (memberSignedIn) {
                    final displayName = session.displayName.trim().isNotEmpty
                        ? session.displayName.trim()
                        : session.badgeLabel;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _ContextPill(
                              label: '회원 계정',
                              color: Colors.black,
                            ),
                            const SizedBox(width: 8),
                            _ContextPill(
                              label: '카트 $cartCount개',
                              color: const Color(0xFF475569),
                              background: const Color(0xFFF1F5F9),
                            ),
                          ],
                        ),
                        if (session.email.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            session.email,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              await AuthStore.instance.signOut();
                              await CartStore.instance.refreshForCurrentSession();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppRuntimeCopy.text([
                                        'my',
                                        'logoutDoneMessage',
                                      ], '로그아웃했어요'),
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              AppRuntimeCopy.text([
                                'my',
                                'logoutAction',
                              ], '로그아웃'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuestMode
                            ? ((session?.displayName.trim().isNotEmpty ?? false)
                                  ? session!.displayName
                                  : 'Guest')
                            : AppRuntimeCopy.text([
                                'my',
                                'guestModeLabel',
                              ], '게스트로 사용 중이에요'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppRuntimeCopy.text([
                          'my',
                          'guestBody',
                        ], '저장과 기록을 이어가려면 로그인'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ContextPill(
                            label: isGuestMode ? '게스트' : '비로그인',
                            color: const Color(0xFFE31837),
                          ),
                          _ContextPill(
                            label: '카트 $cartCount개',
                            color: const Color(0xFF475569),
                            background: const Color(0xFFF1F5F9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE31837),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LoginPage(preferSignup: isGuestMode),
                              ),
                            );
                            if (result == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppRuntimeCopy.text([
                                      'my',
                                      'linkedDoneMessage',
                                    ], '계정을 연결했어요'),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            isGuestMode
                                ? AppRuntimeCopy.text([
                                    'my',
                                    'guestSignupAction',
                                  ], '회원가입하기')
                                : AppRuntimeCopy.text([
                                    'my',
                                    'loginAction',
                                  ], '로그인 / 회원가입'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _InlinePromoSlot(
          slotKey: 'my_perks_inline_1',
          title: AppRuntimeCopy.text(['my', 'adFallbackTitle'], '회원 전용 혜택 예고'),
          message: AppRuntimeCopy.text([
            'my',
            'adFallbackMessage',
          ], 'My 화면에서는 계정 가치와 맞물린 부드러운 프로모션만 보여주는 게 좋아요.'),
          height: 96,
        ),
        ValueListenableBuilder(
          valueListenable: AuthStore.instance.session,
          builder: (context, session, _) {
            final memberSignedIn = session != null && !session.isGuest;
            if (memberSignedIn) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppRuntimeCopy.text(['my', 'benefitsTitle'], '계정이 있으면 좋은 점'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppRuntimeCopy.text([
                          'my',
                          'benefitsBody',
                        ], '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ContextPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;

  const _ContextPill({
    required this.label,
    required this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _RecentSavedPreviewCard extends StatelessWidget {
  final SavedCart? cart;

  const _RecentSavedPreviewCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    if (cart == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppRuntimeCopy.text(['saved', 'recentTitle'], '최근 저장 카트'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              AppRuntimeCopy.text([
                'saved',
                'recentEmptyBody',
              ], '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final dateText = DateFormat('M월 d일').format(cart!.createdAt);
    final title = (cart!.title ?? '').trim();
    final preview = cart!.items.take(2).map((e) => e.name).join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart!)));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty
                        ? AppRuntimeCopy.text(['saved', 'recentTitle'], '최근 저장 카트')
                        : title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                if (cart!.isExpired)
                  const _ContextPill(label: '만료됨', color: Color(0xFFE31837)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$dateText · ${cart!.totalCount}개 · ₩${formatPrice(cart!.totalPrice)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentScanCard extends StatelessWidget {
  final RecentScanEntry entry;

  const _RecentScanCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final confidence = item.confidence;
    final confidenceText = confidence == null
        ? AppRuntimeCopy.text(['scan', 'confidence', 'none'], '신뢰도 없음')
        : '${(confidence * 100).round()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₩${formatPrice(item.price)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${AppRuntimeCopy.text(['home', 'recentRecognizedPrefix'], '최근 인식')} · $confidenceText',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceBannerSlot extends StatelessWidget {
  final bool showForGuests;
  final bool showForMembers;

  const _AudienceBannerSlot({
    required this.showForGuests,
    required this.showForMembers,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSession?>(
      valueListenable: AuthStore.instance.session,
      builder: (context, session, _) {
        if (session == null) {
          return const SizedBox.shrink();
        }

        final showBanner = session.isGuest ? showForGuests : showForMembers;
        if (!showBanner) {
          return const SizedBox.shrink();
        }

        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Center(child: AdMobBannerSlot()),
        );
      },
    );
  }
}

class _InlinePromoSlot extends StatefulWidget {
  final String slotKey;
  final String title;
  final String message;
  final double height;

  const _InlinePromoSlot({
    required this.slotKey,
    required this.title,
    required this.message,
    required this.height,
  });

  @override
  State<_InlinePromoSlot> createState() => _InlinePromoSlotState();
}

class _InlinePromoSlotState extends State<_InlinePromoSlot> {
  String? _lastImpressionKey;

  void _maybeRecordImpression(AppAdSlot slot) {
    final campaignId = slot.config.campaignId?.trim();
    if (campaignId == null || campaignId.isEmpty || !slot.enabled) return;

    final impressionKey = '${slot.slotKey}:$campaignId';
    if (_lastImpressionKey == impressionKey) return;
    _lastImpressionKey = impressionKey;

    unawaited(
      AdTrackingService.instance.recordImpression(
        slot: slot,
        screenName: slot.config.screen ?? widget.slotKey,
      ),
    );
  }

  Future<void> _handleTap(AppAdSlot slot) async {
    final rawUrl = slot.config.targetUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    await AdTrackingService.instance.recordClick(
      slot: slot,
      screenName: slot.config.screen ?? widget.slotKey,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _resolveText(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : fallback;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppAdSlot>>(
      valueListenable: AppConfigStore.instance.adSlots,
      builder: (context, slots, child) {
        AppAdSlot? liveSlot;
        for (final slot in slots) {
          if (slot.slotKey == widget.slotKey) {
            liveSlot = slot;
            break;
          }
        }
        if (liveSlot != null && !liveSlot.enabled) {
          return const SizedBox.shrink();
        }

        if (liveSlot != null) {
          final trackedSlot = liveSlot;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _maybeRecordImpression(trackedSlot);
          });
        }

        final slotTitle = _resolveText(liveSlot?.config.title, widget.title);
        final slotMessage = _resolveText(liveSlot?.config.message, widget.message);
        final slotHeight = liveSlot?.config.maxHeight ?? widget.height;
        final ctaLabel = _resolveText(liveSlot?.config.ctaLabel, widget.slotKey);
        final imageUrl = liveSlot?.config.imageUrl?.trim();
        final hasTapAction = (liveSlot?.config.targetUrl?.trim().isNotEmpty ?? false);

        final card = Container(
          constraints: BoxConstraints(minHeight: slotHeight),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF4F5), Color(0xFFF7F9FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9E9E9)),
          ),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _PromoSlotIcon(hasTapAction: hasTapAction);
                    },
                  ),
                ),
              ] else ...[
                _PromoSlotIcon(hasTapAction: hasTapAction),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slotTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slotMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ctaLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: hasTapAction ? const Color(0xFFE31837) : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );

        if (!hasTapAction || liveSlot == null) {
          return card;
        }

        final tappableSlot = liveSlot;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleTap(tappableSlot),
          child: card,
        );
      },
    );
  }
}

class _PromoSlotIcon extends StatelessWidget {
  final bool hasTapAction;

  const _PromoSlotIcon({required this.hasTapAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFE31837).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        hasTapAction ? Icons.open_in_new : Icons.local_offer_outlined,
        color: const Color(0xFFE31837),
      ),
    );
  }
}

class _SavedCartListCard extends StatelessWidget {
  final SavedCart cart;
  final VoidCallback onTap;

  const _SavedCartListCard({required this.cart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy년 M월 d일').format(cart.createdAt);
    final title = (cart.title ?? '').trim();
    final preview = cart.items.take(2).map((e) => e.name).join(' · ');
    final expiryText = cart.expiresAt == null
        ? null
        : cart.isExpired
        ? '저장 기간 만료 · 광고 보고 14일 연장 가능'
        : '게스트 저장 ${DateFormat('M/d').format(cart.expiresAt!)}까지';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? dateText : title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (cart.isExpired)
                        const _ContextPill(label: '만료됨', color: Color(0xFFE31837)),
                    ],
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${cart.totalCount}개 · ₩${formatPrice(cart.totalPrice)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  if (expiryText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      expiryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cart.isExpired ? const Color(0xFFE31837) : Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class ItemCard extends StatefulWidget {
  final CartItem item;

  const ItemCard({super.key, required this.item});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  void increase() => setState(() => widget.item.quantity++);

  void decrease() {
    if (widget.item.quantity > 1) {
      setState(() => widget.item.quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.remove), onPressed: decrease),
              Text('${item.quantity}'),
              IconButton(icon: const Icon(Icons.add), onPressed: increase),
              const SizedBox(width: 8),
              Text(
                '₩${formatPrice(item.totalPrice)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TotalBar extends StatelessWidget {
  final int totalPrice;
  final VoidCallback onSave;
  final bool isSaving;

  const TotalBar({
    super.key,
    required this.totalPrice,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE31837),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppRuntimeCopy.text(['home', 'cartTotalLabel'], '현재 카트 합계'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₩${formatPrice(totalPrice)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSaving ? null : onSave,
              child: Text(
                isSaving
                    ? AppRuntimeCopy.text(['common', 'loading'], '처리 중…')
                    : AppRuntimeCopy.text(['home', 'saveCartButton'], '카트 저장'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
