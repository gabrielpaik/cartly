class SavedCartReceiptStatus {
  final String receiptId;
  final String receiptStatus;
  final String? merchantName;
  final bool hasReceipt;
  final DateTime? purchasedAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const SavedCartReceiptStatus({
    required this.receiptId,
    required this.receiptStatus,
    required this.merchantName,
    required this.hasReceipt,
    required this.purchasedAt,
    required this.updatedAt,
    required this.completedAt,
  });

  bool get isReady => receiptStatus == 'ready';

  Map<String, dynamic> toJson() => {
    'receiptId': receiptId,
    'receiptStatus': receiptStatus,
    'merchantName': merchantName,
    'hasReceipt': hasReceipt,
    'purchasedAt': purchasedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  static SavedCartReceiptStatus fromJson(Map<String, dynamic> json) =>
      SavedCartReceiptStatus(
        receiptId: (json['receiptId'] ?? '') as String,
        receiptStatus: (json['receiptStatus'] ?? 'processing') as String,
        merchantName: json['merchantName'] as String?,
        hasReceipt: json['hasReceipt'] != false,
        purchasedAt: DateTime.tryParse((json['purchasedAt'] ?? '') as String),
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
  String? originalName;
  int? originalPrice;
  String? categoryLabel;
  String? categorySource;

  SavedCartItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.source,
    this.scanResultId,
    this.originalName,
    this.originalPrice,
    this.categoryLabel,
    this.categorySource,
  });

  int get total => price * quantity;
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  int? get discountAmount => hasDiscount ? originalPrice! - price : null;

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'quantity': quantity,
    'source': source,
    'scanResultId': scanResultId,
    'originalName': originalName,
    'originalPrice': originalPrice,
    'categoryLabel': categoryLabel,
    'categorySource': categorySource,
  };

  static SavedCartItem fromJson(Map<String, dynamic> json) {
    final categoryMeta = json['categoryMeta'] is Map<String, dynamic>
        ? json['categoryMeta'] as Map<String, dynamic>
        : json['categoryMeta'] is Map
        ? Map<String, dynamic>.from(json['categoryMeta'] as Map)
        : null;
    return SavedCartItem(
      name: (json['name'] ?? '') as String,
      price: (json['price'] ?? 0) as int,
      quantity: (json['quantity'] ?? 1) as int,
      source: json['source'] as String?,
      scanResultId: json['scanResultId'] as String?,
      originalName: (json['originalName'] ?? json['name']) as String?,
      originalPrice: json['originalPrice'] is int
          ? json['originalPrice'] as int
          : json['originalPrice'] is num
          ? (json['originalPrice'] as num).toInt()
          : null,
      categoryLabel:
          (json['categoryLabel'] as String?) ??
          (categoryMeta?['naverLargeCategory'] as String?) ??
          (categoryMeta?['category'] as String?),
      categorySource:
          (json['categorySource'] as String?) ??
          (categoryMeta?['categorySource'] as String?) ??
          (categoryMeta?['source'] as String?),
    );
  }
}

class SavedCart {
  String id; // unique
  String? title;
  DateTime createdAt;
  DateTime updatedAt;
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
    DateTime? updatedAt,
    required this.items,
    this.expiresAt,
    this.isExpired = false,
    this.retentionExtensionCount = 0,
    this.canExtendRetention = false,
    this.receiptStatus,
  }) : updatedAt = updatedAt ?? createdAt;

  int get totalPrice => items.fold(0, (sum, it) => sum + it.total);
  int get totalCount => items.fold(0, (sum, it) => sum + it.quantity);
  DateTime get lastTouchedAt => updatedAt;
  DateTime get customerTimelineAt => receiptStatus?.purchasedAt ?? createdAt;

  DateTime? purchaseCompletedAt({DateTime? now}) {
    if (receiptStatus?.isReady == true) {
      return receiptStatus?.completedAt ??
          receiptStatus?.updatedAt ??
          updatedAt;
    }
    final completedAt = lastTouchedAt.add(const Duration(days: 2));
    if (completedAt.isAfter(now ?? DateTime.now())) {
      return null;
    }
    return completedAt;
  }

  bool isPurchaseCompleted({DateTime? now}) {
    return purchaseCompletedAt(now: now) != null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
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
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String)
        : null,
    expiresAt: json['expiresAt'] != null
        ? DateTime.tryParse(json['expiresAt'] as String)
        : null,
    isExpired: json['isExpired'] == true,
    retentionExtensionCount: (json['retentionExtensionCount'] ?? 0) as int,
    canExtendRetention: json['canExtendRetention'] == true,
    receiptStatus: json['receiptStatus'] is Map<String, dynamic>
        ? SavedCartReceiptStatus.fromJson(
            json['receiptStatus'] as Map<String, dynamic>,
          )
        : json['receiptStatus'] is Map
        ? SavedCartReceiptStatus.fromJson(
            Map<String, dynamic>.from(json['receiptStatus'] as Map),
          )
        : null,
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((e) => SavedCartItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
