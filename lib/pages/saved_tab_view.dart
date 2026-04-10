import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
import '../widgets/inline_promo_slot.dart';
import '../widgets/saved_cart_list_card.dart';

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
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Opacity(
                        opacity: 0.16,
                        child: Icon(Icons.bookmark_border, size: 72),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppRuntimeCopy.text([
                          'saved',
                          'emptyTitle',
                        ], '아직 저장된 카트가 없어요'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppRuntimeCopy.text([
                          'saved',
                          'emptyBody',
                        ], 'Home에서 저장하면 여기서 다시 볼 수 있어.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(carts.length, (index) {
                final cart = carts[index];
                return Column(
                  children: [
                    SavedCartListCard(
                      cart: cart,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CartDetailPage(cart: cart),
                          ),
                        );
                      },
                    ),
                    if (index == 0)
                      InlinePromoSlot(
                        slotKey: 'saved_inline_1',
                        title: AppRuntimeCopy.text([
                          'saved',
                          'adFallbackTitle',
                        ], '오늘의 혜택 추천'),
                        message: AppRuntimeCopy.text([
                          'saved',
                          'adFallbackMessage',
                        ], '저장 카트 확인을 방해하지 않는 위치에 작고 자연스러운 혜택 슬롯을 둬요.'),
                        height: 104,
                      ),
                    if (index == 2)
                      InlinePromoSlot(
                        slotKey: 'saved_inline_2',
                        title: AppRuntimeCopy.text([
                          'saved',
                          'adSecondaryFallbackTitle',
                        ], '비슷한 상품 프로모션'),
                        message: AppRuntimeCopy.text([
                          'saved',
                          'adSecondaryFallbackMessage',
                        ], '히스토리를 보는 흐름은 유지하고, 목록 사이에만 낮은 밀도로 노출해요.'),
                        height: 104,
                      ),
                  ],
                );
              }),
          ],
        );
      },
    );
  }
}
