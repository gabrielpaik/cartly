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

  void addRecognizedItem(RecognizedItem item, {String? recentScanEntryId}) {
    _setState(() {
      items.insert(
        0,
        CartItem(
          name: item.name,
          price: item.price,
          source: item.source,
          scanJobId: item.scanJobId,
        ),
      );
      final resolvedEntryId =
          recentScanEntryId ?? _recentScanEntryIdForItem(item);
      if (resolvedEntryId != null) {
        recentScans.removeWhere((entry) => entry.id == resolvedEntryId);
      }
    });
  }

  void dismissRecentScan(RecentScanEntry entry) {
    _setState(() {
      recentScans.removeWhere((item) => item.id == entry.id);
    });
  }

  void dismissRecognizedItem(RecognizedItem item) {
    final entryId = _recentScanEntryIdForItem(item);
    if (entryId == null) return;
    _setState(() {
      recentScans.removeWhere((entry) => entry.id == entryId);
    });
  }

  void addRecentScanToCart(RecentScanEntry entry) {
    addRecognizedItem(entry.item, recentScanEntryId: entry.id);
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
    final now = DateTime.now();
    final entryId =
        _recentScanEntryIdForItem(item) ?? '${now.microsecondsSinceEpoch}';

    _setState(() {
      recentScans.removeWhere((entry) => entry.id == entryId);
      recentScans.insert(
        0,
        RecentScanEntry(id: entryId, item: item, createdAt: now),
      );
      if (recentScans.length > 10) {
        recentScans.removeRange(10, recentScans.length);
      }
    });
  }

  String? _recentScanEntryIdForItem(RecognizedItem item) {
    final scanJobId = item.scanJobId?.trim();
    if (scanJobId == null || scanJobId.isEmpty) {
      return null;
    }
    return scanJobId;
  }
}
