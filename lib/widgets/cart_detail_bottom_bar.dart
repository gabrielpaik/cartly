import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import '../services/app_runtime_copy.dart';

class CartDetailBottomBar extends StatelessWidget {
  final String totalPriceText;
  final bool isSaving;
  final VoidCallback onSave;

  const CartDetailBottomBar({
    super.key,
    required this.totalPriceText,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + bottomInset),
      decoration: BoxDecoration(
        color: CartlyColors.surface0,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppRuntimeCopy.text(['cartDetail', 'totalLabel'], '총 합계'),
                  style: const TextStyle(
                    color: CartlyColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalPriceText,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CartlyColors.brand,
                foregroundColor: CartlyColors.onBrandPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                ),
              ),
              onPressed: isSaving ? null : onSave,
              child: Text(
                isSaving
                    ? AppRuntimeCopy.text(['cartDetail', 'saving'], '저장 중…')
                    : AppRuntimeCopy.text(['cartDetail', 'saveButton'], '저장하기'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
