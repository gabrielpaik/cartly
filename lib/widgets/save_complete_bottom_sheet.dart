import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import 'inline_promo_slot.dart';

Future<void> showSaveCompleteBottomSheet({
  required BuildContext context,
  required SavedCart savedCart,
  required VoidCallback onViewSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _SaveCompleteBottomSheet(
        savedCart: savedCart,
        onViewSaved: () {
          Navigator.pop(sheetContext);
          onViewSaved();
        },
      );
    },
  );
}

class _SaveCompleteBottomSheet extends StatelessWidget {
  const _SaveCompleteBottomSheet({
    required this.savedCart,
    required this.onViewSaved,
  });

  final SavedCart savedCart;
  final VoidCallback onViewSaved;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF1E8E3E)),
                const SizedBox(width: 8),
                Text(
                  AppRuntimeCopy.text([
                    'saveComplete',
                    'title',
                  ], '카트를 저장했어요'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${savedCart.totalCount}개 상품 · ₩${formatPrice(savedCart.totalPrice)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppRuntimeCopy.text([
                'saveComplete',
                'subtitle',
              ], '다음 결제 전에 다시 볼 수 있어.'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            InlinePromoSlot(
              slotKey: 'save_complete_sheet_1',
              title: AppRuntimeCopy.text([
                'saveComplete',
                'adFallbackTitle',
              ], '더 저렴한 대안 보기'),
              message: AppRuntimeCopy.text([
                'saveComplete',
                'adFallbackMessage',
              ], '결제 전에 더 나은 선택을 추천해.'),
              height: 88,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppRuntimeCopy.text([
                        'home',
                        'continueScanAction',
                      ], '계속 스캔하기'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE31837),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onViewSaved,
                    child: Text(
                      AppRuntimeCopy.text([
                        'saveComplete',
                        'viewSavedAction',
                      ], '지난 카트 보기'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
