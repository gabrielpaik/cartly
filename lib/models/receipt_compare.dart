class ReceiptSummaryModel {
  final String id;
  final String savedCartId;
  final String status;
  final String? imageUrl;
  final String? merchantName;
  final DateTime? purchasedAt;
  final String currency;
  final int? subtotal;
  final int? tax;
  final int? totalAmount;
  final int? totalDiscountAmount;
  final String? rawText;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReceiptSummaryModel({
    required this.id,
    required this.savedCartId,
    required this.status,
    required this.imageUrl,
    required this.merchantName,
    required this.purchasedAt,
    required this.currency,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    required this.totalDiscountAmount,
    required this.rawText,
    required this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReceiptSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReceiptSummaryModel(
      id: (json['id'] ?? '') as String,
      savedCartId: (json['savedCartId'] ?? '') as String,
      status: (json['status'] ?? 'processing') as String,
      imageUrl: json['imageUrl'] as String?,
      merchantName: json['merchantName'] as String?,
      purchasedAt: _parseDateTime(json['purchasedAt']),
      currency: (json['currency'] ?? 'KRW') as String,
      subtotal: _parseInt(json['subtotal']),
      tax: _parseInt(json['tax']),
      totalAmount: _parseInt(json['totalAmount']),
      totalDiscountAmount: _parseInt(json['totalDiscountAmount']),
      rawText: json['rawText'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }
}

class ReceiptLineItemModel {
  final String id;
  final String rawName;
  final String normalizedName;
  final int? quantity;
  final int? unitPrice;
  final int lineAmount;
  final int? finalAmount;
  final String category;
  final double? confidence;

  const ReceiptLineItemModel({
    required this.id,
    required this.rawName,
    required this.normalizedName,
    required this.quantity,
    required this.unitPrice,
    required this.lineAmount,
    required this.finalAmount,
    required this.category,
    required this.confidence,
  });

  factory ReceiptLineItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptLineItemModel(
      id: (json['id'] ?? '') as String,
      rawName: (json['rawName'] ?? '') as String,
      normalizedName: (json['normalizedName'] ?? '') as String,
      quantity: _parseInt(json['quantity']),
      unitPrice: _parseInt(json['unitPrice']),
      lineAmount: _parseInt(json['lineAmount']) ?? 0,
      finalAmount: _parseInt(json['finalAmount']),
      category: (json['category'] ?? 'item') as String,
      confidence: _parseDouble(json['confidence']),
    );
  }
}

class ReceiptCompareResultModel {
  final ReceiptSummaryModel receipt;
  final List<ReceiptLineItemModel> lineItems;

  const ReceiptCompareResultModel({
    required this.receipt,
    required this.lineItems,
  });

  factory ReceiptCompareResultModel.fromJson(Map<String, dynamic> json) {
    final receiptJson = json['receipt'];
    final lineItemsJson = (json['lineItems'] as List?) ?? const [];

    return ReceiptCompareResultModel(
      receipt: ReceiptSummaryModel.fromJson(
        receiptJson is Map<String, dynamic>
            ? receiptJson
            : Map<String, dynamic>.from(receiptJson as Map),
      ),
      lineItems: lineItemsJson
          .whereType<Map>()
          .map((item) => ReceiptLineItemModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

int? _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _parseDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return null;
}
