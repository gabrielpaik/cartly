import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_cart.dart';
import 'auth_store.dart';
import 'remote_cart_repository.dart';

class CartStore {
  CartStore._();
  static final CartStore instance = CartStore._();

  static const _key = 'saved_carts_v1';
  static const _ownerKey = 'saved_carts_owner_v1';

  final RemoteCartRepository _remoteRepository = RemoteCartRepository();

  final ValueNotifier<List<SavedCart>> carts = ValueNotifier<List<SavedCart>>(
    [],
  );

  Future<void> load() async {
    final local = await _readLocalState();
    final currentSession = AuthStore.instance.session.value;

    if (currentSession == null || currentSession.authToken.trim().isEmpty) {
      carts.value = local.ownerId.isEmpty ? local.carts : const [];
      return;
    }

    try {
      var remoteCarts = await _remoteRepository.listCarts(
        currentSession.authToken,
      );
      if (local.carts.isNotEmpty &&
          (local.ownerId.isEmpty ||
              (local.ownerId == currentSession.id && remoteCarts.isEmpty))) {
        for (final cart in local.carts) {
          await _remoteRepository.createCart(
            authToken: currentSession.authToken,
            cart: cart,
          );
        }
        remoteCarts = await _remoteRepository.listCarts(
          currentSession.authToken,
        );
      }
      await _persistLocal(remoteCarts, ownerId: currentSession.id);
      carts.value = List.unmodifiable(_sort(remoteCarts));
    } catch (_) {
      if (local.ownerId.isEmpty || local.ownerId == currentSession.id) {
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
    final localCart = SavedCart(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
      items: items,
    );

    final currentSession = AuthStore.instance.session.value;
    if (currentSession != null && currentSession.authToken.trim().isNotEmpty) {
      try {
        final created = await _remoteRepository.createCart(
          authToken: currentSession.authToken,
          cart: localCart,
        );
        final next = [
          created,
          ...carts.value.where((cart) => cart.id != created.id),
        ];
        await _persistLocal(next, ownerId: currentSession.id);
        return created;
      } catch (_) {
        final next = [
          localCart,
          ...carts.value.where((cart) => cart.id != localCart.id),
        ];
        await _persistLocal(next, ownerId: currentSession.id);
        return localCart;
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
        final remote = await _remoteRepository.updateCart(
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
        return remote;
      } catch (_) {
        final localSnapshot = SavedCart(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: updated.title,
          createdAt: DateTime.now(),
          items: updated.items,
        );
        final next = [localSnapshot, ...carts.value];
        await _persistLocal(next, ownerId: currentSession.id);
        return localSnapshot;
      }
    }

    final localSnapshot = SavedCart(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: updated.title,
      createdAt: DateTime.now(),
      items: updated.items,
    );
    final next = [localSnapshot, ...carts.value];
    await _persistLocal(next, ownerId: '');
    return localSnapshot;
  }

  Future<void> deleteCart(String id) async {
    final currentSession = AuthStore.instance.session.value;
    if (currentSession != null && currentSession.authToken.trim().isNotEmpty) {
      try {
        await _remoteRepository.deleteCart(
          authToken: currentSession.authToken,
          cartId: id,
        );
      } catch (_) {
        // keep local cache fallback path even if remote delete fails
      }
      final next = carts.value.where((cart) => cart.id != id).toList();
      await _persistLocal(next, ownerId: currentSession.id);
      return;
    }

    final next = carts.value.where((cart) => cart.id != id).toList();
    await _persistLocal(next, ownerId: '');
  }

  Future<SavedCart> extendRetention(String id) async {
    final currentSession = AuthStore.instance.session.value;
    if (currentSession == null || currentSession.authToken.trim().isEmpty) {
      throw const RemoteCartException('로그인이 필요해');
    }

    final updated = await _remoteRepository.extendCartRetention(
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
