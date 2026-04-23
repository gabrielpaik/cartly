import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';

class CartDetailAppBarActions extends StatelessWidget {
  final bool isEditing;
  final bool isExpiredGuestLocked;
  final SavedCartReceiptStatus? receiptStatus;
  final VoidCallback onToggleEditMode;
  final VoidCallback onDelete;
  final VoidCallback onReceiptCompare;

  const CartDetailAppBarActions({
    super.key,
    required this.isEditing,
    required this.isExpiredGuestLocked,
    required this.receiptStatus,
    required this.onToggleEditMode,
    required this.onDelete,
    required this.onReceiptCompare,
  });

  @override
  Widget build(BuildContext context) {
    if (isExpiredGuestLocked) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isEditing)
          IconButton(
            tooltip: AppRuntimeCopy.text([
              'receiptCompare',
              'entryAction',
            ], '영수증 확인'),
            onPressed: onReceiptCompare,
            icon: Icon(
              receiptStatus == null
                  ? Icons.receipt_long_outlined
                  : Icons.receipt_long,
            ),
          ),
        TextButton(
          onPressed: onToggleEditMode,
          child: Text(
            isEditing
                ? AppRuntimeCopy.text(['cartDetail', 'done'], '완료')
                : AppRuntimeCopy.text(['cartDetail', 'edit'], '수정'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (isEditing)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }
}
