import 'package:flutter/foundation.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';

class HomePageCartController {
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final void Function(VoidCallback fn) _setState;
  final VoidCallback? _onStateChanged;

  HomePageCartController({
    required this.items,
    required this.recentScans,
    required void Function(VoidCallback fn) setState,
    VoidCallback? onStateChanged,
  }) : _setState = setState,
       _onStateChanged = onStateChanged;

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
      _removeRecentScanEntry(item, recentScanEntryId: recentScanEntryId);
    });
    _onStateChanged?.call();
  }

  void increaseMatchingCartItem(
    CartItem existing,
    RecognizedItem item, {
    String? recentScanEntryId,
  }) {
    _setState(() {
      existing.quantity++;
      _removeRecentScanEntry(item, recentScanEntryId: recentScanEntryId);
    });
    _onStateChanged?.call();
  }

  CartItem? findDuplicateCartItem(RecognizedItem item) {
    final normalizedName = _normalizeItemName(item.name);
    for (final existing in items) {
      if (_normalizeItemName(existing.name) != normalizedName) continue;
      if (existing.price != item.price) continue;
      return existing;
    }
    return null;
  }

  void dismissRecentScan(RecentScanEntry entry) {
    _setState(() {
      recentScans.removeWhere((item) => item.id == entry.id);
    });
    _onStateChanged?.call();
  }

  void dismissRecognizedItem(RecognizedItem item) {
    final entryId = _recentScanEntryIdForItem(item);
    if (entryId == null) return;
    _setState(() {
      recentScans.removeWhere((entry) => entry.id == entryId);
    });
    _onStateChanged?.call();
  }

  void addRecentScanToCart(RecentScanEntry entry) {
    addRecognizedItem(entry.item, recentScanEntryId: entry.id);
  }

  void removeCartItem(CartItem item) {
    _setState(() {
      items.remove(item);
    });
    _onStateChanged?.call();
  }

  void clearItems() {
    _setState(items.clear);
    _onStateChanged?.call();
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
    _onStateChanged?.call();
  }

  void _removeRecentScanEntry(
    RecognizedItem item, {
    String? recentScanEntryId,
  }) {
    final resolvedEntryId =
        recentScanEntryId ?? _recentScanEntryIdForItem(item);
    if (resolvedEntryId != null) {
      recentScans.removeWhere((entry) => entry.id == resolvedEntryId);
    }
  }

  String? _recentScanEntryIdForItem(RecognizedItem item) {
    final scanJobId = item.scanJobId?.trim();
    if (scanJobId == null || scanJobId.isEmpty) {
      return null;
    }
    return scanJobId;
  }

  String _normalizeItemName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
