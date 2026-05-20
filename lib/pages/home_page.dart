import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/app_ad_slot.dart';
import '../models/recognized_item.dart';
import '../config/cartly_runtime_config.dart';
import '../pages/home_page_cart_controller.dart';
import '../pages/home_page_cart_save_controller.dart';
import '../pages/home_tab_view.dart';
import '../pages/login_page.dart';
import '../pages/saved_tab_view.dart';
import '../services/app_event_service.dart';
import '../services/app_navigation_service.dart';
import '../services/cart_title_suggester.dart';
import '../services/current_cart_store.dart';
import '../pages/my_page.dart';
import '../pages/shopping_help_page.dart';
import '../services/app_attention_service.dart';
import '../services/app_config_store.dart';
import '../services/auth_store.dart';
import '../services/push_navigation_service.dart';
import '../services/household_store.dart';
import '../services/remote_current_cart_repository.dart';
import '../services/remote_scan_repository.dart';
import '../services/scan_repository.dart';
import '../services/shopping_nudge_service.dart';
import '../widgets/total_bar.dart';
import '../widgets/cartly_symbol_icon.dart';
import '../widgets/home_floating_promo_slot.dart';
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
  final List<ConsideredProductEntry> consideredItems = [];
  int _tabIndex = 0;
  bool _savingCurrentCart = false;
  bool _showHomeDot = false;
  bool _showExploreDot = false;
  bool? _exploreShoppingModeOverride;
  String? _loadedCurrentCartOwnerId;
  Timer? _sharedCurrentCartPollTimer;
  bool _sharedCurrentCartEnabled = false;
  bool _hasHouseholdLink = false;
  int _sharedCurrentCartSyncDepth = 0;
  DateTime? _lastSharedCurrentCartMutationAt;

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
  late final RemoteCurrentCartRepository _remoteCurrentCartRepository =
      RemoteCurrentCartRepository();
  late final HomePageCartController _cartController = HomePageCartController(
    items: items,
    recentScans: recentScans,
    consideredItems: consideredItems,
    setState: setState,
    onStateChanged: _persistCurrentCartState,
  );

  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);
  bool get _hasActiveShoppingContext =>
      items.isNotEmpty || recentScans.isNotEmpty;
  bool get _showExploreShoppingMode =>
      _exploreShoppingModeOverride ?? _hasActiveShoppingContext;

  String _exploreTabLabel(String fallback) {
    return _showExploreShoppingMode ? '지금 장보는중!' : fallback;
  }

  void _normalizeExploreModeOverride() {
    if (_hasActiveShoppingContext || _exploreShoppingModeOverride == null) {
      return;
    }
    setState(() {
      _exploreShoppingModeOverride = null;
    });
  }

  void _setExploreShoppingMode(bool enabled) {
    setState(() {
      _exploreShoppingModeOverride = enabled;
    });
  }

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
      openAccountSettings: _openAccountSettingsPage,
    );
    unawaited(_restoreCurrentCartState());
    unawaited(_bootstrapVisitorSession());
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
    _sharedCurrentCartPollTimer?.cancel();
    super.dispose();
  }

  String get _currentCartOwnerId => AuthStore.instance.session.value?.id ?? '';

  Future<void> _restoreCurrentCartState() async {
    final ownerId = _currentCartOwnerId;
    final snapshot = await CurrentCartStore.instance.loadPersonal();
    final preferredMode = await CurrentCartStore.instance.loadMode();
    var sharedEnabled = preferredMode == CurrentCartMode.shared;
    var hasHouseholdLink = false;
    List<CartItem> nextItems = snapshot.items;
    final session = AuthStore.instance.session.value;
    if (session != null &&
        !session.isGuest &&
        session.authToken.trim().isNotEmpty) {
      try {
        final sharedSnapshot = await _remoteCurrentCartRepository
            .getCurrentCart(session.authToken);
        hasHouseholdLink = sharedSnapshot.shared;
        if (sharedSnapshot.shared && preferredMode == CurrentCartMode.shared) {
          sharedEnabled = true;
          nextItems = sharedSnapshot.items;
        } else {
          sharedEnabled = false;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      items
        ..clear()
        ..addAll(nextItems);
      recentScans
        ..clear()
        ..addAll(snapshot.recentScans);
      consideredItems
        ..clear()
        ..addAll(snapshot.consideredItems);
      _loadedCurrentCartOwnerId = ownerId;
      _sharedCurrentCartEnabled = sharedEnabled;
      _hasHouseholdLink = hasHouseholdLink;
    });
    _restartSharedCurrentCartPolling();
    _persistCurrentCartState();
    _refreshShoppingNudge();
  }

  void _persistCurrentCartState() {
    if (_sharedCurrentCartEnabled) {
      return;
    }
    unawaited(
      CurrentCartStore.instance.savePersonal(
        items: items,
        recentScans: recentScans,
        consideredItems: consideredItems,
      ),
    );
  }

  void _restartSharedCurrentCartPolling() {
    _sharedCurrentCartPollTimer?.cancel();
    if (!_sharedCurrentCartEnabled) return;
    _sharedCurrentCartPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshSharedCurrentCart()),
    );
  }

  void _applySharedCurrentCartItems(List<CartItem> nextItems) {
    if (_sameCurrentCartItems(items, nextItems)) {
      return;
    }
    setState(() {
      items
        ..clear()
        ..addAll(nextItems);
    });
    _persistCurrentCartState();
    _refreshShoppingNudge();
  }

  bool get _shouldPauseSharedCurrentCartPolling {
    if (_sharedCurrentCartSyncDepth > 0) {
      return true;
    }
    final lastMutationAt = _lastSharedCurrentCartMutationAt;
    if (lastMutationAt == null) {
      return false;
    }
    return DateTime.now().difference(lastMutationAt) <
        const Duration(seconds: 3);
  }

  Future<void> _refreshSharedCurrentCart() async {
    if (!_sharedCurrentCartEnabled || _shouldPauseSharedCurrentCartPolling) {
      return;
    }
    final session = AuthStore.instance.session.value;
    if (session == null ||
        session.isGuest ||
        session.authToken.trim().isEmpty) {
      return;
    }
    try {
      final sharedSnapshot = await _remoteCurrentCartRepository.getCurrentCart(
        session.authToken,
      );
      if (!mounted || !sharedSnapshot.shared) return;
      _applySharedCurrentCartItems(sharedSnapshot.items);
    } catch (_) {}
  }

  bool _sameCurrentCartItems(List<CartItem> a, List<CartItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i].id != b[i].id ||
          a[i].name != b[i].name ||
          a[i].price != b[i].price ||
          a[i].quantity != b[i].quantity ||
          a[i].source != b[i].source ||
          a[i].scanJobId != b[i].scanJobId ||
          a[i].originalRecognizedName != b[i].originalRecognizedName) {
        return false;
      }
    }
    return true;
  }

  Future<void> _syncSharedItemAdd(CartItem item) async {
    final session = AuthStore.instance.session.value;
    if (!_sharedCurrentCartEnabled ||
        session == null ||
        session.authToken.trim().isEmpty) {
      return;
    }
    _sharedCurrentCartSyncDepth += 1;
    _lastSharedCurrentCartMutationAt = DateTime.now();
    try {
      final snapshot = await _remoteCurrentCartRepository.addItem(
        session.authToken,
        item,
      );
      if (!mounted || !snapshot.shared) return;
      _applySharedCurrentCartItems(snapshot.items);
    } catch (_) {
    } finally {
      _sharedCurrentCartSyncDepth -= 1;
    }
  }

  Future<void> _syncSharedItemUpdate(CartItem item) async {
    final session = AuthStore.instance.session.value;
    if (!_sharedCurrentCartEnabled ||
        session == null ||
        session.authToken.trim().isEmpty) {
      return;
    }
    _sharedCurrentCartSyncDepth += 1;
    _lastSharedCurrentCartMutationAt = DateTime.now();
    try {
      final snapshot = await _remoteCurrentCartRepository.updateItem(
        session.authToken,
        item,
      );
      if (!mounted || !snapshot.shared) return;
      _applySharedCurrentCartItems(snapshot.items);
    } catch (_) {
    } finally {
      _sharedCurrentCartSyncDepth -= 1;
    }
  }

  Future<void> _syncSharedItemDelete(CartItem item) async {
    final session = AuthStore.instance.session.value;
    if (!_sharedCurrentCartEnabled ||
        session == null ||
        session.authToken.trim().isEmpty) {
      return;
    }
    _sharedCurrentCartSyncDepth += 1;
    _lastSharedCurrentCartMutationAt = DateTime.now();
    try {
      final snapshot = await _remoteCurrentCartRepository.deleteItem(
        session.authToken,
        item.id,
      );
      if (!mounted || !snapshot.shared) return;
      _applySharedCurrentCartItems(snapshot.items);
    } catch (_) {
    } finally {
      _sharedCurrentCartSyncDepth -= 1;
    }
  }

  Future<void> _clearSharedCurrentCartIfNeeded() async {
    final session = AuthStore.instance.session.value;
    if (!_sharedCurrentCartEnabled ||
        session == null ||
        session.authToken.trim().isEmpty) {
      return;
    }
    _sharedCurrentCartSyncDepth += 1;
    _lastSharedCurrentCartMutationAt = DateTime.now();
    try {
      final snapshot = await _remoteCurrentCartRepository.clear(
        session.authToken,
      );
      if (!mounted || !snapshot.shared) return;
      _applySharedCurrentCartItems(snapshot.items);
    } catch (_) {
    } finally {
      _sharedCurrentCartSyncDepth -= 1;
    }
  }

  Future<void> _bootstrapVisitorSession() async {
    final session = await AuthStore.instance.ensureGuestSession();
    if (session == null || session.authToken.trim().isEmpty) {
      return;
    }
    await AppEventService.instance.track(
      'app_open',
      screen: 'home',
      onceKey: 'app_open/home',
      props: {'userType': session.isGuest ? 'guest' : 'member'},
    );
  }

  void _handleSessionChanged() {
    final nextOwnerId = _currentCartOwnerId;
    HouseholdStore.instance.clear();
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
      unawaited(_restoreCurrentCartState());
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
    _normalizeExploreModeOverride();
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
    unawaited(_syncSharedItemDelete(item));
    _markExploreAttention();
    _refreshShoppingNudge();
  }

  void _handleChangeCartItem(CartItem item) {
    setState(() {});
    _persistCurrentCartState();
    unawaited(_syncSharedItemUpdate(item));
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
      MaterialPageRoute(builder: (_) => LoginPage(preferSignup: preferSignup)),
    );
  }

  Future<void> _openAccountSettingsPage() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsAndHouseholdPage()));
  }

  Future<void> _showSignupPrompt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원가입이 필요해요'),
        content: const Text('가족과 현재 카트를 함께 쓰려면 먼저 회원가입이 필요해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('회원가입하기'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _openLoginPage(preferSignup: true);
    }
  }

  Future<bool> _refreshHouseholdState() async {
    final session = AuthStore.instance.session.value;
    if (session == null ||
        session.isGuest ||
        session.authToken.trim().isEmpty) {
      if (mounted) {
        setState(() => _hasHouseholdLink = false);
      }
      return false;
    }
    try {
      await HouseholdStore.instance.refresh();
      final hasHousehold = HouseholdStore.instance.state.value.hasHousehold;
      if (mounted) {
        setState(() => _hasHouseholdLink = hasHousehold);
      }
      return hasHousehold;
    } catch (_) {
      return _hasHouseholdLink;
    }
  }

  Future<void> _switchCurrentCartMode(CurrentCartMode mode) async {
    final previousMode = _sharedCurrentCartEnabled
        ? CurrentCartMode.shared
        : CurrentCartMode.personal;
    if (previousMode == mode) return;

    if (mode == CurrentCartMode.shared) {
      final session = AuthStore.instance.session.value;
      if (session == null || session.authToken.trim().isEmpty) return;
      try {
        final sharedSnapshot = await _remoteCurrentCartRepository
            .getCurrentCart(session.authToken);
        if (!mounted) return;
        setState(() {
          _sharedCurrentCartEnabled = true;
          _hasHouseholdLink = sharedSnapshot.shared;
          items
            ..clear()
            ..addAll(sharedSnapshot.items);
        });
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
        return;
      }
      _restartSharedCurrentCartPolling();
    } else {
      final personalSnapshot = await CurrentCartStore.instance.loadPersonal();
      if (!mounted) return;
      setState(() {
        _sharedCurrentCartEnabled = false;
        items
          ..clear()
          ..addAll(personalSnapshot.items);
        recentScans
          ..clear()
          ..addAll(personalSnapshot.recentScans);
        consideredItems
          ..clear()
          ..addAll(personalSnapshot.consideredItems);
      });
      _restartSharedCurrentCartPolling();
      _refreshShoppingNudge();
    }

    await CurrentCartStore.instance.saveMode(mode);
    _refreshShoppingNudge();
  }

  Future<void> _handleCurrentCartModeTap(CurrentCartMode targetMode) async {
    final currentMode = _sharedCurrentCartEnabled
        ? CurrentCartMode.shared
        : CurrentCartMode.personal;
    if (currentMode == targetMode) {
      return;
    }

    final session = AuthStore.instance.session.value;
    if (session == null || session.isGuest) {
      await _showSignupPrompt();
      return;
    }

    final hasHousehold = await _refreshHouseholdState();
    if (!hasHousehold) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsAndHouseholdPage()),
      );
      await _refreshHouseholdState();
      return;
    }

    if (!mounted) return;
    await _switchCurrentCartMode(targetMode);
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
      await _clearSharedCurrentCartIfNeeded();
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
      final added = _cartController.addRecognizedItem(
        item,
        recentScanEntryId: recentScanEntryId,
      );
      await _syncSharedItemAdd(added);
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
        final updated = _cartController.increaseMatchingCartItem(
          duplicate,
          item,
          recentScanEntryId: recentScanEntryId,
        );
        unawaited(_syncSharedItemUpdate(updated));
        _markExploreAttention();
        _refreshShoppingNudge();
        return true;
      case _DuplicateAddChoice.addAsNew:
        final added = _cartController.addRecognizedItem(
          item,
          recentScanEntryId: recentScanEntryId,
        );
        unawaited(_syncSharedItemAdd(added));
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
          isSharedCurrentCartMode: _sharedCurrentCartEnabled,
          onPersonalCurrentCartTap: () =>
              _handleCurrentCartModeTap(CurrentCartMode.personal),
          onSharedCurrentCartTap: () =>
              _handleCurrentCartModeTap(CurrentCartMode.shared),
        ),
        ShoppingHelpPage(
          items: items,
          recentScans: recentScans,
          consideredItems: consideredItems,
          shoppingModeOverride: _exploreShoppingModeOverride,
          onUseDefaultExploreMode: _hasActiveShoppingContext
              ? () => _setExploreShoppingMode(false)
              : null,
          onUseShoppingMode:
              _hasActiveShoppingContext && !_showExploreShoppingMode
              ? () => _setExploreShoppingMode(true)
              : null,
          onGoHome: () => _selectTab(0),
          onGoSaved: _openSavedCartsList,
        ),
        const MyPage(),
      ],
    );
  }

  Widget _buildScaffoldBody() {
    final body = _buildBody();
    final showImmersiveExploreHeader =
        _tabIndex == 1 && _showExploreShoppingMode;
    final scaffoldBody = showImmersiveExploreHeader
        ? body
        : SafeArea(top: true, bottom: false, child: body);

    if (_tabIndex != 0) {
      return scaffoldBody;
    }

    return Stack(
      children: [
        scaffoldBody,
        ValueListenableBuilder<List<AppAdSlot>>(
          valueListenable: AppConfigStore.instance.adSlots,
          builder: (context, slots, child) {
            final slot = AppConfigStore.instance.slotByKey('home_floating_1');
            if (slot == null || !slot.enabled) {
              return const SizedBox.shrink();
            }
            final bottomOffset = (_tabIndex == 0 ? 78.0 + 72.0 : 78.0) + 12.0;
            return HomeFloatingPromoSlot(
              slotKey: slot.slotKey,
              delay: Duration(milliseconds: slot.config.showDelayMs),
              bottomOffset: bottomOffset,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = AppConfigStore.instance.branding.value;

    return Scaffold(
      backgroundColor: CartlyColors.surface0,
      body: _buildScaffoldBody(),
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
                label: _exploreTabLabel(branding.helpTabLabel),
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
      backgroundColor: CartlyColors.surface0,
      appBar: AppBar(title: const Text('지난 카트')),
      body: const SafeArea(child: SavedTabView()),
    );
  }
}

enum _DuplicateAddChoice { mergeQuantity, addAsNew }
