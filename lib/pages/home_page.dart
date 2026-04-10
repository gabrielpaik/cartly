import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app_support.dart';
import '../config/wimc_runtime_config.dart';
import '../models/recognized_item.dart';
import '../models/saved_cart.dart';
import '../pages/home_tab_view.dart';
import '../pages/my_page.dart';
import '../pages/saved_tab_view.dart';
import '../services/admob_service.dart';
import '../services/app_config_store.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../services/remote_scan_repository.dart';
import '../services/scan_repository.dart';
import '../widgets/inline_promo_slot.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

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
                  InlinePromoSlot(
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
          cameras: widget.cameras,
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
