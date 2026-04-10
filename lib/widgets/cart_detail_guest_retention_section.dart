import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/saved_cart.dart';

class CartDetailGuestRetentionSection extends StatelessWidget {
  final SavedCart cart;
  final bool isExtendingRetention;
  final VoidCallback onExtendRetention;

  const CartDetailGuestRetentionSection({
    super.key,
    required this.cart,
    required this.isExtendingRetention,
    required this.onExtendRetention,
  });

  @override
  Widget build(BuildContext context) {
    if (cart.expiresAt == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cart.isExpired
              ? const Color(0xFFFFF4F5)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cart.isExpired
                ? const Color(0xFFFFD7DE)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cart.isExpired
                  ? '게스트 저장 기간이 만료돼서 카트가 잠겼어요'
                  : '게스트 저장 기간이 남아 있어요',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cart.isExpired
                  ? '만료된 게스트 카트는 전체 내용이 가려져요. 광고를 끝까지 보면 14일 더 다시 열 수 있어요.'
                  : '현재 보관 만료일은 ${DateFormat('M월 d일').format(cart.expiresAt!)}예요.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            if (cart.retentionExtensionCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '연장 ${cart.retentionExtensionCount}회',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                ),
              ),
            ],
            if (cart.isExpired && cart.canExtendRetention) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE31837),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isExtendingRetention ? null : onExtendRetention,
                  child: Text(
                    isExtendingRetention ? '광고 확인 중…' : '광고 보고 14일 연장',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CartDetailGuestLockedView extends StatelessWidget {
  final bool canExtendRetention;

  const CartDetailGuestLockedView({
    super.key,
    required this.canExtendRetention,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color: Color(0xFFE31837),
              ),
              const SizedBox(height: 14),
              const Text(
                '만료된 게스트 카트 전체가 잠겨 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                canExtendRetention
                    ? '상품, 수량, 가격, 합계까지 모두 숨겨져 있어요. 광고 보상을 완료하면 다시 열려요.'
                    : '이 카트는 더 이상 연장할 수 없어서 내용을 다시 열 수 없어요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
