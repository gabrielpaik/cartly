import 'package:flutter_test/flutter_test.dart';
import 'package:cartly/models/saved_cart.dart';
import 'package:cartly/services/cart_sync_pending_ops.dart';

SavedCart _cart({required String id, required int day}) => SavedCart(
  id: id,
  title: 'cart-$id',
  createdAt: DateTime(2026, 4, day),
  items: [SavedCartItem(name: 'item-$id', price: 1000, quantity: 1)],
);

void main() {
  group('cart_sync_pending_ops', () {
    test('PendingCartOp JSON round-trip preserves create payload', () {
      final op = PendingCartOp.create(ownerId: 'user-1', cart: _cart(id: 'c1', day: 10));

      final decoded = PendingCartOp.fromJson(op.toJson());

      expect(decoded.kind, PendingCartOpKind.create);
      expect(decoded.ownerId, 'user-1');
      expect(decoded.cartId, 'c1');
      expect(decoded.cartJson?['title'], 'cart-c1');
    });

    test('PendingCartOp JSON round-trip preserves update payload', () {
      final op = PendingCartOp.update(ownerId: 'user-1', cart: _cart(id: 'c1', day: 10));

      final decoded = PendingCartOp.fromJson(op.toJson());

      expect(decoded.kind, PendingCartOpKind.update);
      expect(decoded.ownerId, 'user-1');
      expect(decoded.cartId, 'c1');
      expect(decoded.cartJson?['title'], 'cart-c1');
    });

    test('applyPendingCartOps overlays pending create onto remote carts', () {
      final remote = [_cart(id: 'c1', day: 1)];
      final created = SavedCart(
        id: 'temp-1',
        title: 'created-local',
        createdAt: DateTime(2026, 4, 21),
        items: [SavedCartItem(name: 'temp-item', price: 3000, quantity: 1)],
      );

      final result = applyPendingCartOps(
        remote,
        [PendingCartOp.create(ownerId: 'user-1', cart: created)],
      );

      expect(result.map((cart) => cart.id), ['temp-1', 'c1']);
      expect(result.first.title, 'created-local');
    });

    test('applyPendingCartOps overlays pending update onto remote carts', () {
      final remote = [_cart(id: 'c1', day: 1)];
      final updated = SavedCart(
        id: 'c1',
        title: 'updated-cart',
        createdAt: DateTime(2026, 4, 20),
        items: [SavedCartItem(name: 'new-item', price: 2000, quantity: 2)],
      );

      final result = applyPendingCartOps(
        remote,
        [PendingCartOp.update(ownerId: 'user-1', cart: updated)],
      );

      expect(result, hasLength(1));
      expect(result.first.title, 'updated-cart');
      expect(result.first.items.first.name, 'new-item');
    });

    test('applyPendingCartOps hides carts with pending delete', () {
      final remote = [_cart(id: 'c1', day: 1), _cart(id: 'c2', day: 2)];

      final result = applyPendingCartOps(
        remote,
        [PendingCartOp.delete(ownerId: 'user-1', cartId: 'c1')],
      );

      expect(result.map((cart) => cart.id), ['c2']);
    });

    test('applyPendingCartOps returns carts sorted newest first after overlay', () {
      final remote = [_cart(id: 'older', day: 1)];
      final newer = _cart(id: 'newer', day: 22);

      final result = applyPendingCartOps(
        remote,
        [PendingCartOp.update(ownerId: 'user-1', cart: newer)],
      );

      expect(result.map((cart) => cart.id), ['newer', 'older']);
    });
  });
}
