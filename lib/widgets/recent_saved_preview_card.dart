import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_support.dart';
import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../services/app_runtime_copy.dart';

class RecentSavedPreviewCard extends StatelessWidget {
  final SavedCart? cart;

  const RecentSavedPreviewCard({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    if (cart == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppRuntimeCopy.text(['saved', 'recentTitle'], '최근 저장 카트'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              AppRuntimeCopy.text([
                'saved',
                'recentEmptyBody',
              ], '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final savedCart = cart!;
    final dateText = DateFormat('M월 d일').format(savedCart.createdAt);
    final title = (savedCart.title ?? '').trim();
    final preview = savedCart.items.take(2).map((e) => e.name).join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CartDetailPage(cart: savedCart)),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty
                        ? AppRuntimeCopy.text(['saved', 'recentTitle'], '최근 저장 카트')
                        : title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                if (savedCart.isExpired)
                  const _RecentSavedContextPill(
                    label: '만료됨',
                    color: Color(0xFFE31837),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$dateText · ${savedCart.totalCount}개 · ₩${formatPrice(savedCart.totalPrice)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
          ],
        ),
      ),
    );
  }
}

class _RecentSavedContextPill extends StatelessWidget {
  final String label;
  final Color color;

  const _RecentSavedContextPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
