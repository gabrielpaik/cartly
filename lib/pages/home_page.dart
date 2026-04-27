import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';
import '../config/cartly_runtime_config.dart';
import '../pages/home_page_cart_controller.dart';
import '../pages/home_page_cart_save_controller.dart';
import '../pages/home_tab_view.dart';
import '../services/cart_title_suggester.dart';
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

    final suggestion = await CartTitleSuggester.suggest(items);
    if (!mounted) return;

    final title = await _promptForCartTitle(suggestion);
    if (!mounted || title == null) return;

    setState(() => _savingCurrentCart = true);

    try {
      final savedCart = await HomePageCartSaveController.saveCart(
        items,
        title: title,
      );
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

  Future<String?> _promptForCartTitle(CartTitleSuggestion suggestion) async {
    final controller = TextEditingController(text: suggestion.suggestedTitle);
    try {
      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '카트 이름 정하기',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    suggestion.subtitle ?? '저장할 카트 이름을 확인해 주세요.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '카트 이름',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      final title = controller.text.trim();
                      Navigator.of(sheetContext).pop(
                        title.isEmpty ? suggestion.suggestedTitle : title,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE31837),
                          ),
                          onPressed: () {
                            final title = controller.text.trim();
                            Navigator.of(sheetContext).pop(
                              title.isEmpty ? suggestion.suggestedTitle : title,
                            );
                          },
                          child: const Text('이 이름으로 저장'),
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
      controller.dispose();
    }
  }

  Future<bool> _addRecognizedItemWithChoice(
    RecognizedItem item, {
    String? recentScanEntryId,
  }) async {
    final duplicate = _cartController.findDuplicateCartItem(item);
    if (duplicate == null) {
      _cartController.addRecognizedItem(item, recentScanEntryId: recentScanEntryId);
      return true;
    }

    final choice = await showModalBottomSheet<_DuplicateAddChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '같은 상품이 이미 있어요',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₩${formatPrice(item.price)} · 현재 수량 ${duplicate.quantity}개',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_DuplicateAddChoice.mergeQuantity),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFFE31837),
                  ),
                  child: const Text('수량만 +1 할게요'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_DuplicateAddChoice.addAsNew),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('새 상품으로 따로 넣기'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return false;

    switch (choice) {
      case _DuplicateAddChoice.mergeQuantity:
        _cartController.increaseMatchingCartItem(
          duplicate,
          item,
          recentScanEntryId: recentScanEntryId,
        );
        return true;
      case _DuplicateAddChoice.addAsNew:
        _cartController.addRecognizedItem(item, recentScanEntryId: recentScanEntryId);
        return true;
    }
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _tabIndex,
      children: [
        HomeTabView(
          cameras: widget.cameras,
          scanRepository: _scanRepository,
          items: items,
          recentScans: recentScans,
          onRecognized: _cartController.recordRecentScan,
          onAdd: _addRecognizedItemWithChoice,
          onDismissRecognized: _cartController.dismissRecognizedItem,
          onAddRecentScan: (entry) => _addRecognizedItemWithChoice(
            entry.item,
            recentScanEntryId: entry.id,
          ),
          onDismissRecentScan: _cartController.dismissRecentScan,
          onRemove: _cartController.removeCartItem,
        ),
        ShoppingHelpPage(
          items: items,
          recentScans: recentScans,
          onGoHome: () => setState(() => _tabIndex = 0),
          onGoSaved: () => setState(() => _tabIndex = 2),
        ),
        const MyPage(),
      ],
    );
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

enum _DuplicateAddChoice { mergeQuantity, addAsNew }
