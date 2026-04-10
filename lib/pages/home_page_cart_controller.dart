import 'package:flutter/foundation.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';

class HomePageCartController {
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final void Function(VoidCallback fn) _setState;

  HomePageCartController({
    required this.items,
    required this.recentScans,
    required void Function(VoidCallback fn) setState,
  }) : _setState = setState;

  void addRecognizedItem(RecognizedItem item) {
    _setState(() {
      items.insert(0, CartItem(name: item.name, price: item.price));
      recentScans.removeWhere(
        (entry) =>
            entry.item.name == item.name &&
            entry.item.price == item.price &&
            (entry.item.sku ?? '').trim() == (item.sku ?? '').trim(),
      );
    });
  }

  void removeCartItem(CartItem item) {
    _setState(() {
      items.remove(item);
    });
  }

  void clearItems() {
    _setState(items.clear);
  }

  void recordRecentScan(RecognizedItem item) {
    _setState(() {
      recentScans.insert(
        0,
        RecentScanEntry(item: item, createdAt: DateTime.now()),
      );
      if (recentScans.length > 10) {
        recentScans.removeRange(10, recentScans.length);
      }
    });
  }
}
