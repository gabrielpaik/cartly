import 'dart:math';

import 'package:intl/intl.dart';

import 'models/recognized_item.dart';

final _priceFormatter = NumberFormat('#,###');
final _cartItemIdRandom = Random();

String formatPrice(int price) => _priceFormatter.format(price);

String _nextCartItemId() {
  return '${DateTime.now().microsecondsSinceEpoch}-${_cartItemIdRandom.nextInt(1 << 32)}';
}

class CartItem {
  String id;
  String name;
  int price;
  int quantity;
  String? source;
  String? scanJobId;
  String? originalRecognizedName;

  CartItem({
    String? id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.source,
    this.scanJobId,
    this.originalRecognizedName,
  }) : id = id ?? _nextCartItemId();
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
