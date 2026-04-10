import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import 'inline_promo_slot.dart';
import 'saved_cart_list_card.dart';

class SavedTabListEntry extends StatelessWidget {
  final SavedCart cart;
  final int index;
  final VoidCallback onTap;

  const SavedTabListEntry({
    super.key,
    required this.cart,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SavedCartListCard(cart: cart, onTap: onTap),
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
  }
}
