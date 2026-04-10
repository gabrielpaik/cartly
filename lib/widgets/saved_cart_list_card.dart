import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_support.dart';
import '../models/saved_cart.dart';
import 'context_pill.dart';

class SavedCartListCard extends StatelessWidget {
  final SavedCart cart;
  final VoidCallback onTap;

  const SavedCartListCard({
    super.key,
    required this.cart,
    required this.onTap,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? dateText : title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (cart.isExpired)
                        const ContextPill(label: '만료됨', color: Color(0xFFE31837)),
                    ],
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${cart.totalCount}개 · ₩${formatPrice(cart.totalPrice)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  if (expiryText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      expiryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cart.isExpired ? const Color(0xFFE31837) : Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
