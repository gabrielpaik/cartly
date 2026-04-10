import 'package:flutter/material.dart';

import '../services/app_runtime_copy.dart';

class CartDetailAppBarActions extends StatelessWidget {
  final bool isEditing;
  final bool isExpiredGuestLocked;
  final VoidCallback onToggleEditMode;
  final VoidCallback onDelete;

  const CartDetailAppBarActions({
    super.key,
    required this.isEditing,
    required this.isExpiredGuestLocked,
    required this.onToggleEditMode,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isExpiredGuestLocked) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
