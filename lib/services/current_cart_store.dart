import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';
import 'auth_store.dart';

class CurrentCartSnapshot {
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;

  const CurrentCartSnapshot({required this.items, required this.recentScans});
}

class CurrentCartStore {
  CurrentCartStore._();

  static final CurrentCartStore instance = CurrentCartStore._();

  static const _snapshotKey = 'current_cart_snapshot_v1';
  static const _ownerKey = 'current_cart_snapshot_owner_v1';

  String get _currentOwnerId => AuthStore.instance.session.value?.id ?? '';

  Future<CurrentCartSnapshot> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_snapshotKey);
    final storedOwnerId = sp.getString(_ownerKey) ?? '';
    final currentOwnerId = _currentOwnerId;

    if (raw == null || raw.trim().isEmpty) {
      return const CurrentCartSnapshot(items: [], recentScans: []);
    }
    if (storedOwnerId != currentOwnerId) {
      return const CurrentCartSnapshot(items: [], recentScans: []);
    }

    try {
      final decoded = jsonDecode(raw);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final itemsRaw = map['items'];
      final recentRaw = map['recentScans'];
      final items = itemsRaw is List
          ? itemsRaw
                .whereType<Map>()
                .map(
                  (entry) =>
                      _cartItemFromJson(Map<String, dynamic>.from(entry)),
                )
                .toList(growable: false)
          : const <CartItem>[];
      final recentScans = recentRaw is List
          ? recentRaw
                .whereType<Map>()
                .map(
                  (entry) =>
                      _recentScanFromJson(Map<String, dynamic>.from(entry)),
                )
                .toList(growable: false)
          : const <RecentScanEntry>[];
      return CurrentCartSnapshot(items: items, recentScans: recentScans);
    } catch (_) {
      return const CurrentCartSnapshot(items: [], recentScans: []);
    }
  }

  Future<void> save({
    required List<CartItem> items,
    required List<RecentScanEntry> recentScans,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final payload = {
      'items': items.map(_cartItemToJson).toList(growable: false),
      'recentScans': recentScans.map(_recentScanToJson).toList(growable: false),
    };
    await sp.setString(_ownerKey, _currentOwnerId);
    await sp.setString(_snapshotKey, jsonEncode(payload));
  }

  Map<String, dynamic> _cartItemToJson(CartItem item) => {
    'name': item.name,
    'price': item.price,
    'quantity': item.quantity,
    'source': item.source,
    'scanJobId': item.scanJobId,
    'originalRecognizedName': item.originalRecognizedName,
  };

  CartItem _cartItemFromJson(Map<String, dynamic> json) {
    return CartItem(
      name: (json['name'] ?? '') as String,
      price: (json['price'] ?? 0) as int,
      quantity: (json['quantity'] ?? 1) as int,
      source: json['source'] as String?,
      scanJobId: json['scanJobId'] as String?,
      originalRecognizedName:
          (json['originalRecognizedName'] ?? json['name']) as String?,
    );
  }

  Map<String, dynamic> _recentScanToJson(RecentScanEntry entry) => {
    'id': entry.id,
    'createdAt': entry.createdAt.toIso8601String(),
    'item': {
      'name': entry.item.name,
      'price': entry.item.price,
      'sku': entry.item.sku,
      'confidence': entry.item.confidence,
      'source': entry.item.source,
      'rawText': entry.item.rawText,
      'scanJobId': entry.item.scanJobId,
      'originalRecognizedName': entry.item.originalRecognizedName,
    },
  };

  RecentScanEntry _recentScanFromJson(Map<String, dynamic> json) {
    final itemJson = json['item'];
    final itemMap = itemJson is Map<String, dynamic>
        ? itemJson
        : <String, dynamic>{};
    return RecentScanEntry(
      id: (json['id'] ?? '') as String,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '') as String) ??
          DateTime.now(),
      item: RecognizedItem(
        name: (itemMap['name'] ?? '') as String,
        price: (itemMap['price'] ?? 0) as int,
        sku: itemMap['sku'] as String?,
        confidence: (itemMap['confidence'] as num?)?.toDouble(),
        source: itemMap['source'] as String?,
        rawText: itemMap['rawText'] as String?,
        scanJobId: itemMap['scanJobId'] as String?,
        originalRecognizedName:
            (itemMap['originalRecognizedName'] ?? itemMap['name']) as String?,
      ),
    );
  }
}
