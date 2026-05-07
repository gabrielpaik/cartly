import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import 'cartly_surface_card.dart';

class CartlyInfoCard extends StatelessWidget {
  final Widget? header;
  final String? eyebrow;
  final String title;
  final String? body;
  final Widget? footer;
  final Color backgroundColor;
  final BoxBorder? border;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color titleColor;
  final Color bodyColor;

  const CartlyInfoCard({
    super.key,
    this.header,
    this.eyebrow,
    required this.title,
    this.body,
    this.footer,
    this.backgroundColor = CartlyColors.surface1,
    this.border,
    this.radius = CartlyRadii.card,
    this.padding = const EdgeInsets.all(16),
    this.titleColor = CartlyColors.textPrimary,
    this.bodyColor = CartlyColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return CartlySurfaceCard(
      backgroundColor: backgroundColor,
      border: border,
      radius: radius,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 12)],
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: CartlyText.cardMeta.copyWith(color: CartlyColors.brand),
            ),
            const SizedBox(height: 8),
          ],
          Text(title, style: CartlyText.cardTitle.copyWith(color: titleColor)),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, style: CartlyText.cardBody.copyWith(color: bodyColor)),
          ],
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}
