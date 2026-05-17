import 'package:flutter/foundation.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';

class HomePageCartController {
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final List<ConsideredProductEntry> consideredItems;
  final void Function(VoidCallback fn) _setState;
  final VoidCallback? _onStateChanged;

  HomePageCartController({
    required this.items,
    required this.recentScans,
    required this.consideredItems,
    required void Function(VoidCallback fn) setState,
    VoidCallback? onStateChanged,
  }) : _setState = setState,
       _onStateChanged = onStateChanged;

  CartItem addRecognizedItem(RecognizedItem item, {String? recentScanEntryId}) {
    late final CartItem addedItem;
    _setState(() {
      addedItem = CartItem(
        name: item.name,
        price: item.price,
        source: item.source,
        scanJobId: item.scanJobId,
        originalRecognizedName:
            item.originalRecognizedName?.trim().isNotEmpty == true
            ? item.originalRecognizedName!.trim()
            : item.name.trim(),
      );
      items.insert(0, addedItem);
      _clearConsideredMatches(item.originalRecognizedName ?? item.name);
      _removeRecentScanEntry(item, recentScanEntryId: recentScanEntryId);
    });
    _onStateChanged?.call();
    return addedItem;
  }

  CartItem increaseMatchingCartItem(
    CartItem existing,
    RecognizedItem item, {
    String? recentScanEntryId,
  }) {
    _setState(() {
      existing.quantity++;
      _clearConsideredMatches(item.originalRecognizedName ?? item.name);
      _removeRecentScanEntry(item, recentScanEntryId: recentScanEntryId);
    });
    _onStateChanged?.call();
    return existing;
  }

  CartItem? findDuplicateCartItem(RecognizedItem item) {
    final normalizedName = _normalizeItemName(
      item.originalRecognizedName ?? item.name,
    );
    for (final existing in items) {
      final matchName = _normalizeItemName(
        existing.originalRecognizedName ?? existing.name,
      );
      if (matchName != normalizedName) continue;
      if (existing.price != item.price) continue;
      return existing;
    }
    return null;
  }

  void dismissRecentScan(RecentScanEntry entry) {
    _setState(() {
      _rememberConsideredProduct(
        name: entry.item.originalRecognizedName ?? entry.item.name,
        price: entry.item.price,
        source: 'scanNotAdded',
        originalRecognizedName: entry.item.originalRecognizedName,
      );
      recentScans.removeWhere((item) => item.id == entry.id);
    });
    _onStateChanged?.call();
  }

  void dismissRecognizedItem(RecognizedItem item) {
    final entryId = _recentScanEntryIdForItem(item);
    _setState(() {
      _rememberConsideredProduct(
        name: item.originalRecognizedName ?? item.name,
        price: item.price,
        source: 'scanNotAdded',
        originalRecognizedName: item.originalRecognizedName,
      );
      if (entryId != null) {
        recentScans.removeWhere((entry) => entry.id == entryId);
      }
    });
    _onStateChanged?.call();
  }

  void addRecentScanToCart(RecentScanEntry entry) {
    addRecognizedItem(entry.item, recentScanEntryId: entry.id);
  }

  void removeCartItem(CartItem item) {
    _setState(() {
      _rememberConsideredProduct(
        name: item.originalRecognizedName ?? item.name,
        price: item.price,
        source: 'removedFromCart',
        originalRecognizedName: item.originalRecognizedName,
      );
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

  void _rememberConsideredProduct({
    required String name,
    required int price,
    required String source,
    String? originalRecognizedName,
  }) {
    final normalizedName = _normalizeItemName(originalRecognizedName ?? name);
    consideredItems.removeWhere(
      (entry) =>
          entry.source == source &&
          _normalizeItemName(entry.originalRecognizedName ?? entry.name) ==
              normalizedName,
    );
    consideredItems.insert(
      0,
      ConsideredProductEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        price: price,
        source: source,
        createdAt: DateTime.now(),
        originalRecognizedName: originalRecognizedName,
      ),
    );
    if (consideredItems.length > 24) {
      consideredItems.removeRange(24, consideredItems.length);
    }
  }

  void _clearConsideredMatches(String name) {
    final normalizedName = _normalizeItemName(name);
    consideredItems.removeWhere(
      (entry) =>
          _normalizeItemName(entry.originalRecognizedName ?? entry.name) ==
          normalizedName,
    );
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
