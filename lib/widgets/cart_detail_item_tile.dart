import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import 'cartly_symbol_icon.dart';

class CartDetailItemTile extends StatelessWidget {
  final SavedCartItem item;
  final bool isEditingMode;
  final bool isInlineEditing;
  final String priceText;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onCancelInlineEdit;
  final VoidCallback onApplyInlineEdit;

  const CartDetailItemTile({
    super.key,
    required this.item,
    required this.isEditingMode,
    required this.isInlineEditing,
    required this.priceText,
    required this.nameController,
    required this.priceController,
    required this.onEdit,
    required this.onDelete,
    required this.onDecrease,
    required this.onIncrease,
    required this.onCancelInlineEdit,
    required this.onApplyInlineEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$priceText · ${item.quantity}개',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEditingMode) ...[
                IconButton(
                  onPressed: onEdit,
                  icon: const CartlySymbolIcon.sf('pencil.tip'),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const CartlySymbolIcon.sf('xmark'),
                ),
              ],
            ],
          ),
          if (isEditingMode && !isInlineEditing) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onDecrease,
                  icon: const CartlySymbolIcon.sf('minus.circle'),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: onIncrease,
                  icon: const CartlySymbolIcon.sf('plus.circle'),
                ),
              ],
            ),
          ],
          if (isInlineEditing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppRuntimeCopy.text([
                  'cartDetail',
                  'nameLabel',
                ], '상품명'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppRuntimeCopy.text([
                  'cartDetail',
                  'priceLabel',
                ], '가격'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancelInlineEdit,
                  child: Text(AppRuntimeCopy.text(['common', 'cancel'], '취소')),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onApplyInlineEdit,
                  child: Text(
                    AppRuntimeCopy.text(['cartDetail', 'apply'], '적용'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
