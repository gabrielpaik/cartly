import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_cart.dart';
import 'auth_store.dart';
import 'cart_sync_pending_ops.dart';
import 'remote_cart_repository.dart';

class CartStore {
  CartStore._();
  static final CartStore instance = CartStore._();

  static const _key = 'saved_carts_v1';
  static const _ownerKey = 'saved_carts_owner_v1';
  static const _pendingOpKey = 'saved_carts_pending_ops_v1';

  RemoteCartRepository? _remoteRepository;

  RemoteCartRepository get _cartRepository =>
      _remoteRepository ??= RemoteCartRepository();

  final ValueNotifier<List<SavedCart>> carts = ValueNotifier<List<SavedCart>>(
    [],
  );
  final ValueNotifier<Set<String>> pendingCartIds = ValueNotifier<Set<String>>(
    <String>{},
  );

  Future<void> load() async {
    final local = await _readLocalState();
    final currentSession = AuthStore.instance.session.value;

    if (currentSession == null || currentSession.authToken.trim().isEmpty) {
      pendingCartIds.value = <String>{};
      carts.value = local.ownerId.isEmpty ? local.carts : const [];
      return;
    }

    if (local.ownerId.isEmpty || local.ownerId == currentSession.id) {
      carts.value = List.unmodifiable(_sort(local.carts));
    }

    try {
      var remoteCarts = await _cartRepository.listCarts(
        currentSession.authToken,
      );
      if (local.carts.isNotEmpty &&
          (local.ownerId.isEmpty ||
              (local.ownerId == currentSession.id && remoteCarts.isEmpty))) {
        for (final cart in local.carts) {
          await _cartRepository.createCart(
            authToken: currentSession.authToken,
            cart: cart,
          );
        }
        remoteCarts = await _cartRepository.listCarts(currentSession.authToken);
      }

      final remainingPending = await _flushPendingOps(
        authToken: currentSession.authToken,
        ownerId: currentSession.id,
      );
      remoteCarts = await _cartRepository.listCarts(currentSession.authToken);
      final ownerPending = remainingPending
          .where((op) => op.ownerId == currentSession.id)
          .toList();
      final effectiveCarts = applyPendingCartOps(remoteCarts, ownerPending);

      _updatePendingCartIds(ownerPending);
      await _persistLocal(effectiveCarts, ownerId: currentSession.id);
      carts.value = List.unmodifiable(_sort(effectiveCarts));
    } catch (_) {
      if (local.ownerId.isEmpty || local.ownerId == currentSession.id) {
        final pending = await _readPendingOps();
        _updatePendingCartIds(
          pending.where((op) => op.ownerId == currentSession.id).toList(),
        );
        carts.value = List.unmodifiable(_sort(local.carts));
        return;
      }
      carts.value = const [];
    }
  }

  Future<SavedCart> saveNewCart({
    required List<SavedCartItem> items,
    String? title,
  }) async {
    final now = DateTime.now();
    final localCart = SavedCart(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
      updatedAt: now,
      items: items,
    );

    final currentSession = AuthStore.instance.session.value;
    if (currentSession != null && currentSession.authToken.trim().isNotEmpty) {
      try {
        final created = await _cartRepository.createCart(
          authToken: currentSession.authToken,
          cart: localCart,
        );
        final next = [
          created,
          ...carts.value.where((cart) => cart.id != created.id),
        ];
        await _persistLocal(next, ownerId: currentSession.id);
        return created;
      } on RemoteCartException {
        final next = [
          localCart,
          ...carts.value.where((cart) => cart.id != localCart.id),
        ];
        await _persistLocal(next, ownerId: currentSession.id);
        await _upsertPendingOp(
          PendingCartOp.create(ownerId: currentSession.id, cart: localCart),
        );
        throw const RemoteCartException('저장은 로컬에 반영했고, 서버 생성은 다시 시도할게');
      }
    }

    final next = [
      localCart,
      ...carts.value.where((cart) => cart.id != localCart.id),
    ];
    await _persistLocal(next, ownerId: '');
    return localCart;
  }

  Future<SavedCart> updateCart(SavedCart updated) async {
    final currentSession = AuthStore.instance.session.value;
    if (currentSession != null && currentSession.authToken.trim().isNotEmpty) {
      try {
        final remote = await _cartRepository.updateCart(
          authToken: currentSession.authToken,
          cart: updated,
        );
        final next = [
          remote,
          ...carts.value.where(
            (cart) => cart.id != updated.id && cart.id != remote.id,
          ),
        ];
        await _persistLocal(next, ownerId: currentSession.id);
        await _clearPendingOp(ownerId: currentSession.id, cartId: remote.id);
        return remote;
      } on RemoteCartException {
        final next = [
          updated,
          ...carts.value.where((cart) => cart.id != updated.id),
        ];
        await _persistLocal(next, ownerId: currentSession.id);
        final existingPending = await _getPendingOpForCart(
          ownerId: currentSession.id,
          cartId: updated.id,
        );
        await _upsertPendingOp(
          existingPending?.kind == PendingCartOpKind.create
              ? PendingCartOp.create(ownerId: currentSession.id, cart: updated)
              : PendingCartOp.update(ownerId: currentSession.id, cart: updated),
        );
        throw const RemoteCartException('저장은 로컬에 반영했고, 서버 동기화는 다시 시도할게');
      }
    }

    final localSnapshot = SavedCart(
      id: updated.id,
      title: updated.title,
      createdAt: updated.createdAt,
      updatedAt: DateTime.now(),
      items: updated.items,
      expiresAt: updated.expiresAt,
      isExpired: updated.isExpired,
      retentionExtensionCount: updated.retentionExtensionCount,
      canExtendRetention: updated.canExtendRetention,
      receiptStatus: updated.receiptStatus,
    );
    final next = [
      localSnapshot,
      ...carts.value.where((cart) => cart.id != localSnapshot.id),
    ];
    await _persistLocal(next, ownerId: '');
    return localSnapshot;
  }

  Future<void> deleteCart(String id) async {
    final currentSession = AuthStore.instance.session.value;
    if (currentSession != null && currentSession.authToken.trim().isNotEmpty) {
      try {
        await _cartRepository.deleteCart(
          authToken: currentSession.authToken,
          cartId: id,
        );
        final next = carts.value.where((cart) => cart.id != id).toList();
        await _persistLocal(next, ownerId: currentSession.id);
        await _clearPendingOp(ownerId: currentSession.id, cartId: id);
        return;
      } on RemoteCartException {
        final next = carts.value.where((cart) => cart.id != id).toList();
        await _persistLocal(next, ownerId: currentSession.id);
        final existingPending = await _getPendingOpForCart(
          ownerId: currentSession.id,
          cartId: id,
        );
        if (existingPending?.kind == PendingCartOpKind.create) {
          await _clearPendingOp(ownerId: currentSession.id, cartId: id);
          return;
        }
        await _upsertPendingOp(
          PendingCartOp.delete(ownerId: currentSession.id, cartId: id),
        );
        throw const RemoteCartException('삭제는 로컬에 반영했고, 서버 동기화는 다시 시도할게');
      }
    }

    final next = carts.value.where((cart) => cart.id != id).toList();
    await _persistLocal(next, ownerId: '');
  }

  Future<SavedCart?> refreshCartById(String id) async {
    final currentSession = AuthStore.instance.session.value;
    if (currentSession == null || currentSession.authToken.trim().isEmpty) {
      for (final cart in carts.value) {
        if (cart.id == id) return cart;
      }
      return null;
    }

    try {
      final remote = await _cartRepository.getCart(
        authToken: currentSession.authToken,
        cartId: id,
      );
      final next = [
        remote,
        ...carts.value.where((cart) => cart.id != id && cart.id != remote.id),
      ];
      await _persistLocal(next, ownerId: currentSession.id);
      return remote;
    } catch (_) {
      for (final cart in carts.value) {
        if (cart.id == id) return cart;
      }
      return null;
    }
  }

  Future<SavedCart> extendRetention(String id) async {
    final currentSession = AuthStore.instance.session.value;
    if (currentSession == null || currentSession.authToken.trim().isEmpty) {
      throw const RemoteCartException('로그인이 필요해');
    }

    final updated = await _cartRepository.extendCartRetention(
      authToken: currentSession.authToken,
      cartId: id,
    );
    final next = [
      updated,
      ...carts.value.where((cart) => cart.id != id && cart.id != updated.id),
    ];
    await _persistLocal(next, ownerId: currentSession.id);
    return updated;
  }

  Future<void> refreshForCurrentSession() async {
    await load();
  }

  Future<_LocalCartState> _readLocalState() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    final ownerId = sp.getString(_ownerKey)?.trim() ?? '';
    if (raw == null || raw.isEmpty) {
      return _LocalCartState(carts: const [], ownerId: ownerId);
    }

    try {
      final decoded = jsonDecode(raw) as List;
      final list = decoded
          .map((e) => SavedCart.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return _LocalCartState(carts: _sort(list), ownerId: ownerId);
    } catch (_) {
      return _LocalCartState(carts: const [], ownerId: ownerId);
    }
  }

  Future<List<PendingCartOp>> _readPendingOps() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_pendingOpKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => PendingCartOp.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistPendingOps(List<PendingCartOp> ops) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(ops.map((op) => op.toJson()).toList());
    await sp.setString(_pendingOpKey, encoded);
    final ownerId = AuthStore.instance.session.value?.id;
    if (ownerId != null && ownerId.isNotEmpty) {
      _updatePendingCartIds(ops.where((op) => op.ownerId == ownerId).toList());
    } else {
      pendingCartIds.value = <String>{};
    }
  }

  Future<void> _upsertPendingOp(PendingCartOp op) async {
    final ops = await _readPendingOps();
    final next = ops
        .where(
          (existing) =>
              existing.ownerId != op.ownerId || existing.cartId != op.cartId,
        )
        .toList();
    next.add(op);
    await _persistPendingOps(next);
  }

  Future<PendingCartOp?> _getPendingOpForCart({
    required String ownerId,
    required String cartId,
  }) async {
    final ops = await _readPendingOps();
    for (final op in ops) {
      if (op.ownerId == ownerId && op.cartId == cartId) {
        return op;
      }
    }
    return null;
  }

  Future<void> _clearPendingOp({
    required String ownerId,
    required String cartId,
  }) async {
    final ops = await _readPendingOps();
    final next = ops
        .where((op) => op.ownerId != ownerId || op.cartId != cartId)
        .toList();
    await _persistPendingOps(next);
  }

  Future<List<PendingCartOp>> _flushPendingOps({
    required String authToken,
    required String ownerId,
  }) async {
    final ops = await _readPendingOps();
    if (ops.isEmpty) return const [];

    final remaining = <PendingCartOp>[];
    for (final op in ops) {
      if (op.ownerId != ownerId) {
        remaining.add(op);
        continue;
      }

      try {
        switch (op.kind) {
          case PendingCartOpKind.create:
            final cartJson = op.cartJson;
            if (cartJson == null) {
              continue;
            }
            await _cartRepository.createCart(
              authToken: authToken,
              cart: SavedCart.fromJson(cartJson),
            );
          case PendingCartOpKind.update:
            final cartJson = op.cartJson;
            if (cartJson == null) {
              continue;
            }
            await _cartRepository.updateCart(
              authToken: authToken,
              cart: SavedCart.fromJson(cartJson),
            );
          case PendingCartOpKind.delete:
            await _cartRepository.deleteCart(
              authToken: authToken,
              cartId: op.cartId,
            );
        }
      } on RemoteCartException {
        remaining.add(op);
      }
    }

    await _persistPendingOps(remaining);
    return remaining;
  }

  Future<void> _persistLocal(
    List<SavedCart> list, {
    required String ownerId,
  }) async {
    final sorted = _sort(list);
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(sorted.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);
    await sp.setString(_ownerKey, ownerId);
    carts.value = List.unmodifiable(sorted);
  }

  void _updatePendingCartIds(List<PendingCartOp> ops) {
    pendingCartIds.value = ops.map((op) => op.cartId).toSet();
  }

  List<SavedCart> _sort(List<SavedCart> input) {
    final next = List<SavedCart>.from(input);
    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return next;
  }
}

class _LocalCartState {
  final List<SavedCart> carts;
  final String ownerId;

  const _LocalCartState({required this.carts, required this.ownerId});
}
