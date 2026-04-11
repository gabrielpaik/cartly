import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/saved_cart.dart';
import '../services/admob_service.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../widgets/save_complete_bottom_sheet.dart';

class HomePageCartSaveController {
  const HomePageCartSaveController._();

  static Future<SavedCart> saveCart(List<CartItem> items) async {
    await _showGuestSaveInterstitialIfNeeded();
    return CartStore.instance.saveNewCart(items: _toSavedCartItems(items));
  }

  static Future<void> showSaveCompleteSheet({
    required BuildContext context,
    required SavedCart savedCart,
    required VoidCallback onViewSaved,
  }) {
    return showSaveCompleteBottomSheet(
      context: context,
      savedCart: savedCart,
      onViewSaved: onViewSaved,
    );
  }

  static Future<void> _showGuestSaveInterstitialIfNeeded() async {
    final session = AuthStore.instance.session.value;
    if (session?.isGuest == true) {
      await AdMobService.instance.showGuestSaveInterstitial();
    }
  }

  static List<SavedCartItem> _toSavedCartItems(List<CartItem> items) {
    return items
        .map(
          (item) => SavedCartItem(
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            source: item.source,
            scanResultId: item.scanJobId,
          ),
        )
        .toList();
  }
}
