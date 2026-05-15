import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';
import '../config/cartly_runtime_config.dart';
import '../pages/home_page_cart_controller.dart';
import '../pages/home_page_cart_save_controller.dart';
import '../pages/home_tab_view.dart';
import '../pages/login_page.dart';
import '../pages/saved_tab_view.dart';
import '../services/app_navigation_service.dart';
import '../services/cart_title_suggester.dart';
import '../services/current_cart_store.dart';
import '../pages/my_page.dart';
import '../pages/shopping_help_page.dart';
import '../services/app_attention_service.dart';
import '../services/app_config_store.dart';
import '../services/auth_store.dart';
import '../services/push_navigation_service.dart';
import '../services/remote_scan_repository.dart';
import '../services/scan_repository.dart';
import '../services/shopping_nudge_service.dart';
import '../widgets/total_bar.dart';
import '../widgets/cartly_symbol_icon.dart';
import '../app/cartly_ui.dart';

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
  bool _showHomeDot = false;
  bool _showExploreDot = false;
  String? _loadedCurrentCartOwnerId;

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
    onStateChanged: _persistCurrentCartState,
  );

  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  void initState() {
    super.initState();
    AppAttentionService.instance.home.addListener(_syncAttentionDots);
    AppAttentionService.instance.explore.addListener(_syncAttentionDots);
    PushNavigationService.instance.pendingTargetTab.addListener(
      _handlePendingTargetTab,
    );
    AuthStore.instance.session.addListener(_handleSessionChanged);
    AppNavigationService.instance.bind(
      selectTab: _selectTab,
      openSaved: _openSavedCartsList,
      openLogin: _openLoginPage,
    );
    unawaited(_restoreCurrentCartState());
    _syncAttentionDots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingTargetTab();
    });
  }

  @override
  void dispose() {
    AppAttentionService.instance.home.removeListener(_syncAttentionDots);
    AppAttentionService.instance.explore.removeListener(_syncAttentionDots);
    PushNavigationService.instance.pendingTargetTab.removeListener(
      _handlePendingTargetTab,
    );
    AuthStore.instance.session.removeListener(_handleSessionChanged);
    AppNavigationService.instance.unbind();
    super.dispose();
  }

  String get _currentCartOwnerId => AuthStore.instance.session.value?.id ?? '';

  Future<void> _restoreCurrentCartState() async {
    final ownerId = _currentCartOwnerId;
    final snapshot = await CurrentCartStore.instance.load();
    if (!mounted) return;
    setState(() {
      items
        ..clear()
        ..addAll(snapshot.items);
      recentScans
        ..clear()
        ..addAll(snapshot.recentScans);
      _loadedCurrentCartOwnerId = ownerId;
    });
    _refreshShoppingNudge();
  }

  void _persistCurrentCartState() {
    unawaited(
      CurrentCartStore.instance.save(items: items, recentScans: recentScans),
    );
  }

  void _handleSessionChanged() {
    final nextOwnerId = _currentCartOwnerId;
    if (_loadedCurrentCartOwnerId == nextOwnerId) {
      return;
    }
    unawaited(_restoreCurrentCartState());
  }

  void _syncAttentionDots() {
    if (!mounted) return;
    final nextHomeDot =
        AppAttentionService.instance.home.value && _tabIndex != 0;
    final nextExploreDot =
        AppAttentionService.instance.explore.value && _tabIndex != 1;
    if (_showHomeDot == nextHomeDot && _showExploreDot == nextExploreDot) {
      return;
    }
    setState(() {
      _showHomeDot = nextHomeDot;
      _showExploreDot = nextExploreDot;
    });
  }

  void _handlePendingTargetTab() {
    final targetTab = PushNavigationService.instance.consumePendingTargetTab();
    if (targetTab == null) return;
    switch (targetTab) {
      case 'home':
        _selectTab(0);
        return;
      case 'explore':
        _selectTab(1);
        return;
      case 'my':
        _selectTab(2);
        return;
    }
  }

  void _markHomeAttention() {
    if (_tabIndex == 0) return;
    unawaited(AppAttentionService.instance.markHome());
  }

  void _markExploreAttention() {
    if (_tabIndex == 1) return;
    unawaited(AppAttentionService.instance.markExplore());
  }

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
      if (index == 0) {
        _showHomeDot = false;
      }
      if (index == 1) {
        _showExploreDot = false;
      }
    });
    if (index == 0) {
      unawaited(AppAttentionService.instance.clearHome());
      unawaited(ShoppingNudgeService.instance.acknowledgeReceiptReminder());
      unawaited(
        PushNavigationService.instance.clearSystemAttentionForTab('home'),
      );
    }
    if (index == 1) {
      unawaited(AppAttentionService.instance.clearExplore());
      unawaited(
        PushNavigationService.instance.clearSystemAttentionForTab('explore'),
      );
    }
    if (index == 2) {
      unawaited(
        PushNavigationService.instance.clearSystemAttentionForTab('my'),
      );
    }
  }

  void _refreshShoppingNudge() {
    unawaited(
      ShoppingNudgeService.instance.refreshReceiptReminder(
        hasPendingShoppingContext: items.isNotEmpty || recentScans.isNotEmpty,
      ),
    );
  }

  void _handleRecognized(RecognizedItem item) {
    _cartController.recordRecentScan(item);
    _markHomeAttention();
    _markExploreAttention();
    _refreshShoppingNudge();
  }

  void _handleDismissRecognized(RecognizedItem item) {
    _cartController.dismissRecognizedItem(item);
    _markExploreAttention();
    _refreshShoppingNudge();
  }

  void _handleDismissRecentScan(RecentScanEntry entry) {
    _cartController.dismissRecentScan(entry);
    _markExploreAttention();
    _refreshShoppingNudge();
  }

  void _handleRemoveCartItem(CartItem item) {
    _cartController.removeCartItem(item);
    _markExploreAttention();
    _refreshShoppingNudge();
  }

  void _handleChangeCartItem(CartItem item) {
    setState(() {});
    _persistCurrentCartState();
    _markExploreAttention();
    _refreshShoppingNudge();
  }

  Widget _navIcon(Widget icon, {required bool showDot}) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        children: [
          Center(child: SizedBox(width: 28, height: 28, child: icon)),
          if (showDot)
            Positioned(
              right: 1,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: CartlyColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: CartlyColors.surface0, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSavedCartsList() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _SavedCartsPage()));
  }

  Future<void> _openLoginPage({bool preferSignup = false}) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginPage(preferSignup: preferSignup),
      ),
    );
  }

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
      _markExploreAttention();
      _refreshShoppingNudge();

      await HomePageCartSaveController.showSaveCompleteSheet(
        context: context,
        savedCart: savedCart,
        onViewSaved: _openSavedCartsList,
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
                      Navigator.of(
                        sheetContext,
                      ).pop(title.isEmpty ? suggestion.suggestedTitle : title);
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
      _cartController.addRecognizedItem(
        item,
        recentScanEntryId: recentScanEntryId,
      );
      _markExploreAttention();
      _refreshShoppingNudge();
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
                  onPressed: () =>
                      Navigator.of(context).pop(_DuplicateAddChoice.addAsNew),
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
        _markExploreAttention();
        _refreshShoppingNudge();
        return true;
      case _DuplicateAddChoice.addAsNew:
        _cartController.addRecognizedItem(
          item,
          recentScanEntryId: recentScanEntryId,
        );
        _markExploreAttention();
        _refreshShoppingNudge();
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
          onRecognized: _handleRecognized,
          onAdd: _addRecognizedItemWithChoice,
          onDismissRecognized: _handleDismissRecognized,
          onAddRecentScan: (entry) => _addRecognizedItemWithChoice(
            entry.item,
            recentScanEntryId: entry.id,
          ),
          onDismissRecentScan: _handleDismissRecentScan,
          onRemove: _handleRemoveCartItem,
          onChangeCurrentCartItem: _handleChangeCartItem,
          onGoExplore: () => _selectTab(1),
        ),
        ShoppingHelpPage(
          items: items,
          recentScans: recentScans,
          onGoHome: () => _selectTab(0),
          onGoSaved: _openSavedCartsList,
        ),
        const MyPage(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = AppConfigStore.instance.branding.value;

    return Scaffold(
      backgroundColor: CartlyColors.surface0,
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
            onDestinationSelected: _selectTab,
            backgroundColor: CartlyColors.surface0,
            indicatorColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            height: 78,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CartlyColors.textPrimary,
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
                icon: _navIcon(
                  const CartlySymbolIcon.sf('cart', size: 28),
                  showDot: _showHomeDot,
                ),
                selectedIcon: _navIcon(
                  const CartlySymbolIcon.sf('cart.fill', size: 28),
                  showDot: _showHomeDot,
                ),
                label: branding.homeTabLabel,
              ),
              NavigationDestination(
                icon: _navIcon(
                  const CartlySymbolIcon.sf('magnifyingglass', size: 28),
                  showDot: _showExploreDot,
                ),
                selectedIcon: _navIcon(
                  const CartlySymbolIcon.sf(
                    'sparkle.magnifyingglass',
                    size: 28,
                  ),
                  showDot: _showExploreDot,
                ),
                label: branding.helpTabLabel,
              ),
              NavigationDestination(
                icon: _navIcon(
                  const CartlySymbolIcon.sf('person.crop.circle', size: 28),
                  showDot: false,
                ),
                selectedIcon: _navIcon(
                  const CartlySymbolIcon.sf(
                    'person.crop.circle.fill',
                    size: 28,
                  ),
                  showDot: false,
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

class _SavedCartsPage extends StatelessWidget {
  const _SavedCartsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('지난 카트')),
      body: const SafeArea(child: SavedTabView()),
    );
  }
}

enum _DuplicateAddChoice { mergeQuantity, addAsNew }
