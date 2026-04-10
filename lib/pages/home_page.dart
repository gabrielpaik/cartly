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
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../services/remote_scan_repository.dart';
import '../services/scan_repository.dart';
import '../widgets/save_complete_bottom_sheet.dart';

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

      await showSaveCompleteBottomSheet(
        context: context,
        savedCart: savedCart,
        onViewSaved: () => setState(() => _tabIndex = 1),
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
