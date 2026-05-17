import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/saved_cart.dart';
import 'saved_cart_list_card_header.dart';

class SavedCartListCardContent extends StatelessWidget {
  final SavedCart cart;
  final String dateText;
  final String title;
  final String preview;
  final String? expiryText;
  final String? statusText;

  const SavedCartListCardContent({
    super.key,
    required this.cart,
    required this.dateText,
    required this.title,
    required this.preview,
    required this.expiryText,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final ownerName = cart.owner?.displayName.trim() ?? '';
    final sharedText = cart.isSharedWithHousehold
        ? '공유 카트 · $ownerName'
        : !cart.viewerCanEdit && ownerName.isNotEmpty
        ? '읽기 전용 · $ownerName'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SavedCartListCardHeader(
          title: title,
          dateText: dateText,
          isExpired: cart.isExpired,
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
        if (sharedText != null) ...[
          const SizedBox(height: 6),
          Text(
            sharedText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
        if (statusText != null) ...[
          const SizedBox(height: 6),
          Text(
            statusText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ],
    );
  }
}
