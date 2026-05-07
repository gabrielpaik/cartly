import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';

class CartlyBadge extends StatelessWidget {
  final String label;
  final bool dark;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final FontWeight fontWeight;

  const CartlyBadge({
    super.key,
    required this.label,
    this.dark = false,
    this.backgroundColor,
    this.foregroundColor,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBackground =
        backgroundColor ??
        (dark ? const Color(0xFF2B2B2B) : CartlyColors.surfaceNeutral);
    final resolvedForeground =
        foregroundColor ??
        (dark ? CartlyColors.onBrandMuted : CartlyColors.brandTextOnLight);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(CartlyRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: fontWeight,
          color: resolvedForeground,
        ),
      ),
    );
  }
}
