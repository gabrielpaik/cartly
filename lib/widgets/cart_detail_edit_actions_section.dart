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

  const CartDetailEditActionsSection({
    super.key,
    required this.isVisible,
    required this.isEditing,
    required this.onAddItem,
    required this.totalPriceText,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
