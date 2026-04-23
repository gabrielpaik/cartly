class SavedCartReceiptStatus {
  final String receiptId;
  final String receiptStatus;
  final String? merchantName;
  final bool hasReceipt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const SavedCartReceiptStatus({
    required this.receiptId,
    required this.receiptStatus,
    required this.merchantName,
    required this.hasReceipt,
    required this.updatedAt,
    required this.completedAt,
  });

  bool get isReady => receiptStatus == 'ready';

  Map<String, dynamic> toJson() => {
    'receiptId': receiptId,
    'receiptStatus': receiptStatus,
    'merchantName': merchantName,
    'hasReceipt': hasReceipt,
    'updatedAt': updatedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  static SavedCartReceiptStatus fromJson(Map<String, dynamic> json) => SavedCartReceiptStatus(
    receiptId: (json['receiptId'] ?? '') as String,
    receiptStatus: (json['receiptStatus'] ?? 'processing') as String,
    merchantName: json['merchantName'] as String?,
    hasReceipt: json['hasReceipt'] != false,
    updatedAt: DateTime.tryParse((json['updatedAt'] ?? '') as String),
    completedAt: DateTime.tryParse((json['completedAt'] ?? '') as String),
  );
}

class SavedCartItem {
  String name;
  int price;
  int quantity;
  String? source;
  String? scanResultId;

  SavedCartItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.source,
    this.scanResultId,
  });

  int get total => price * quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'quantity': quantity,
    'source': source,
    'scanResultId': scanResultId,
  };

  static SavedCartItem fromJson(Map<String, dynamic> json) => SavedCartItem(
    name: (json['name'] ?? '') as String,
    price: (json['price'] ?? 0) as int,
    quantity: (json['quantity'] ?? 1) as int,
    source: json['source'] as String?,
    scanResultId: json['scanResultId'] as String?,
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
  SavedCartReceiptStatus? receiptStatus;

  SavedCart({
    required this.id,
    this.title,
    required this.createdAt,
    required this.items,
    this.expiresAt,
    this.isExpired = false,
    this.retentionExtensionCount = 0,
    this.canExtendRetention = false,
    this.receiptStatus,
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
    'receiptStatus': receiptStatus?.toJson(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  static SavedCart fromJson(Map<String, dynamic> json) => SavedCart(
    id: json['id'] as String,
    title: json['title'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null,
    isExpired: json['isExpired'] == true,
    retentionExtensionCount: (json['retentionExtensionCount'] ?? 0) as int,
    canExtendRetention: json['canExtendRetention'] == true,
    receiptStatus: json['receiptStatus'] is Map<String, dynamic>
        ? SavedCartReceiptStatus.fromJson(json['receiptStatus'] as Map<String, dynamic>)
        : json['receiptStatus'] is Map
        ? SavedCartReceiptStatus.fromJson(Map<String, dynamic>.from(json['receiptStatus'] as Map))
        : null,
    items:
        (json['items'] as List<dynamic>? ?? const [])
            .map((e) => SavedCartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
  );
}

