import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_support.dart';
import '../models/pending_scan_entry.dart';
import '../models/recognized_item.dart';
import '../models/recognized_item_candidate.dart';
import 'auth_store.dart';

enum CurrentCartMode { personal, shared }

class CurrentCartSnapshot {
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final List<ConsideredProductEntry> consideredItems;
  final List<PendingScanEntry> pendingScans;
  final String? activePendingScanId;

  const CurrentCartSnapshot({
    required this.items,
    required this.recentScans,
    required this.consideredItems,
    this.pendingScans = const [],
    this.activePendingScanId,
  });
}

class CurrentCartStore {
  CurrentCartStore._();

  static final CurrentCartStore instance = CurrentCartStore._();

  static const _personalSnapshotKey = 'current_cart_personal_snapshot_v2';
  static const _ownerKey = 'current_cart_snapshot_owner_v2';
  static const _modeKey = 'current_cart_mode_v2';

  String get _currentOwnerId => AuthStore.instance.session.value?.id ?? '';
  bool get _canUseSharedModePreference {
    final session = AuthStore.instance.session.value;
    return session != null &&
        !session.isGuest &&
        session.authToken.trim().isNotEmpty;
  }

  Future<CurrentCartSnapshot> loadPersonal() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_personalSnapshotKey);
    final storedOwnerId = sp.getString(_ownerKey) ?? '';
    final currentOwnerId = _currentOwnerId;

    if (raw == null || raw.trim().isEmpty || storedOwnerId != currentOwnerId) {
      return const CurrentCartSnapshot(
        items: [],
        recentScans: [],
        consideredItems: [],
        pendingScans: [],
      );
    }

    try {
      final decoded = jsonDecode(raw);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final itemsRaw = map['items'];
      final recentRaw = map['recentScans'];
      final consideredRaw = map['consideredItems'];
      final pendingRaw = map['pendingScans'];
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
      final consideredItems = consideredRaw is List
          ? consideredRaw
                .whereType<Map>()
                .map(
                  (entry) =>
                      _consideredItemFromJson(Map<String, dynamic>.from(entry)),
                )
                .toList(growable: false)
          : const <ConsideredProductEntry>[];
      final pendingScans = pendingRaw is List
          ? pendingRaw
                .whereType<Map>()
                .map(
                  (entry) =>
                      _pendingScanFromJson(Map<String, dynamic>.from(entry)),
                )
                .toList(growable: false)
          : const <PendingScanEntry>[];
      return CurrentCartSnapshot(
        items: items,
        recentScans: recentScans,
        consideredItems: consideredItems,
        pendingScans: pendingScans,
        activePendingScanId: map['activePendingScanId'] as String?,
      );
    } catch (_) {
      return const CurrentCartSnapshot(
        items: [],
        recentScans: [],
        consideredItems: [],
        pendingScans: [],
      );
    }
  }

  Future<CurrentCartSnapshot> load() => loadPersonal();

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_personalSnapshotKey);
    await sp.remove(_ownerKey);
    await sp.remove(_modeKey);
  }

  Future<void> savePersonal({
    required List<CartItem> items,
    required List<RecentScanEntry> recentScans,
    required List<ConsideredProductEntry> consideredItems,
    List<PendingScanEntry>? pendingScans,
    String? activePendingScanId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final existingSnapshot = await loadPersonal();
    final resolvedPendingScans = pendingScans ?? existingSnapshot.pendingScans;
    final resolvedActivePendingScanId = pendingScans == null
        ? existingSnapshot.activePendingScanId
        : activePendingScanId;
    final payload = {
      'items': items.map(_cartItemToJson).toList(growable: false),
      'recentScans': recentScans.map(_recentScanToJson).toList(growable: false),
      'consideredItems': consideredItems
          .map(_consideredItemToJson)
          .toList(growable: false),
      'pendingScans': resolvedPendingScans
          .map(_pendingScanToJson)
          .toList(growable: false),
      'activePendingScanId': resolvedActivePendingScanId,
    };
    await sp.setString(_ownerKey, _currentOwnerId);
    await sp.setString(_personalSnapshotKey, jsonEncode(payload));
  }

  Future<void> save({
    required List<CartItem> items,
    required List<RecentScanEntry> recentScans,
    required List<ConsideredProductEntry> consideredItems,
    List<PendingScanEntry>? pendingScans,
    String? activePendingScanId,
  }) {
    return savePersonal(
      items: items,
      recentScans: recentScans,
      consideredItems: consideredItems,
      pendingScans: pendingScans,
      activePendingScanId: activePendingScanId,
    );
  }

  Future<PendingScanStateSnapshot> loadPendingScans() async {
    final snapshot = await loadPersonal();
    return PendingScanStateSnapshot(
      entries: snapshot.pendingScans,
      activeEntryId: snapshot.activePendingScanId,
    );
  }

  Future<void> savePendingScans({
    required List<PendingScanEntry> pendingScans,
    String? activePendingScanId,
  }) async {
    final snapshot = await loadPersonal();
    await savePersonal(
      items: snapshot.items,
      recentScans: snapshot.recentScans,
      consideredItems: snapshot.consideredItems,
      pendingScans: pendingScans,
      activePendingScanId: activePendingScanId,
    );
  }

  Future<CurrentCartMode?> loadStoredMode() async {
    if (!_canUseSharedModePreference) {
      return null;
    }
    final sp = await SharedPreferences.getInstance();
    final storedOwnerId = sp.getString(_ownerKey) ?? '';
    if (storedOwnerId != _currentOwnerId) {
      return null;
    }
    return switch (sp.getString(_modeKey)) {
      'shared' => CurrentCartMode.shared,
      'personal' => CurrentCartMode.personal,
      _ => null,
    };
  }

  Future<CurrentCartMode> loadMode() async {
    return await loadStoredMode() ?? CurrentCartMode.personal;
  }

  Future<void> saveMode(CurrentCartMode mode) async {
    if (!_canUseSharedModePreference) {
      return;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_ownerKey, _currentOwnerId);
    await sp.setString(
      _modeKey,
      mode == CurrentCartMode.shared ? 'shared' : 'personal',
    );
  }

  Map<String, dynamic> _cartItemToJson(CartItem item) => {
    'id': item.id,
    'name': item.name,
    'price': item.price,
    'quantity': item.quantity,
    'source': item.source,
    'scanJobId': item.scanJobId,
    'originalRecognizedName': item.originalRecognizedName,
  };

  CartItem _cartItemFromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String?,
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
    'item': _recognizedItemToJson(entry.item),
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
      item: _recognizedItemFromJson(itemMap),
    );
  }

  Map<String, dynamic> _consideredItemToJson(ConsideredProductEntry entry) => {
    'id': entry.id,
    'name': entry.name,
    'price': entry.price,
    'source': entry.source,
    'createdAt': entry.createdAt.toIso8601String(),
    'originalRecognizedName': entry.originalRecognizedName,
  };

  ConsideredProductEntry _consideredItemFromJson(Map<String, dynamic> json) {
    return ConsideredProductEntry(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      price: (json['price'] ?? 0) as int,
      source: (json['source'] ?? 'scanNotAdded') as String,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '') as String) ??
          DateTime.now(),
      originalRecognizedName: json['originalRecognizedName'] as String?,
    );
  }

  Map<String, dynamic> _pendingScanToJson(PendingScanEntry entry) => {
    'id': entry.id,
    'imagePath': entry.imagePath,
    'status': _pendingStatusToJson(entry.status),
    'createdAt': entry.createdAt.toIso8601String(),
    'completedAt': entry.completedAt?.toIso8601String(),
    'item': entry.item == null ? null : _recognizedItemToJson(entry.item!),
    'candidate': entry.candidate == null
        ? null
        : _recognizedItemCandidateToJson(entry.candidate!),
    'errorMessage': entry.errorMessage,
    'scanJobId': entry.scanJobId,
  };

  PendingScanEntry _pendingScanFromJson(Map<String, dynamic> json) {
    final itemJson = json['item'];
    final itemMap = itemJson is Map<String, dynamic>
        ? itemJson
        : <String, dynamic>{};
    final candidateJson = json['candidate'];
    final candidateMap = candidateJson is Map<String, dynamic>
        ? candidateJson
        : <String, dynamic>{};
    return PendingScanEntry(
      id: (json['id'] ?? '') as String,
      imagePath: json['imagePath'] as String?,
      status: _pendingStatusFromJson(json['status'] as String?),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '') as String) ??
          DateTime.now(),
      completedAt: DateTime.tryParse((json['completedAt'] ?? '') as String),
      item: itemJson is Map<String, dynamic> ? _recognizedItemFromJson(itemMap) : null,
      candidate: candidateJson is Map<String, dynamic>
          ? _recognizedItemCandidateFromJson(candidateMap)
          : null,
      errorMessage: json['errorMessage'] as String?,
      scanJobId: json['scanJobId'] as String?,
    );
  }

  Map<String, dynamic> _recognizedItemToJson(RecognizedItem item) => {
    'name': item.name,
    'price': item.price,
    'sku': item.sku,
    'confidence': item.confidence,
    'source': item.source,
    'rawText': item.rawText,
    'scanJobId': item.scanJobId,
    'originalRecognizedName': item.originalRecognizedName,
  };

  RecognizedItem _recognizedItemFromJson(Map<String, dynamic> itemMap) {
    return RecognizedItem(
      name: (itemMap['name'] ?? '') as String,
      price: (itemMap['price'] ?? 0) as int,
      sku: itemMap['sku'] as String?,
      confidence: (itemMap['confidence'] as num?)?.toDouble(),
      source: itemMap['source'] as String?,
      rawText: itemMap['rawText'] as String?,
      scanJobId: itemMap['scanJobId'] as String?,
      originalRecognizedName:
          (itemMap['originalRecognizedName'] ?? itemMap['name']) as String?,
    );
  }

  Map<String, dynamic> _recognizedItemCandidateToJson(
    RecognizedItemCandidate candidate,
  ) => {
    'name': candidate.name,
    'price': candidate.price,
    'sku': candidate.sku,
    'confidence': candidate.confidence,
    'source': candidate.source,
    'rawText': candidate.rawText,
    'scanJobId': candidate.scanJobId,
  };

  RecognizedItemCandidate _recognizedItemCandidateFromJson(
    Map<String, dynamic> candidateMap,
  ) {
    return RecognizedItemCandidate(
      name: (candidateMap['name'] ?? '') as String,
      price: (candidateMap['price'] ?? 0) as int,
      sku: candidateMap['sku'] as String?,
      confidence: (candidateMap['confidence'] as num?)?.toDouble(),
      source: (candidateMap['source'] ?? 'scan') as String,
      rawText: candidateMap['rawText'] as String?,
      scanJobId: candidateMap['scanJobId'] as String?,
    );
  }

  String _pendingStatusToJson(PendingScanStatus status) => switch (status) {
    PendingScanStatus.captured => 'captured',
    PendingScanStatus.uploading => 'uploading',
    PendingScanStatus.processing => 'processing',
    PendingScanStatus.ready => 'ready',
    PendingScanStatus.failed => 'failed',
    PendingScanStatus.added => 'added',
  };

  PendingScanStatus _pendingStatusFromJson(String? raw) {
    return switch (raw) {
      'captured' => PendingScanStatus.captured,
      'uploading' => PendingScanStatus.uploading,
      'processing' => PendingScanStatus.processing,
      'ready' => PendingScanStatus.ready,
      'failed' => PendingScanStatus.failed,
      'added' => PendingScanStatus.added,
      _ => PendingScanStatus.captured,
    };
  }
}
