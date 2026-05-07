import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import 'cartly_surface_card.dart';

class CartlyActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final BoxBorder? border;
  final double radius;
  final EdgeInsetsGeometry padding;

  const CartlyActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onTap,
    this.showChevron = false,
    this.backgroundColor = CartlyColors.surface1,
    this.iconBackgroundColor = CartlyColors.surface2,
    this.iconColor = CartlyColors.brand,
    this.border,
    this.radius = CartlyRadii.card,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: CartlySurfaceCard(
          padding: padding,
          backgroundColor: backgroundColor,
          border: border,
          radius: radius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: CartlyIconSizes.row, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: CartlyText.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(body, style: CartlyText.cardBody),
                    if (actionLabel != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        actionLabel!,
                        style: CartlyText.cardMeta.copyWith(
                          color: CartlyColors.subBrand,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: CartlyIconSizes.inline,
                    color: CartlyColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
