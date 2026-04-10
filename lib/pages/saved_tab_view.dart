import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../services/cart_store.dart';
import '../widgets/saved_tab_cart_list.dart';
import '../widgets/saved_tab_empty_state.dart';
import '../widgets/saved_tab_header.dart';

class SavedTabView extends StatelessWidget {
  const SavedTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedCart>>(
      valueListenable: CartStore.instance.carts,
      builder: (context, carts, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            const SavedTabHeader(),
            if (carts.isNotEmpty) const SizedBox(height: 8),
            if (carts.isEmpty)
              const SavedTabEmptyState()
            else
              SavedTabCartList(
                carts: carts,
                onCartTap: (cart) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CartDetailPage(cart: cart),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
