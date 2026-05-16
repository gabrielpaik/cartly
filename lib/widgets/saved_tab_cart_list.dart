import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import 'saved_tab_list_entry.dart';

class SavedTabCartList extends StatelessWidget {
  final List<SavedCart> carts;
  final ValueChanged<SavedCart> onCartTap;

  const SavedTabCartList({
    super.key,
    required this.carts,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final sortedCarts = [...carts]
      ..sort((a, b) => b.customerTimelineAt.compareTo(a.customerTimelineAt));

    return Column(
      children: List.generate(sortedCarts.length, (index) {
        final cart = sortedCarts[index];
        return SavedTabListEntry(
          cart: cart,
          index: index,
          onTap: () => onCartTap(cart),
        );
      }),
    );
  }
}
