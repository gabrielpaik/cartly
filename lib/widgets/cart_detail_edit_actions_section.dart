import 'package:flutter/material.dart';

import 'cart_detail_bottom_bar.dart';
import 'saved_cart_item_add_section.dart';

class CartDetailEditActionsSection extends StatelessWidget {
  final bool isVisible;
  final bool isEditing;
  final void Function(String name, int price) onAddItem;
  final String totalPriceText;
  final bool isSaving;
  final VoidCallback onSave;
  final bool showUndoReceiptApply;
  final VoidCallback? onUndoReceiptApply;

  const CartDetailEditActionsSection({
    super.key,
    required this.isVisible,
    required this.isEditing,
    required this.onAddItem,
    required this.totalPriceText,
    required this.isSaving,
    required this.onSave,
    this.showUndoReceiptApply = false,
    this.onUndoReceiptApply,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEditing && showUndoReceiptApply)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '영수증 반영을 되돌릴 수 있어요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5B21B6),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onUndoReceiptApply,
                    child: const Text(
                      '되돌리기',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SavedCartItemAddSection(
            isEditing: isEditing,
            onAdd: onAddItem,
          ),
        ),
        CartDetailBottomBar(
          totalPriceText: totalPriceText,
          isSaving: isSaving,
          onSave: onSave,
        ),
      ],
    );
  }
}
