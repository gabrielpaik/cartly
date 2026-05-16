import 'package:intl/intl.dart';

import 'models/recognized_item.dart';

final _priceFormatter = NumberFormat('#,###');
String formatPrice(int price) => _priceFormatter.format(price);

class CartItem {
  String name;
  int price;
  int quantity;
  String? source;
  String? scanJobId;
  String? originalRecognizedName;

  CartItem({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.source,
    this.scanJobId,
    this.originalRecognizedName,
  });
  int get totalPrice => price * quantity;
}

class RecentScanEntry {
  final String id;
  final RecognizedItem item;
  final DateTime createdAt;

  const RecentScanEntry({
    required this.id,
    required this.item,
    required this.createdAt,
  });
}

class ConsideredProductEntry {
  final String id;
  final String name;
  final int price;
  final String source;
  final DateTime createdAt;
  final String? originalRecognizedName;

  const ConsideredProductEntry({
    required this.id,
    required this.name,
    required this.price,
    required this.source,
    required this.createdAt,
    this.originalRecognizedName,
  });
}
