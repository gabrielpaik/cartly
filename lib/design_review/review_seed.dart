import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_ad_slot.dart';
import '../models/app_branding.dart';
import '../models/saved_cart.dart';
import '../models/user_session.dart';
import '../services/app_config_store.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';

class ReviewSeed extends StatefulWidget {
  final AppBranding branding;
  final List<AppAdSlot> adSlots;
  final List<SavedCart> carts;
  final UserSession? session;
  final Widget child;

  const ReviewSeed({
    super.key,
    required this.branding,
    required this.adSlots,
    required this.carts,
    required this.session,
    required this.child,
  });

  @override
  State<ReviewSeed> createState() => _ReviewSeedState();
}

class _ReviewSeedState extends State<ReviewSeed> {
  late final AppBranding _previousBranding;
  late final List<AppAdSlot> _previousAdSlots;
  late final List<SavedCart> _previousCarts;
  late final UserSession? _previousSession;

  @override
  void initState() {
    super.initState();
    _previousBranding = AppConfigStore.instance.branding.value;
    _previousAdSlots = List<AppAdSlot>.from(
      AppConfigStore.instance.adSlots.value,
    );
    _previousCarts = List<SavedCart>.from(CartStore.instance.carts.value);
    _previousSession = AuthStore.instance.session.value;
    _applySeed();
  }

  @override
  void didUpdateWidget(covariant ReviewSeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branding != widget.branding ||
        oldWidget.session != widget.session ||
        !listEquals(oldWidget.adSlots, widget.adSlots) ||
        !listEquals(oldWidget.carts, widget.carts)) {
      _applySeed();
    }
  }

  @override
  void dispose() {
    AppConfigStore.instance.branding.value = _previousBranding;
    AppConfigStore.instance.adSlots.value = List.unmodifiable(_previousAdSlots);
    CartStore.instance.carts.value = List.unmodifiable(_previousCarts);
    AuthStore.instance.session.value = _previousSession;
    super.dispose();
  }

  void _applySeed() {
    AppConfigStore.instance.branding.value = widget.branding;
    AppConfigStore.instance.adSlots.value = List.unmodifiable(widget.adSlots);
    CartStore.instance.carts.value = List.unmodifiable(widget.carts);
    AuthStore.instance.session.value = widget.session;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
