import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import 'cart_detail_guest_retention_section.dart';
import 'cart_detail_item_tile.dart';

class CartDetailBody extends StatelessWidget {
  final bool isExpiredGuestLocked;
  final bool canExtendRetention;
  final List<SavedCartItem> items;
  final bool isEditing;
  final int? editingIndex;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final String Function(int price) formatPriceText;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onDecrease;
  final ValueChanged<int> onIncrease;
  final VoidCallback onCancelInlineEdit;
  final VoidCallback onApplyInlineEdit;

  const CartDetailBody({
    super.key,
    required this.isExpiredGuestLocked,
    required this.canExtendRetention,
    required this.items,
    required this.isEditing,
    required this.editingIndex,
    required this.nameController,
    required this.priceController,
    required this.formatPriceText,
    required this.onEdit,
    required this.onDelete,
    required this.onDecrease,
    required this.onIncrease,
    required this.onCancelInlineEdit,
    required this.onApplyInlineEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (isExpiredGuestLocked) {
      return CartDetailGuestLockedView(canExtendRetention: canExtendRetention);
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          AppRuntimeCopy.text(['cartDetail', 'empty'], '카트가 비었어요'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final editing = editingIndex == index;

        return CartDetailItemTile(
          item: item,
          isEditingMode: isEditing,
          isInlineEditing: editing,
          priceText: formatPriceText(item.price),
          originalPriceText: item.hasDiscount && item.originalPrice != null
              ? formatPriceText(item.originalPrice!)
              : null,
          nameController: nameController,
          priceController: priceController,
          onEdit: isEditing ? () => onEdit(index) : null,
          onDelete: isEditing ? () => onDelete(index) : null,
          onDecrease: isEditing && !editing ? () => onDecrease(index) : null,
          onIncrease: isEditing && !editing ? () => onIncrease(index) : null,
          onCancelInlineEdit: onCancelInlineEdit,
          onApplyInlineEdit: onApplyInlineEdit,
        );
      },
    );
  }
}
