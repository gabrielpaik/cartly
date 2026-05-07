import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
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

  Future<void> _deleteCart(BuildContext context) async {
    final title = (cart.title ?? '').trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('지난 카트 삭제'),
          content: Text(
            title.isEmpty ? '이 지난 카트를 삭제할까요?' : '`$title` 카트를 삭제할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE31837),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await CartStore.instance.deleteCart(cart.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('지난 카트를 삭제했어요')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slidable(
          key: ValueKey('saved-cart-${cart.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.26,
            children: [
              SlidableAction(
                onPressed: (_) => _deleteCart(context),
                backgroundColor: const Color(0xFFE31837),
                foregroundColor: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                icon: Icons.delete_outline_rounded,
                label: '삭제',
              ),
            ],
          ),
          child: SavedCartListCard(cart: cart, onTap: onTap),
        ),
        const SizedBox(height: 12),
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
