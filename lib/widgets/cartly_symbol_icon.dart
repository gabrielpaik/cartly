import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'cartly_symbol_assets.dart';

class CartlySymbolIcon extends StatelessWidget {
  final String name;
  final bool isSfSymbol;
  final double? size;
  final Color? color;
  final String? semanticsLabel;

  const CartlySymbolIcon({
    super.key,
    required this.name,
    this.size,
    this.color,
    this.semanticsLabel,
  }) : isSfSymbol = false;

  const CartlySymbolIcon.sf(
    this.name, {
    super.key,
    this.size,
    this.color,
    this.semanticsLabel,
  }) : isSfSymbol = true;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor = color ?? iconTheme.color;

    return SvgPicture.asset(
      isSfSymbol ? CartlySymbolAssets.sf(name) : name,
      width: resolvedSize,
      height: resolvedSize,
      fit: BoxFit.contain,
      semanticsLabel: semanticsLabel,
      colorFilter: resolvedColor == null
          ? null
          : ColorFilter.mode(resolvedColor, BlendMode.srcIn),
      placeholderBuilder: (context) =>
          SizedBox(width: resolvedSize, height: resolvedSize),
    );
  }
}
