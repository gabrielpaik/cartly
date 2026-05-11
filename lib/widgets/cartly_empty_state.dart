import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';

class CartlyEmptyState extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? body;
  final double iconSize;

  const CartlyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: Center(child: icon),
        ),
        const SizedBox(height: 12),
        Text(title, style: CartlyText.cardTitle),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!, textAlign: TextAlign.center, style: CartlyText.cardBody),
        ],
      ],
    );
  }
}
