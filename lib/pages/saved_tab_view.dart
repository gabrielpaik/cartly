import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
import '../widgets/inline_promo_slot.dart';
import '../widgets/saved_tab_empty_state.dart';
import '../widgets/saved_tab_list_entry.dart';

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
            Text(
              AppRuntimeCopy.text(['saved', 'pageTitle'], 'Saved carts'),
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                height: 0.95,
                color: Color(0xFFE31837),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppRuntimeCopy.text(['saved', 'subtitle'], '저장한 카트를 다시 봐'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const AudienceBannerSlot(
              showForGuests: true,
              showForMembers: true,
            ),
            if (carts.isNotEmpty) const SizedBox(height: 8),
            if (carts.isEmpty)
              const SavedTabEmptyState()
            else
              ...List.generate(carts.length, (index) {
                final cart = carts[index];
                return SavedTabListEntry(
                  cart: cart,
                  index: index,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CartDetailPage(cart: cart),
                      ),
                    );
                  },
                );
              }),
          ],
        );
      },
    );
  }
}
