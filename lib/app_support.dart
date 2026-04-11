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

  CartItem({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.source,
    this.scanJobId,
  });
  int get totalPrice => price * quantity;
}

class RecentScanEntry {
  final RecognizedItem item;
  final DateTime createdAt;

  const RecentScanEntry({required this.item, required this.createdAt});
}
