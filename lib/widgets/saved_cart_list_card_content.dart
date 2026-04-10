import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/saved_cart.dart';
import 'context_pill.dart';

class SavedCartListCardContent extends StatelessWidget {
  final SavedCart cart;
  final String dateText;
  final String title;
  final String preview;
  final String? expiryText;

  const SavedCartListCardContent({
    super.key,
    required this.cart,
    required this.dateText,
    required this.title,
    required this.preview,
    required this.expiryText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
            expiryText!,
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
    );
  }
}
