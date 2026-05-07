import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';

class CartlySurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BoxBorder? border;
  final Gradient? gradient;
  final double radius;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const CartlySurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = CartlyColors.surface1,
    this.border,
    this.gradient,
    this.radius = CartlyRadii.card,
    this.width = double.infinity,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBackground = backgroundColor;
    final shouldUseDefaultBorder =
        border == null &&
        gradient == null &&
        (resolvedBackground == CartlyColors.surface1 ||
            resolvedBackground == CartlyColors.surface2);

    return Container(
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? resolvedBackground : null,
        gradient: gradient,
        border:
            border ??
            (shouldUseDefaultBorder
                ? Border.all(color: CartlyColors.line, width: 0.5)
                : null),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
