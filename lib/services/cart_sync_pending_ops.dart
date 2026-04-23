import '../models/saved_cart.dart';

enum PendingCartOpKind { create, update, delete }

class PendingCartOp {
  final PendingCartOpKind kind;
  final String ownerId;
  final String cartId;
  final Map<String, dynamic>? cartJson;

  const PendingCartOp({
    required this.kind,
    required this.ownerId,
    required this.cartId,
    required this.cartJson,
  });

  factory PendingCartOp.create({
    required String ownerId,
    required SavedCart cart,
  }) => PendingCartOp(
    kind: PendingCartOpKind.create,
    ownerId: ownerId,
    cartId: cart.id,
    cartJson: cart.toJson(),
  );

  factory PendingCartOp.update({
    required String ownerId,
    required SavedCart cart,
  }) => PendingCartOp(
    kind: PendingCartOpKind.update,
    ownerId: ownerId,
    cartId: cart.id,
    cartJson: cart.toJson(),
  );

  factory PendingCartOp.delete({
    required String ownerId,
    required String cartId,
  }) => PendingCartOp(
    kind: PendingCartOpKind.delete,
    ownerId: ownerId,
    cartId: cartId,
    cartJson: null,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'ownerId': ownerId,
    'cartId': cartId,
    'cartJson': cartJson,
  };

  static PendingCartOp fromJson(Map<String, dynamic> json) {
    final kindName = (json['kind'] ?? 'update') as String;
    final kind = switch (kindName) {
      'create' => PendingCartOpKind.create,
      'delete' => PendingCartOpKind.delete,
      _ => PendingCartOpKind.update,
    };
    return PendingCartOp(
      kind: kind,
      ownerId: (json['ownerId'] ?? '') as String,
      cartId: (json['cartId'] ?? '') as String,
      cartJson: json['cartJson'] is Map<String, dynamic>
          ? json['cartJson'] as Map<String, dynamic>
          : json['cartJson'] is Map
          ? Map<String, dynamic>.from(json['cartJson'] as Map)
          : null,
    );
  }
}

List<SavedCart> applyPendingCartOps(
  List<SavedCart> remoteCarts,
  List<PendingCartOp> ops,
) {
  var next = List<SavedCart>.from(remoteCarts);

  for (final op in ops) {
    switch (op.kind) {
      case PendingCartOpKind.create:
      case PendingCartOpKind.update:
        final cartJson = op.cartJson;
        if (cartJson == null) {
          continue;
        }
        final cart = SavedCart.fromJson(cartJson);
        next = [
          cart,
          ...next.where((existing) => existing.id != cart.id),
        ];
      case PendingCartOpKind.delete:
        next = next.where((cart) => cart.id != op.cartId).toList();
    }
  }

  next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return next;
}
