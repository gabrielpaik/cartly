import 'package:flutter/material.dart';

import 'context_pill.dart';

class SavedCartListCardHeader extends StatelessWidget {
  final String title;
  final String dateText;
  final bool isExpired;

  const SavedCartListCardHeader({
    super.key,
    required this.title,
    required this.dateText,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.isEmpty ? dateText : title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (isExpired)
          const ContextPill(label: '만료됨', color: Color(0xFFE31837)),
      ],
    );
  }
}
