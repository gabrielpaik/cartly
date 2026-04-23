import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app_support.dart';
import '../config/cartly_runtime_config.dart';
import '../pages/home_page_cart_controller.dart';
import '../pages/home_page_cart_save_controller.dart';
import '../pages/home_tab_view.dart';
import '../pages/my_page.dart';
import '../pages/shopping_help_page.dart';
import '../services/app_config_store.dart';
import '../services/auth_store.dart';
import '../services/remote_scan_repository.dart';
import '../services/scan_repository.dart';
import '../widgets/total_bar.dart';

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
    baseUrl: CartlyRuntimeConfig.current.normalizedRemoteBaseUrl,
    authTokenProvider: () {
      final sessionToken = AuthStore.instance.session.value?.authToken.trim();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        return sessionToken;
      }
      return CartlyRuntimeConfig.current.effectiveRemoteAuthToken;
    },
  );
  late final HomePageCartController _cartController = HomePageCartController(
    items: items,
    recentScans: recentScans,
    setState: setState,
  );

  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

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
      final savedCart = await HomePageCartSaveController.saveCart(items);
      if (!mounted) return;

      _cartController.clearItems();

      await HomePageCartSaveController.showSaveCompleteSheet(
        context: context,
        savedCart: savedCart,
        onViewSaved: () => setState(() => _tabIndex = 2),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _savingCurrentCart = false);
      }
    }
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 1:
        return const ShoppingHelpPage();
      case 2:
        return const MyPage();
      case 0:
      default:
        return HomeTabView(
          cameras: widget.cameras,
          scanRepository: _scanRepository,
          items: items,
          recentScans: recentScans,
          onRecognized: _cartController.recordRecentScan,
          onAdd: _cartController.addRecognizedItem,
          onDismissRecognized: _cartController.dismissRecognizedItem,
          onAddRecentScan: _cartController.addRecentScanToCart,
          onDismissRecentScan: _cartController.dismissRecentScan,
          onRemove: _cartController.removeCartItem,
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
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: branding.helpTabLabel,
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
