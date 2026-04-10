class SavedCartItem {
  String name;
  int price;
  int quantity;

  SavedCartItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  int get total => price * quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'quantity': quantity,
  };

  static SavedCartItem fromJson(Map<String, dynamic> json) => SavedCartItem(
    name: (json['name'] ?? '') as String,
    price: (json['price'] ?? 0) as int,
    quantity: (json['quantity'] ?? 1) as int,
  );
}

class SavedCart {
  String id; // unique
  String? title;
  DateTime createdAt;
  List<SavedCartItem> items;
  DateTime? expiresAt;
  bool isExpired;
  int retentionExtensionCount;
  bool canExtendRetention;

  SavedCart({
    required this.id,
    this.title,
    required this.createdAt,
    required this.items,
    this.expiresAt,
    this.isExpired = false,
    this.retentionExtensionCount = 0,
    this.canExtendRetention = false,
  });

  int get totalPrice => items.fold(0, (sum, it) => sum + it.total);
  int get totalCount => items.fold(0, (sum, it) => sum + it.quantity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'isExpired': isExpired,
    'retentionExtensionCount': retentionExtensionCount,
    'canExtendRetention': canExtendRetention,
    'items': items.map((e) => e.toJson()).toList(),
  };

  static SavedCart fromJson(Map<String, dynamic> json) => SavedCart(
    id: (json['id'] ?? '') as String,
    title: (json['title'] as String?)?.trim().isEmpty == true
        ? null
        : json['title'] as String?,
    createdAt:
        DateTime.tryParse((json['createdAt'] ?? '') as String) ??
        DateTime.now(),
    expiresAt: DateTime.tryParse((json['expiresAt'] ?? '') as String),
    isExpired: json['isExpired'] == true,
    retentionExtensionCount: (json['retentionExtensionCount'] ?? 0) as int,
    canExtendRetention: json['canExtendRetention'] == true,
    items: ((json['items'] ?? []) as List)
        .map((e) => SavedCartItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}
