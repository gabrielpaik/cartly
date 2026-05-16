import '../models/saved_cart.dart';

class MyPageCategoryGroup {
  final String id;
  final String label;
  final List<String> keywords;

  const MyPageCategoryGroup({
    required this.id,
    required this.label,
    required this.keywords,
  });

  factory MyPageCategoryGroup.fromJson(Map<String, dynamic> json) {
    final keywords = (json['keywords'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return MyPageCategoryGroup(
      id: (json['id'] ?? '') as String,
      label: (json['label'] ?? '기타') as String,
      keywords: keywords,
    );
  }
}

class MyPageItemSummary {
  final String key;
  final String label;
  final String categoryLabel;
  final int cartCount;
  final int quantity;
  final int amount;

  const MyPageItemSummary({
    required this.key,
    required this.label,
    required this.categoryLabel,
    required this.cartCount,
    required this.quantity,
    required this.amount,
  });
}

class MyPageCategorySummary {
  final String label;
  final int amount;
  final int itemCount;
  final List<MyPageItemSummary> items;

  const MyPageCategorySummary({
    required this.label,
    required this.amount,
    required this.itemCount,
    required this.items,
  });
}

class MyPageMonthlySummary {
  final DateTime month;
  final int savedCartCount;
  final int totalAmount;
  final int totalItemCount;
  final List<MyPageCategorySummary> topCategories;
  final List<MyPageItemSummary> topItems;
  final List<SavedCart> carts;

  const MyPageMonthlySummary({
    required this.month,
    required this.savedCartCount,
    required this.totalAmount,
    required this.totalItemCount,
    required this.topCategories,
    required this.topItems,
    required this.carts,
  });
}

class MyPageInsightsCalculator {
  MyPageInsightsCalculator._();

  static List<MyPageMonthlySummary> buildMonthlySummaries({
    required List<SavedCart> carts,
    required List<MyPageCategoryGroup> groups,
    required int months,
    required int topCategoryCount,
    DateTime? now,
  }) {
    final base = now ?? DateTime.now();
    final monthStarts = List.generate(
      months,
      (index) => DateTime(base.year, base.month - index, 1),
    );

    return monthStarts.map((monthStart) {
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final monthCarts =
          carts.where((cart) {
              final completedAt = cart.purchaseCompletedAt(now: base);
              if (completedAt == null) {
                return false;
              }
              return !completedAt.isBefore(monthStart) &&
                  completedAt.isBefore(nextMonth);
            }).toList()
            ..sort((a, b) => b.lastTouchedAt.compareTo(a.lastTouchedAt));

      final categoryBuckets = <String, _CategoryBucket>{};
      final itemBuckets = <String, _ItemBucket>{};
      var amount = 0;
      var itemCount = 0;

      for (final cart in monthCarts) {
        amount += cart.totalPrice;
        itemCount += cart.totalCount;
        final seenItemKeys = <String>{};

        for (final item in cart.items) {
          final categoryLabel = _resolveCategoryLabel(item, groups);
          final itemKey = _normalizeItemKey(item);
          final itemLabel = _resolveItemLabel(item);
          final firstSeenInCart = seenItemKeys.add(itemKey);

          final categoryBucket = categoryBuckets.putIfAbsent(
            categoryLabel,
            () => _CategoryBucket(label: categoryLabel),
          );
          categoryBucket.add(
            itemKey: itemKey,
            itemLabel: itemLabel,
            item: item,
            incrementCartCount: firstSeenInCart,
          );

          final itemBucket = itemBuckets.putIfAbsent(
            itemKey,
            () => _ItemBucket(
              key: itemKey,
              label: itemLabel,
              categoryLabel: categoryLabel,
            ),
          );
          itemBucket.add(item: item, incrementCartCount: firstSeenInCart);
        }
      }

      final topCategories =
          categoryBuckets.values.map((bucket) => bucket.build()).toList()
            ..sort(_compareCategorySummary);

      final topItems =
          itemBuckets.values.map((bucket) => bucket.build()).toList()
            ..sort(_compareItemSummary);

      return MyPageMonthlySummary(
        month: monthStart,
        savedCartCount: monthCarts.length,
        totalAmount: amount,
        totalItemCount: itemCount,
        topCategories: topCategories.take(topCategoryCount).toList(),
        topItems: topItems,
        carts: monthCarts,
      );
    }).toList();
  }

  static int _compareCategorySummary(
    MyPageCategorySummary a,
    MyPageCategorySummary b,
  ) {
    final amountCompare = b.amount.compareTo(a.amount);
    if (amountCompare != 0) {
      return amountCompare;
    }
    final itemCompare = b.itemCount.compareTo(a.itemCount);
    if (itemCompare != 0) {
      return itemCompare;
    }
    return a.label.compareTo(b.label);
  }

  static int _compareItemSummary(MyPageItemSummary a, MyPageItemSummary b) {
    final cartCompare = b.cartCount.compareTo(a.cartCount);
    if (cartCompare != 0) {
      return cartCompare;
    }
    final quantityCompare = b.quantity.compareTo(a.quantity);
    if (quantityCompare != 0) {
      return quantityCompare;
    }
    final amountCompare = b.amount.compareTo(a.amount);
    if (amountCompare != 0) {
      return amountCompare;
    }
    return a.label.compareTo(b.label);
  }

  static String _resolveCategoryLabel(
    SavedCartItem item,
    List<MyPageCategoryGroup> groups,
  ) {
    final haystack = '${item.name} ${item.originalName ?? ''}'.toLowerCase();
    for (final group in groups) {
      for (final keyword in group.keywords) {
        if (keyword.trim().isEmpty) continue;
        if (haystack.contains(keyword.toLowerCase())) {
          return group.label;
        }
      }
    }
    return '기타';
  }

  static String _normalizeItemKey(SavedCartItem item) {
    return _resolveItemLabel(item).toLowerCase();
  }

  static String _resolveItemLabel(SavedCartItem item) {
    final originalName = (item.originalName ?? '').trim();
    if (originalName.isNotEmpty) {
      return originalName;
    }
    final name = item.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return '이름 없는 상품';
  }
}

class _CategoryBucket {
  final String label;
  int amount = 0;
  int itemCount = 0;
  final Map<String, _ItemBucket> items = {};

  _CategoryBucket({required this.label});

  void add({
    required String itemKey,
    required String itemLabel,
    required SavedCartItem item,
    required bool incrementCartCount,
  }) {
    amount += item.total;
    itemCount += item.quantity;
    final itemBucket = items.putIfAbsent(
      itemKey,
      () => _ItemBucket(key: itemKey, label: itemLabel, categoryLabel: label),
    );
    itemBucket.add(item: item, incrementCartCount: incrementCartCount);
  }

  MyPageCategorySummary build() {
    final builtItems = items.values.map((item) => item.build()).toList()
      ..sort(MyPageInsightsCalculator._compareItemSummary);
    return MyPageCategorySummary(
      label: label,
      amount: amount,
      itemCount: itemCount,
      items: builtItems,
    );
  }
}

class _ItemBucket {
  final String key;
  final String label;
  final String categoryLabel;
  int cartCount = 0;
  int quantity = 0;
  int amount = 0;

  _ItemBucket({
    required this.key,
    required this.label,
    required this.categoryLabel,
  });

  void add({required SavedCartItem item, required bool incrementCartCount}) {
    if (incrementCartCount) {
      cartCount += 1;
    }
    quantity += item.quantity;
    amount += item.total;
  }

  MyPageItemSummary build() {
    return MyPageItemSummary(
      key: key,
      label: label,
      categoryLabel: categoryLabel,
      cartCount: cartCount,
      quantity: quantity,
      amount: amount,
    );
  }
}
