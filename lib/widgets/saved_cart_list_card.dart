import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/saved_cart.dart';
import '../services/cart_store.dart';
import 'cartly_symbol_icon.dart';
import 'saved_cart_list_card_content.dart';

class SavedCartListCard extends StatelessWidget {
  final SavedCart cart;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const SavedCartListCard({
    super.key,
    required this.cart,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy년 M월 d일').format(cart.createdAt);
    final title = (cart.title ?? '').trim();
    final preview = cart.items.take(2).map((e) => e.name).join(' · ');
    final expiryText = cart.expiresAt == null
        ? null
        : cart.isExpired
        ? '저장 기간 만료 · 광고 보고 14일 연장 가능'
        : '게스트 저장 ${DateFormat('M/d').format(cart.expiresAt!)}까지';

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: borderRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: CartStore.instance.pendingCartIds,
                builder: (context, pendingCartIds, _) {
                  final statusText = pendingCartIds.contains(cart.id)
                      ? '서버 동기화 대기 중'
                      : null;
                  return SavedCartListCardContent(
                    cart: cart,
                    dateText: dateText,
                    title: title,
                    preview: preview,
                    expiryText: expiryText,
                    statusText: statusText,
                  );
                },
              ),
            ),
            const CartlySymbolIcon.sf('chevron.right'),
          ],
        ),
      ),
    );
  }
}
